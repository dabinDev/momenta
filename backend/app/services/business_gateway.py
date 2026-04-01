from __future__ import annotations

from collections.abc import Sequence
from typing import Any

from app.models.video_task import VideoTask
from app.services.config_store import get_or_create_user_app_config
from app.services.legacy_gateway import legacy_gateway_service
from app.services.llm_gateway import llm_gateway_service
from app.services.local_media import local_media_service
from app.services.video_gateway import video_gateway_service


class BusinessGatewayService:
    async def upload_images(
        self,
        *,
        user_id: int,
        files: Sequence[tuple[str, bytes, str]],
    ) -> Any:
        config = await get_or_create_user_app_config(user_id)
        if video_gateway_service.is_configured(config):
            return {"images": await local_media_service.save_uploaded_images(user_id=user_id, files=files)}
        return await legacy_gateway_service.upload_images(files)

    async def polish_text(self, *, user_id: int, text: str) -> Any:
        config = await get_or_create_user_app_config(user_id)
        if llm_gateway_service.is_configured(config):
            return await llm_gateway_service.polish_text(config=config, text=text)
        return await legacy_gateway_service.polish_text(text)

    async def generate_prompt(self, *, user_id: int, text: str) -> Any:
        config = await get_or_create_user_app_config(user_id)
        if llm_gateway_service.is_configured(config):
            return await llm_gateway_service.generate_prompt(config=config, text=text)
        return await legacy_gateway_service.generate_prompt(text)

    async def generate_video(
        self,
        *,
        user_id: int,
        prompt: str,
        images: list[str],
        duration: int,
    ) -> tuple[str, Any]:
        config = await get_or_create_user_app_config(user_id)
        if video_gateway_service.is_configured(config):
            payload = await video_gateway_service.create_video(
                config=config,
                prompt=prompt,
                images=images,
                duration=duration,
            )
            return "openai_compatible", payload

        payload = await legacy_gateway_service.generate_video(
            prompt=prompt,
            images=images,
            duration=duration,
        )
        return "legacy", payload

    async def sync_video_status(self, task: VideoTask) -> Any:
        if task.provider == "openai_compatible":
            config = await get_or_create_user_app_config(task.user_id)
            return await video_gateway_service.get_video_status(
                config=config,
                provider_task_id=task.provider_task_id or "",
                task_id=int(task.id),
            )

        return await legacy_gateway_service.video_status(task.provider_task_id or "")


business_gateway_service = BusinessGatewayService()
