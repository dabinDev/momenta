from __future__ import annotations

import ast
import asyncio
import json
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import httpx

from app.core.exceptions import normalize_error_message as normalize_api_error_message
from app.controllers.points import points_controller
from app.models.admin import User
from app.models.video_task import VideoTask, VideoTaskAsset, VoiceTranscriptionLog
from app.services.business_gateway import business_gateway_service
from app.services.local_media import local_media_service
from app.services.object_storage import ObjectStorageError, object_storage_service
from app.settings import settings


class VideoGenerationRateLimitError(Exception):
    def __init__(self, *, wait_seconds: int, message: str | None = None) -> None:
        self.wait_seconds = max(wait_seconds, 1)
        super().__init__(
            message
            or (
                "当前已有视频正在处理中，请等待当前任务完成或失败后再试。"
                f"若 5 分钟内仍未结束，可在 {self.wait_seconds} 秒后重试。"
            )
        )


class TaskController:
    final_statuses = {"completed", "failed", "cancelled"}
    processing_statuses = {"queued", "processing"}
    auto_retry_enabled = True
    list_status_sync_timeout_seconds = 1.5
    detail_status_sync_timeout_seconds = 3.0
    generation_cooldown = timedelta(minutes=5)
    generation_request_hold = timedelta(seconds=30)
    retryable_failure_markers = (
        "high_traffic",
        "high traffic",
        "生成过程中出现异常，请重新发起请求",
        "temporarily unavailable",
        "service unavailable",
        "please retry",
        "internal error",
        "timeout",
    )
    non_retryable_failure_markers = (
        "audio_filtered",
        "filtered",
        "safety",
        "invalid",
        "parameter",
        "unsupported",
        "forbidden",
        "quota",
        "余额",
        "鉴权",
    )
    transient_failure_retry_limit = 2

    def __init__(self) -> None:
        self._generation_attempt_lock = asyncio.Lock()
        self._pending_generation_attempts: dict[int, datetime] = {}
        self._background_sync_task_ids: set[int] = set()

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
        points_cost: int = 0,
        points_charge_token: str | None = None,
    ) -> VideoTask:
        now = datetime.now()
        status = self._read_status(provider_payload)
        progress = self._read_progress(provider_payload)
        remote_video_url = self._read_remote_video_url(provider_payload)
        cos_video_url = self._read_cos_video_url(provider_payload)

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
            video_url=self._select_preferred_video_url(
                remote_video_url=remote_video_url,
                cos_video_url=cos_video_url,
                fallback=self._read_video_url(provider_payload),
            ),
            remote_video_url=remote_video_url,
            cos_video_url=cos_video_url,
            provider=provider,
            provider_task_id=self._read_provider_task_id(provider_payload),
            progress=progress,
            error_code=self._read_error_code(provider_payload),
            error_message=self._read_error_message(provider_payload),
            provider_payload=provider_payload,
            points_cost=points_cost,
            points_charge_token=points_charge_token,
            points_refunded=False,
            started_at=now if status in {"queued", "processing", "completed", "failed"} else None,
            finished_at=now if status in self.final_statuses else None,
        )

        await self.replace_assets(task=task, images=images)
        await self._refund_task_points_if_needed(task)
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
        provider_payload = self._merge_request_context(
            existing_payload=task.provider_payload or {},
            next_payload=provider_payload,
        )

        status = self._read_status(provider_payload, fallback=task.status)
        progress = self._read_progress(provider_payload, fallback=task.progress)
        if (
            self.auto_retry_enabled
            and status == "failed"
            and await self._should_auto_retry(task=task, payload=provider_payload)
        ):
            return await self._retry_task_from_request_context(task=task, payload=provider_payload)

        task.status = status
        task.prompt = self._read_prompt(provider_payload) or task.prompt
        task.remote_video_url = (
            self._read_remote_video_url(provider_payload)
            or task.remote_video_url
            or self._normalize_remote_video_url(task.video_url)
        )
        task.cos_video_url = (
            self._read_cos_video_url(provider_payload)
            or task.cos_video_url
            or self._normalize_cos_video_url(task.video_url)
        )
        task.video_url = self._select_preferred_video_url(
            remote_video_url=task.remote_video_url,
            cos_video_url=task.cos_video_url,
            fallback=self._read_video_url(provider_payload) or task.video_url,
        )
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
        await self._refund_task_points_if_needed(task)
        return task

    async def sync_task_status_with_timeout(
        self,
        task: VideoTask,
        *,
        force: bool = False,
        timeout_seconds: float | None = None,
        schedule_on_timeout: bool = True,
    ) -> VideoTask:
        if timeout_seconds is None or timeout_seconds <= 0:
            return await self.sync_task_status(task, force=force)

        try:
            return await asyncio.wait_for(
                self.sync_task_status(task, force=force),
                timeout=timeout_seconds,
            )
        except asyncio.TimeoutError:
            if schedule_on_timeout:
                self.schedule_task_status_sync(task, force=force)
            return task

    def schedule_task_status_sync(self, task: VideoTask, *, force: bool = False) -> None:
        if not task.provider_task_id:
            return
        if not force and task.status in self.final_statuses:
            return

        task_id = int(task.id)
        if task_id in self._background_sync_task_ids:
            return

        self._background_sync_task_ids.add(task_id)

        async def _runner() -> None:
            try:
                current_task = await self.get_task(task_id=task_id)
                await self.sync_task_status(current_task, force=force)
            except Exception:
                pass
            finally:
                self._background_sync_task_ids.discard(task_id)

        asyncio.create_task(_runner())

    async def claim_generation_slot(self, *, user_id: int) -> None:
        async with self._generation_attempt_lock:
            now = datetime.now()
            pending_attempt = self._pending_generation_attempts.get(user_id)
            if pending_attempt is not None:
                remaining = int(
                    (pending_attempt + self.generation_request_hold - now).total_seconds()
                )
                if remaining > 0:
                    raise VideoGenerationRateLimitError(
                        wait_seconds=remaining,
                        message=(
                            "当前发布请求正在提交，请勿重复点击。"
                            f"若 {remaining} 秒后仍无反馈，请刷新记录后重试。"
                        ),
                    )
                self._pending_generation_attempts.pop(user_id, None)

            cooldown_started_at = now - self.generation_cooldown

            latest_task = await (
                VideoTask.filter(
                    user_id=user_id,
                    created_at__gte=cooldown_started_at,
                    is_deleted=False,
                    status__in=list(self.processing_statuses),
                )
                .order_by("-created_at")
                .first()
            )
            if latest_task is not None and latest_task.provider_task_id:
                try:
                    latest_task = await self.sync_task_status(latest_task, force=True)
                except Exception:
                    pass

            if latest_task is not None and latest_task.status in self.processing_statuses:
                comparable_now = self._align_datetime(now, latest_task.created_at)
                remaining = int(
                    (
                        latest_task.created_at
                        + self.generation_cooldown
                        - comparable_now
                    ).total_seconds()
                )
                if remaining > 0:
                    raise VideoGenerationRateLimitError(wait_seconds=remaining)

            self._pending_generation_attempts[user_id] = now

    async def release_generation_slot(self, *, user_id: int) -> None:
        async with self._generation_attempt_lock:
            self._pending_generation_attempts.pop(user_id, None)

    async def _should_auto_retry(self, *, task: VideoTask, payload: dict[str, Any]) -> bool:
        if task.provider not in {"openai_compatible", "relay_video"}:
            return False

        retry_count = self._read_retry_count(task.provider_payload or {})
        if retry_count >= self.transient_failure_retry_limit:
            return False

        error_message = (self._read_error_message(payload) or "").strip().lower()
        if not error_message:
            return False

        if any(marker in error_message for marker in self.non_retryable_failure_markers):
            return False
        return any(marker in error_message for marker in self.retryable_failure_markers)

    async def _retry_task_from_request_context(
        self,
        *,
        task: VideoTask,
        payload: dict[str, Any],
        points_cost: int | None = None,
        points_charge_token: str | None = None,
    ) -> VideoTask:
        request_context = self._read_request_context(payload)
        if not request_context:
            return task

        images = await VideoTaskAsset.filter(task_id=task.id).order_by("sort_order").values_list("file_url", flat=True)
        provider, next_payload = await business_gateway_service.recreate_video_from_request_context(
            user_id=task.user_id,
            images=list(images),
            request_context=request_context,
        )
        if not isinstance(next_payload, dict):
            next_payload = {"data": next_payload}

        error_message = self._read_error_message(payload) or ""
        retry_count = self._read_retry_count(task.provider_payload or {}) + 1
        next_payload = self._merge_request_context(
            existing_payload=payload,
            next_payload=next_payload,
        )
        next_payload["app_retry"] = {
            "count": retry_count,
            "max": self.transient_failure_retry_limit,
            "last_error": error_message,
            "previous_provider_task_id": task.provider_task_id or "",
        }

        now = datetime.now()
        task.provider = provider
        task.provider_task_id = self._read_provider_task_id(next_payload) or task.provider_task_id
        task.provider_payload = next_payload
        task.status = self._read_status(next_payload, fallback="queued")
        task.progress = self._read_progress(next_payload, fallback=0)
        task.prompt = self._read_prompt(next_payload) or task.prompt
        task.remote_video_url = self._read_remote_video_url(next_payload)
        task.cos_video_url = self._read_cos_video_url(next_payload)
        task.video_url = self._select_preferred_video_url(
            remote_video_url=task.remote_video_url,
            cos_video_url=task.cos_video_url,
            fallback=self._read_video_url(next_payload) or "",
        )
        task.cover_image_url = self._read_cover_image(next_payload) or task.cover_image_url
        task.error_code = None
        task.error_message = None
        if points_cost is not None:
            task.points_cost = points_cost
        if points_charge_token is not None:
            task.points_charge_token = points_charge_token
            task.points_refunded = False
            task.points_refunded_at = None
        task.started_at = now
        task.finished_at = None
        await task.save()
        await self._refund_task_points_if_needed(task)
        return task

    def _merge_request_context(
        self,
        *,
        existing_payload: dict[str, Any],
        next_payload: dict[str, Any],
    ) -> dict[str, Any]:
        existing_request = self._read_request_context(existing_payload)
        if not existing_request:
            return next_payload

        merged_payload = dict(next_payload)
        next_request = self._read_request_context(next_payload)
        merged_payload["request"] = {
            **existing_request,
            **next_request,
        }
        return merged_payload

    async def get_user_task(
        self,
        *,
        task_id: int,
        user_id: int,
        include_deleted: bool = False,
    ) -> VideoTask:
        filters: dict[str, Any] = {
            "id": task_id,
            "user_id": user_id,
        }
        if not include_deleted:
            filters["is_deleted"] = False
        return await VideoTask.get(**filters)

    async def get_task(self, *, task_id: int, include_deleted: bool = True) -> VideoTask:
        filters: dict[str, Any] = {"id": task_id}
        if not include_deleted:
            filters["is_deleted"] = False
        return await VideoTask.get(**filters)

    async def retry_user_task(
        self,
        *,
        task_id: int,
        user_id: int,
        points_cost: int | None = None,
        points_charge_token: str | None = None,
    ) -> VideoTask:
        task = await self.get_user_task(task_id=task_id, user_id=user_id)
        return await self.retry_task(task, points_cost=points_cost, points_charge_token=points_charge_token)

    async def retry_task(
        self,
        task: VideoTask,
        *,
        points_cost: int | None = None,
        points_charge_token: str | None = None,
    ) -> VideoTask:
        payload = task.provider_payload or {}
        if not isinstance(payload, dict):
            raise ValueError("Task payload is invalid")
        retried_task = await self._retry_task_from_request_context(
            task=task,
            payload=payload,
            points_cost=points_cost,
            points_charge_token=points_charge_token,
        )
        if retried_task.id != task.id:
            return retried_task
        return retried_task

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
        filters: dict[str, Any] = {
            "id": task_id,
            "is_deleted": False,
        }
        if user_id is not None:
            filters["user_id"] = user_id
        task = await VideoTask.get_or_none(**filters)
        if task is None:
            return
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
        video_urls = await self.ensure_task_video_urls(task)
        data = await task.to_dict()
        data["id"] = str(task.id)
        data["prompt"] = task.prompt or ""
        data["display_text"] = self._display_text(task)
        data["video_url"] = video_urls["video_url"]
        data["remote_video_url"] = video_urls["remote_video_url"]
        data["cos_video_url"] = video_urls["cos_video_url"]
        if isinstance(data.get("provider_payload"), dict):
            data["provider_payload"] = self._write_video_urls(
                data["provider_payload"],
                video_url=video_urls["video_url"],
                remote_video_url=video_urls["remote_video_url"],
                cos_video_url=video_urls["cos_video_url"],
            )
        data["error_message"] = self._normalize_error_message(task.error_message) or ""
        data["provider_task_id"] = task.provider_task_id or ""
        data["progress"] = float(task.progress or 0)
        data["is_deleted"] = task.is_deleted
        data["cover_image_url"] = local_media_service.normalize_media_url(task.cover_image_url)
        data["points_cost"] = int(task.points_cost or 0)
        data["points_refunded"] = bool(task.points_refunded)
        request_context = self._read_request_context(task.provider_payload or {})
        data["request_context"] = request_context
        data["creation_mode"] = str(request_context.get("creation_mode") or "simple")
        data["reference_link"] = str(request_context.get("reference_link") or "")
        data["reference_video_path"] = str(request_context.get("reference_video_path") or "")

        if include_assets:
            assets = await VideoTaskAsset.filter(task_id=task.id).order_by("sort_order")
            serialized_assets = []
            for asset in assets:
                asset_data = await asset.to_dict()
                asset_data["file_url"] = local_media_service.normalize_media_url(asset_data.get("file_url"))
                serialized_assets.append(asset_data)
            data["assets"] = serialized_assets
        if include_user:
            user = await User.filter(id=task.user_id).first()
            data["user"] = {
                "id": user.id,
                "username": user.username,
                "alias": user.alias,
                "email": user.email,
            } if user else None
        return data

    async def ensure_task_video_urls(self, task: VideoTask) -> dict[str, str]:
        return await self._ensure_task_video_urls(task)

    async def resolve_public_video_url(self, task: VideoTask) -> str:
        return (await self._ensure_task_video_urls(task))["video_url"]

    async def _ensure_task_video_urls(self, task: VideoTask) -> dict[str, str]:
        current_video_url = str(task.video_url or "").strip()
        remote_video_url = str(task.remote_video_url or "").strip() or self._normalize_remote_video_url(current_video_url)
        cos_video_url = str(task.cos_video_url or "").strip() or self._normalize_cos_video_url(current_video_url)
        source_video_url = self._read_source_video_url(task.provider_payload or {})

        file_name = self._resolve_generated_video_file_name(
            task.id,
            remote_video_url,
            cos_video_url,
            current_video_url,
            source_video_url,
        )
        local_file = local_media_service.generated_video_local_file(task_id=task.id, file_name=file_name)

        if not local_file.exists():
            restore_source = cos_video_url or source_video_url or self._extract_external_video_url(current_video_url)
            if restore_source:
                restored_locations = await self._restore_task_video_file(
                    task=task,
                    source_video_url=restore_source,
                    file_name=file_name,
                )
                remote_video_url = restored_locations["remote_url"] or remote_video_url
                cos_video_url = restored_locations["cos_url"] or cos_video_url
            elif self._normalize_remote_video_url(remote_video_url):
                remote_video_url = ""

        if local_file.exists():
            remote_video_url = local_media_service.generated_video_remote_url(
                task_id=task.id,
                file_name=local_file.name,
            )
            cos_video_url = await self._ensure_cos_video_url(
                task_id=int(task.id),
                file_name=local_file.name,
                current_cos_video_url=cos_video_url,
                local_file=local_file,
            )

        resolved_video_url = self._select_preferred_video_url(
            remote_video_url=remote_video_url if local_file.exists() else "",
            cos_video_url=cos_video_url,
            fallback=self._extract_external_video_url(current_video_url),
        )

        payload = task.provider_payload if isinstance(task.provider_payload, dict) else None
        payload_changed = False
        if payload is not None:
            next_payload = self._write_video_urls(
                payload,
                video_url=resolved_video_url,
                remote_video_url=remote_video_url,
                cos_video_url=cos_video_url,
            )
            payload_changed = next_payload != payload
            if payload_changed:
                task.provider_payload = next_payload

        changed = any(
            (
                (task.remote_video_url or "") != remote_video_url,
                (task.cos_video_url or "") != cos_video_url,
                (task.video_url or "") != resolved_video_url,
                payload_changed,
            )
        )
        if changed:
            task.remote_video_url = remote_video_url or None
            task.cos_video_url = cos_video_url or None
            task.video_url = resolved_video_url or None
            try:
                await task.save()
            except Exception:
                pass

        return {
            "video_url": resolved_video_url,
            "remote_video_url": remote_video_url,
            "cos_video_url": cos_video_url,
        }

    async def _restore_task_video_file(
        self,
        *,
        task: VideoTask,
        source_video_url: str,
        file_name: str,
    ) -> dict[str, str]:
        normalized_source = str(source_video_url or "").strip()
        if not normalized_source:
            return {"remote_url": "", "cos_url": ""}

        try:
            return await local_media_service.ensure_video_storage(
                task_id=int(task.id),
                provider_task_id=str(task.provider_task_id or task.id),
                file_name=file_name,
                content_fetcher=lambda _: self._download_remote_video(normalized_source),
            )
        except Exception:
            return {"remote_url": "", "cos_url": ""}

    async def _ensure_cos_video_url(
        self,
        *,
        task_id: int,
        file_name: str,
        current_cos_video_url: str,
        local_file: Path,
    ) -> str:
        if not object_storage_service.generated_video_storage_enabled():
            return current_cos_video_url

        expected_public_url = object_storage_service.generated_video_public_url(
            task_id=task_id,
            file_name=file_name,
        )
        if await object_storage_service.generated_video_exists(
            task_id=task_id,
            file_name=file_name,
        ):
            return expected_public_url

        try:
            return await object_storage_service.upload_generated_video(
                task_id=task_id,
                file_name=file_name,
                content=local_file.read_bytes(),
            )
        except ObjectStorageError:
            return current_cos_video_url

    async def _download_remote_video(self, url: str) -> bytes:
        timeout = httpx.Timeout(connect=20.0, read=240.0, write=240.0, pool=20.0)
        async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
            response = await client.get(url)
            response.raise_for_status()
            return response.content

    def _resolve_generated_video_file_name(self, task_id: int, *candidates: str) -> str:
        for candidate in candidates:
            file_name = self._extract_generated_video_file_name(candidate)
            if file_name:
                return file_name
        return f"task_{task_id}.mp4"

    def _extract_generated_video_file_name(self, raw_url: str) -> str | None:
        normalized = str(raw_url or "").strip()
        if not normalized:
            return None
        path = urlparse(normalized).path if "://" in normalized else normalized
        file_name = Path(path).name
        return file_name or None

    def _normalize_remote_video_url(self, raw_url: str | None) -> str:
        normalized = str(raw_url or "").strip()
        if not normalized:
            return ""

        parsed_public_base = urlparse((settings.PUBLIC_BASE_URL or "").strip())
        parsed_url = urlparse(normalized)
        if parsed_url.scheme and parsed_url.netloc:
            if parsed_public_base.netloc and parsed_url.netloc != parsed_public_base.netloc:
                return ""
            media_path = parsed_url.path
        else:
            media_path = normalized

        if not media_path.startswith("/"):
            media_path = f"/{media_path}"
        if not media_path.startswith("/media/generated_videos/"):
            return ""

        return local_media_service.media_url(media_path)

    def _normalize_cos_video_url(self, raw_url: str | None) -> str:
        normalized = str(raw_url or "").strip()
        if not normalized or not self._is_cos_url(normalized):
            return ""
        return normalized

    def _extract_external_video_url(self, raw_url: str | None) -> str:
        normalized = str(raw_url or "").strip()
        if not normalized:
            return ""
        if self._normalize_remote_video_url(normalized) or self._normalize_cos_video_url(normalized):
            return ""
        parsed_url = urlparse(normalized)
        if parsed_url.scheme in {"http", "https"} and parsed_url.netloc:
            return normalized
        return ""

    def _is_cos_url(self, raw_url: str) -> bool:
        normalized = str(raw_url or "").strip()
        if not normalized:
            return False

        parsed_url = urlparse(normalized)
        if parsed_url.scheme not in {"http", "https"} or not parsed_url.netloc:
            return False

        public_domain = (settings.COS_PUBLIC_DOMAIN or "").strip()
        expected_hosts = set()
        if public_domain:
            expected_hosts.add(urlparse(public_domain if "://" in public_domain else f"https://{public_domain}").netloc)
        bucket = (settings.COS_BUCKET or "").strip()
        region = (settings.COS_REGION or "").strip()
        if bucket and region:
            expected_hosts.add(f"{bucket}.cos.{region}.myqcloud.com")
        return parsed_url.netloc in {host for host in expected_hosts if host}

    def _write_video_urls(
        self,
        payload: dict[str, Any],
        *,
        video_url: str,
        remote_video_url: str,
        cos_video_url: str,
    ) -> dict[str, Any]:
        next_payload = dict(payload)
        next_payload["video_url"] = video_url
        next_payload["remote_video_url"] = remote_video_url
        next_payload["cos_video_url"] = cos_video_url
        if "videoUrl" in next_payload:
            next_payload.pop("videoUrl", None)

        data = next_payload.get("data")
        if isinstance(data, dict):
            next_data = dict(data)
            next_data["video_url"] = video_url
            next_data["remote_video_url"] = remote_video_url
            next_data["cos_video_url"] = cos_video_url
            next_data.pop("videoUrl", None)
            next_payload["data"] = next_data
        return next_payload

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
                    "prompt": task.prompt or "",
                    "display_text": self._display_text(task),
                }
                if task
                else None
            )
        return data

    @staticmethod
    def _display_text(task: VideoTask) -> str:
        for value in (task.input_text, task.polished_text, task.prompt):
            text = str(value or "").strip()
            if text:
                return text
        return ""

    @staticmethod
    def _align_datetime(value: datetime, reference: datetime) -> datetime:
        if reference.tzinfo is not None and value.tzinfo is None:
            return value.replace(tzinfo=reference.tzinfo)
        if reference.tzinfo is None and value.tzinfo is not None:
            return value.replace(tzinfo=None)
        return value

    @staticmethod
    def _read_payload(payload: dict[str, Any]) -> dict[str, Any]:
        data = payload.get("data")
        if isinstance(data, dict):
            return data
        return payload

    def _read_provider_task_id(self, payload: dict[str, Any]) -> str | None:
        data = self._read_payload(payload)
        value = data.get("id") or data.get("_id") or data.get("taskId") or data.get("task_id")
        return str(value) if value else None

    def _read_prompt(self, payload: dict[str, Any]) -> str | None:
        data = self._read_payload(payload)
        value = data.get("prompt") or data.get("text")
        return str(value) if value else None

    def _read_video_url(self, payload: dict[str, Any]) -> str | None:
        data = self._read_payload(payload)
        value = data.get("video_url") or data.get("videoUrl")
        return str(value) if value else None

    def _read_remote_video_url(self, payload: dict[str, Any]) -> str | None:
        data = self._read_payload(payload)
        value = data.get("remote_video_url") or data.get("remoteVideoUrl")
        if value:
            return self._normalize_remote_video_url(str(value))

        fallback = data.get("video_url") or data.get("videoUrl")
        normalized_fallback = self._normalize_remote_video_url(str(fallback or ""))
        return normalized_fallback or None

    def _read_cos_video_url(self, payload: dict[str, Any]) -> str | None:
        data = self._read_payload(payload)
        value = data.get("cos_video_url") or data.get("cosVideoUrl")
        if value:
            return self._normalize_cos_video_url(str(value))

        fallback = data.get("video_url") or data.get("videoUrl")
        normalized_fallback = self._normalize_cos_video_url(str(fallback or ""))
        return normalized_fallback or None

    def _read_source_video_url(self, payload: dict[str, Any]) -> str:
        data = self._read_payload(payload)
        for key in ("provider_video_url", "source_video_url", "origin_video_url", "original_video_url"):
            value = str(data.get(key) or "").strip()
            if value:
                return value

        fallback = str(data.get("video_url") or data.get("videoUrl") or "").strip()
        return self._extract_external_video_url(fallback)

    @staticmethod
    def _select_preferred_video_url(
        *,
        remote_video_url: str | None,
        cos_video_url: str | None,
        fallback: str | None = None,
    ) -> str:
        for candidate in (cos_video_url, remote_video_url, fallback):
            value = str(candidate or "").strip()
            if value:
                return value
        return ""

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
        return self._normalize_error_message(value)

    def _read_request_context(self, payload: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(payload, dict):
            return {}
        request = payload.get("request")
        return request if isinstance(request, dict) else {}

    def _read_retry_count(self, payload: dict[str, Any]) -> int:
        if not isinstance(payload, dict):
            return 0
        app_retry = payload.get("app_retry")
        if not isinstance(app_retry, dict):
            return 0
        try:
            return max(0, int(app_retry.get("count") or 0))
        except (TypeError, ValueError):
            return 0

    @staticmethod
    def _file_name(path: str) -> str:
        clean_path = path.replace("\\", "/")
        return clean_path.rsplit("/", 1)[-1]

    async def _refund_task_points_if_needed(self, task: VideoTask) -> None:
        if task.status not in {"failed", "cancelled"}:
            return
        if not int(task.points_cost or 0):
            return
        if task.points_refunded:
            return
        charge_token = str(task.points_charge_token or "").strip()
        if not charge_token:
            return
        refunded_ledger, _ = await points_controller.refund_video_generation_points(
            user_id=task.user_id,
            charge_token=charge_token,
            task_id=task.id,
        )
        if refunded_ledger:
            task.points_refunded = True
            task.points_refunded_at = datetime.now()
            await task.save(update_fields=["points_refunded", "points_refunded_at", "updated_at"])

    def _normalize_error_message(self, value: Any) -> str | None:
        extracted = self._extract_error_message(value)
        if not extracted:
            return None
        return normalize_api_error_message(extracted)

    def _extract_error_message(self, value: Any) -> str | None:
        if value is None:
            return None
        if isinstance(value, dict):
            candidate = (
                value.get("message")
                or value.get("msg")
                or value.get("detail")
                or value.get("error_message")
                or value.get("errorMessage")
                or value.get("error")
            )
            return self._extract_error_message(candidate)
        if isinstance(value, list):
            for item in value:
                candidate = self._extract_error_message(item)
                if candidate:
                    return candidate
            return None

        message = str(value).strip()
        if not message:
            return None
        if not (message.startswith("{") or message.startswith("[")):
            return message

        parsed = self._parse_message_payload(message)
        if parsed is None:
            return message
        return self._extract_error_message(parsed)

    @staticmethod
    def _parse_message_payload(message: str) -> Any | None:
        try:
            return json.loads(message)
        except json.JSONDecodeError:
            try:
                return ast.literal_eval(message)
            except (ValueError, SyntaxError):
                return None


task_controller = TaskController()
