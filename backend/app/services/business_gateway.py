from __future__ import annotations

from collections.abc import Sequence
from typing import Any

from app.models.video_task import VideoTask
from app.services.ai_template_registry import ai_template_registry_service
from app.services.config_store import get_or_create_user_app_config
from app.services.legacy_gateway import legacy_gateway_service
from app.services.llm_gateway import LLMGatewayError, llm_gateway_service
from app.services.local_media import local_media_service
from app.services.video_gateway import VideoGatewayError, video_gateway_service


class BusinessGatewayService:
    def get_workbench_manifest(self) -> dict[str, Any]:
        return ai_template_registry_service.get_workbench_manifest()

    def list_prompt_templates(self) -> list[dict[str, Any]]:
        return ai_template_registry_service.list_prompt_templates()

    def list_video_templates(self) -> list[dict[str, Any]]:
        return ai_template_registry_service.list_video_templates()

    async def upload_images(
        self,
        *,
        user_id: int,
        files: Sequence[tuple[str, bytes, str]],
    ) -> Any:
        return {"images": await local_media_service.save_uploaded_images(user_id=user_id, files=files)}

    async def upload_reference_video(
        self,
        *,
        user_id: int,
        file: tuple[str, bytes, str],
    ) -> dict[str, str]:
        filename, content, content_type = file
        return await local_media_service.save_uploaded_video(
            user_id=user_id,
            filename=filename,
            content=content,
            content_type=content_type,
        )

    async def correct_text(self, *, user_id: int, text: str) -> Any:
        config = await get_or_create_user_app_config(user_id)
        if not llm_gateway_service.is_configured(config):
            raise LLMGatewayError("文案模型未配置，请先在应用设置中填写 LLM 服务地址、模型和 API Key")
        return await llm_gateway_service.correct_text(config=config, text=text)

    async def polish_text(self, *, user_id: int, text: str) -> Any:
        config = await get_or_create_user_app_config(user_id)
        if not llm_gateway_service.is_configured(config):
            raise LLMGatewayError("文案模型未配置，请先在应用设置中填写 LLM 服务地址、模型和 API Key")
        return await llm_gateway_service.polish_text(config=config, text=text)

    async def generate_prompt(self, *, user_id: int, text: str, prompt_template_key: str | None = None) -> Any:
        prompt_template = ai_template_registry_service.find_prompt_template(prompt_template_key)
        config = await get_or_create_user_app_config(user_id)
        if not llm_gateway_service.is_configured(config):
            raise LLMGatewayError("文案模型未配置，请先在应用设置中填写 LLM 服务地址、模型和 API Key")

        payload = await llm_gateway_service.generate_prompt(
            config=config,
            text=text,
            prompt_template_instruction=ai_template_registry_service.build_prompt_system_prompt(
                prompt_template_key=prompt_template_key,
            ),
        )

        if isinstance(payload, dict) and prompt_template is not None:
            payload.setdefault("prompt_template_key", prompt_template.key)
            payload.setdefault("prompt_template_name", prompt_template.name)
        return payload

    async def generate_video(
        self,
        *,
        user_id: int,
        prompt: str,
        images: list[str],
        duration: int,
        prompt_template_key: str | None = None,
        video_template_key: str | None = None,
    ) -> tuple[str, Any]:
        request_context = ai_template_registry_service.compose_simple_video_request(
            prompt=prompt,
            prompt_template_key=prompt_template_key,
            video_template_key=video_template_key,
            duration=duration,
            has_images=bool(images),
        )
        return await self._create_video_from_request_context(
            user_id=user_id,
            images=images,
            request_context=request_context,
        )

    async def generate_starter_video(
        self,
        *,
        user_id: int,
        prompt: str | None,
        input_text: str | None,
        images: list[str],
        duration: int,
        reference_link: str,
        prompt_template_key: str | None = None,
        video_template_key: str | None = None,
        supplemental_text: str | None = None,
    ) -> tuple[str, Any]:
        request_context = ai_template_registry_service.compose_starter_video_request(
            prompt=prompt,
            input_text=input_text,
            prompt_template_key=prompt_template_key,
            video_template_key=video_template_key,
            duration=duration,
            has_images=bool(images),
            reference_link=reference_link,
            supplemental_text=supplemental_text,
        )
        return await self._create_video_from_request_context(
            user_id=user_id,
            images=images,
            request_context=request_context,
        )

    async def generate_custom_video(
        self,
        *,
        user_id: int,
        prompt: str | None,
        input_text: str | None,
        images: list[str],
        duration: int,
        video_template_key: str,
        prompt_template_key: str | None = None,
        reference_link: str | None = None,
        reference_video_path: str | None = None,
        supplemental_text: str | None = None,
    ) -> tuple[str, Any]:
        request_context = ai_template_registry_service.compose_custom_video_request(
            prompt=prompt,
            input_text=input_text,
            prompt_template_key=prompt_template_key,
            video_template_key=video_template_key,
            duration=duration,
            has_images=bool(images),
            reference_link=reference_link,
            reference_video_path=reference_video_path,
            supplemental_text=supplemental_text,
        )
        return await self._create_video_from_request_context(
            user_id=user_id,
            images=images,
            request_context=request_context,
        )

    async def _create_video_from_request_context(
        self,
        *,
        user_id: int,
        images: list[str],
        request_context: dict[str, Any],
    ) -> tuple[str, Any]:
        provider_prompt = str(request_context["provider_prompt"])
        resolved_duration = int(request_context["duration"])
        resolved_size = str(request_context["size"])

        config = await get_or_create_user_app_config(user_id)
        if not video_gateway_service.is_configured(config):
            raise VideoGatewayError("视频模型未配置，请先在应用设置中填写视频服务地址、模型和 API Key")

        payload = await video_gateway_service.create_video(
            config=config,
            prompt=provider_prompt,
            images=images,
            duration=resolved_duration,
            size=resolved_size,
        )
        return video_gateway_service.provider_name(config), self._merge_video_request(payload, request_context)

    async def recreate_video_from_request_context(
        self,
        *,
        user_id: int,
        images: list[str],
        request_context: dict[str, Any],
    ) -> tuple[str, Any]:
        return await self._create_video_from_request_context(
            user_id=user_id,
            images=images,
            request_context=request_context,
        )

    async def sync_video_status(self, task: VideoTask) -> Any:
        if task.provider in {"openai_compatible", "relay_video"}:
            config = await get_or_create_user_app_config(task.user_id)
            return await video_gateway_service.get_video_status(
                config=config,
                provider_kind=task.provider,
                provider_task_id=task.provider_task_id or "",
                task_id=int(task.id),
            )

        return await legacy_gateway_service.video_status(task.provider_task_id or "")

    @staticmethod
    def _merge_video_request(payload: Any, request_context: dict[str, Any]) -> dict[str, Any]:
        if isinstance(payload, dict):
            merged = dict(payload)
        else:
            merged = {"data": payload}

        existing_request = merged.get("request")
        if isinstance(existing_request, dict):
            merged["request"] = {**existing_request, **request_context}
        else:
            merged["request"] = request_context
        return merged


business_gateway_service = BusinessGatewayService()
