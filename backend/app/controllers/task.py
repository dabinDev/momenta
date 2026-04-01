from __future__ import annotations

from datetime import datetime
from typing import Any

from app.models.admin import User
from app.models.video_task import VideoTask, VideoTaskAsset, VoiceTranscriptionLog
from app.services.business_gateway import business_gateway_service


class TaskController:
    final_statuses = {"completed", "failed", "cancelled"}

    async def create_task(
        self,
        *,
        user_id: int,
        task_source: str,
        task_type: str,
        provider: str,
        input_text: str | None,
        polished_text: str | None,
        prompt: str,
        duration: int,
        images: list[str],
        provider_payload: dict[str, Any],
    ) -> VideoTask:
        now = datetime.now()
        status = self._read_status(provider_payload)
        progress = self._read_progress(provider_payload)

        task = await VideoTask.create(
            user_id=user_id,
            task_source=task_source,
            task_type=task_type,
            status=status,
            input_text=input_text,
            polished_text=polished_text,
            prompt=self._read_prompt(provider_payload) or prompt,
            duration=duration,
            cover_image_url=self._read_cover_image(provider_payload, images),
            video_url=self._read_video_url(provider_payload),
            provider=provider,
            provider_task_id=self._read_provider_task_id(provider_payload),
            progress=progress,
            error_code=self._read_error_code(provider_payload),
            error_message=self._read_error_message(provider_payload),
            provider_payload=provider_payload,
            started_at=now if status in {"queued", "processing", "completed", "failed"} else None,
            finished_at=now if status in self.final_statuses else None,
        )

        await self.replace_assets(task=task, images=images)
        return task

    async def replace_assets(self, *, task: VideoTask, images: list[str]) -> None:
        await VideoTaskAsset.filter(task_id=task.id).delete()
        assets = [
            VideoTaskAsset(
                task_id=task.id,
                asset_type="reference_image",
                file_url=image,
                file_name=self._file_name(image),
                sort_order=index,
            )
            for index, image in enumerate(images)
            if image
        ]
        if assets:
            await VideoTaskAsset.bulk_create(assets)

    async def sync_task_status(self, task: VideoTask, *, force: bool = False) -> VideoTask:
        if not task.provider_task_id:
            return task
        if not force and task.status in self.final_statuses:
            return task

        provider_payload = await business_gateway_service.sync_video_status(task)
        if not isinstance(provider_payload, dict):
            provider_payload = {"data": provider_payload}

        status = self._read_status(provider_payload, fallback=task.status)
        progress = self._read_progress(provider_payload, fallback=task.progress)
        task.status = status
        task.prompt = self._read_prompt(provider_payload) or task.prompt
        task.video_url = self._read_video_url(provider_payload) or task.video_url
        task.cover_image_url = self._read_cover_image(provider_payload) or task.cover_image_url
        task.error_code = self._read_error_code(provider_payload) or task.error_code
        task.error_message = self._read_error_message(provider_payload) or task.error_message
        task.progress = progress
        task.provider_payload = provider_payload

        now = datetime.now()
        if status in {"queued", "processing"} and task.started_at is None:
            task.started_at = now
        if status in self.final_statuses:
            task.finished_at = now

        await task.save()
        return task

    async def get_user_task(self, *, task_id: int, user_id: int) -> VideoTask:
        return await VideoTask.get(id=task_id, user_id=user_id)

    async def get_task(self, *, task_id: int) -> VideoTask:
        return await VideoTask.get(id=task_id)

    async def list_user_tasks(
        self,
        *,
        user_id: int,
        page: int,
        page_size: int,
        status: str = "all",
    ) -> tuple[int, list[VideoTask]]:
        query = VideoTask.filter(user_id=user_id, is_deleted=False)
        if status and status != "all":
            query = query.filter(status=status)
        total = await query.count()
        items = await query.offset((page - 1) * page_size).limit(page_size).order_by("-created_at")
        return total, items

    async def list_admin_tasks(
        self,
        *,
        page: int,
        page_size: int,
        username: str = "",
        status: str = "",
        task_type: str = "",
        include_deleted: bool = False,
    ) -> tuple[int, list[VideoTask]]:
        query = VideoTask.all()
        if not include_deleted:
            query = query.filter(is_deleted=False)
        if status:
            query = query.filter(status=status)
        if task_type:
            query = query.filter(task_type=task_type)
        if username:
            user_ids = await User.filter(username__contains=username).values_list("id", flat=True)
            if not user_ids:
                return 0, []
            query = query.filter(user_id__in=list(user_ids))

        total = await query.count()
        items = await query.offset((page - 1) * page_size).limit(page_size).order_by("-created_at")
        return total, items

    async def user_summary(self, *, user_id: int) -> dict[str, int]:
        base_query = VideoTask.filter(user_id=user_id, is_deleted=False)
        total = await base_query.count()
        completed = await base_query.filter(status="completed").count()
        processing = await base_query.filter(status__in=["queued", "processing"]).count()
        failed = await base_query.filter(status="failed").count()
        return {
            "total": total,
            "completed": completed,
            "processing": processing,
            "failed": failed,
        }

    async def mark_deleted(self, *, task_id: int, user_id: int | None = None) -> None:
        filters = {"id": task_id}
        if user_id is not None:
            filters["user_id"] = user_id
        task = await VideoTask.get(**filters)
        task.is_deleted = True
        task.deleted_at = datetime.now()
        await task.save()

    async def mark_all_deleted(self, *, user_id: int) -> None:
        await VideoTask.filter(user_id=user_id, is_deleted=False).update(
            is_deleted=True,
            deleted_at=datetime.now(),
        )

    async def list_voice_logs(
        self,
        *,
        page: int,
        page_size: int,
        username: str = "",
        status: str = "",
        provider: str = "",
    ) -> tuple[int, list[VoiceTranscriptionLog]]:
        query = VoiceTranscriptionLog.all()
        if status:
            query = query.filter(status=status)
        if provider:
            query = query.filter(provider=provider)
        if username:
            user_ids = await User.filter(username__contains=username).values_list("id", flat=True)
            if not user_ids:
                return 0, []
            query = query.filter(user_id__in=list(user_ids))

        total = await query.count()
        items = await query.offset((page - 1) * page_size).limit(page_size).order_by("-created_at")
        return total, items

    async def create_voice_log(
        self,
        *,
        user_id: int,
        provider: str,
        file_name: str,
        audio_format: str,
        audio_duration: float,
        language: str,
        accent: str,
        recognized_text: str | None,
        status: str,
        error_message: str | None = None,
        task_id: int | None = None,
    ) -> VoiceTranscriptionLog:
        return await VoiceTranscriptionLog.create(
            user_id=user_id,
            task_id=task_id,
            provider=provider,
            file_name=file_name,
            audio_format=audio_format,
            audio_duration=audio_duration,
            language=language,
            accent=accent,
            recognized_text=recognized_text,
            status=status,
            error_message=error_message,
        )

    async def serialize_task(self, task: VideoTask, *, include_assets: bool = True, include_user: bool = False) -> dict[str, Any]:
        data = await task.to_dict()
        data["id"] = str(task.id)
        data["prompt"] = task.prompt or task.polished_text or task.input_text or ""
        data["video_url"] = task.video_url or ""
        data["error_message"] = task.error_message or ""
        data["provider_task_id"] = task.provider_task_id or ""
        data["progress"] = float(task.progress or 0)
        data["is_deleted"] = task.is_deleted
        data["cover_image_url"] = task.cover_image_url or ""

        if include_assets:
            assets = await VideoTaskAsset.filter(task_id=task.id).order_by("sort_order")
            data["assets"] = [await asset.to_dict() for asset in assets]
        if include_user:
            user = await User.filter(id=task.user_id).first()
            data["user"] = {
                "id": user.id,
                "username": user.username,
                "alias": user.alias,
                "email": user.email,
            } if user else None
        return data

    async def serialize_voice_log(self, voice_log: VoiceTranscriptionLog) -> dict[str, Any]:
        data = await voice_log.to_dict()
        data["id"] = str(voice_log.id)
        user = await User.filter(id=voice_log.user_id).first()
        data["user"] = {
            "id": user.id,
            "username": user.username,
            "alias": user.alias,
            "email": user.email,
        } if user else None
        if voice_log.task_id:
            data["task_id"] = str(voice_log.task_id)
            task = await VideoTask.filter(id=voice_log.task_id).first()
            data["task"] = (
                {
                    "id": str(task.id),
                    "status": task.status,
                    "prompt": task.prompt or task.polished_text or task.input_text or "",
                }
                if task
                else None
            )
        return data

    @staticmethod
    def _read_payload(payload: dict[str, Any]) -> dict[str, Any]:
        data = payload.get("data")
        if isinstance(data, dict):
            return data
        return payload

    def _read_provider_task_id(self, payload: dict[str, Any]) -> str | None:
        data = self._read_payload(payload)
        value = data.get("id") or data.get("_id") or data.get("taskId")
        return str(value) if value else None

    def _read_prompt(self, payload: dict[str, Any]) -> str | None:
        data = self._read_payload(payload)
        value = data.get("prompt") or data.get("text")
        return str(value) if value else None

    def _read_video_url(self, payload: dict[str, Any]) -> str | None:
        data = self._read_payload(payload)
        value = data.get("video_url") or data.get("videoUrl")
        return str(value) if value else None

    def _read_cover_image(self, payload: dict[str, Any], images: list[str] | None = None) -> str | None:
        data = self._read_payload(payload)
        value = data.get("cover_image_url") or data.get("coverImageUrl")
        if value:
            return str(value)
        if images:
            return images[0]
        return None

    def _read_status(self, payload: dict[str, Any], fallback: str = "processing") -> str:
        data = self._read_payload(payload)
        status = (data.get("status") or fallback or "processing").lower()
        if status in {"pending", "queued"}:
            return "queued"
        if status in {"processing", "running", "in_progress"}:
            return "processing"
        if status in {"completed", "success", "succeeded", "done"}:
            return "completed"
        if status in {"failed", "error"}:
            return "failed"
        if status in {"cancelled", "canceled"}:
            return "cancelled"
        return status

    def _read_progress(self, payload: dict[str, Any], fallback: float = 0) -> float:
        data = self._read_payload(payload)
        value = data.get("progress")
        if value is None:
            return 1 if self._read_status(payload) == "completed" else float(fallback or 0)
        try:
            progress = float(value)
        except (TypeError, ValueError):
            return float(fallback or 0)
        if progress > 1:
            progress = progress / 100
        return max(0, min(progress, 1))

    def _read_error_code(self, payload: dict[str, Any]) -> str | None:
        data = self._read_payload(payload)
        value = data.get("error_code") or data.get("errorCode") or data.get("code")
        return str(value) if value not in (None, "", 200, "200") else None

    def _read_error_message(self, payload: dict[str, Any]) -> str | None:
        data = self._read_payload(payload)
        value = data.get("error_message") or data.get("errorMessage") or data.get("error") or data.get("msg")
        return str(value) if value else None

    @staticmethod
    def _file_name(path: str) -> str:
        clean_path = path.replace("\\", "/")
        return clean_path.rsplit("/", 1)[-1]


task_controller = TaskController()
