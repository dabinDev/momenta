from __future__ import annotations

from typing import Any

import httpx

from app.models.app_config import UserAppConfig
from app.services.local_media import local_media_service


class VideoGatewayError(Exception):
    pass


class OpenAICompatibleVideoService:
    @staticmethod
    def is_configured(config: UserAppConfig) -> bool:
        return bool(
            (config.video_base_url or "").strip()
            and (config.video_api_key or "").strip()
            and (config.video_model or "").strip()
        )

    async def create_video(
        self,
        *,
        config: UserAppConfig,
        prompt: str,
        images: list[str],
        duration: int,
    ) -> dict[str, Any]:
        base_url = (config.video_base_url or "").rstrip("/")
        timeout = httpx.Timeout(connect=20.0, read=240.0, write=240.0, pool=20.0)

        async with httpx.AsyncClient(base_url=base_url, timeout=timeout, follow_redirects=True) as client:
            try:
                if images:
                    response = await self._create_with_reference_image(
                        client=client,
                        config=config,
                        prompt=prompt,
                        duration=duration,
                        image_location=images[0],
                    )
                else:
                    response = await client.post(
                        "/videos",
                        headers=self._headers(config),
                        json={
                            "model": config.video_model,
                            "prompt": prompt,
                            "seconds": duration,
                            "size": "720x1280",
                        },
                    )
                response.raise_for_status()
            except httpx.HTTPStatusError as exc:
                raise VideoGatewayError(self._read_error_detail(exc.response)) from exc
            except httpx.HTTPError as exc:
                raise VideoGatewayError("Failed to reach configured video service") from exc

        try:
            return response.json()
        except ValueError as exc:
            raise VideoGatewayError("Configured video service returned invalid JSON") from exc

    async def get_video_status(
        self,
        *,
        config: UserAppConfig,
        provider_task_id: str,
        task_id: int,
    ) -> dict[str, Any]:
        base_url = (config.video_base_url or "").rstrip("/")
        timeout = httpx.Timeout(connect=20.0, read=240.0, write=240.0, pool=20.0)

        async with httpx.AsyncClient(base_url=base_url, timeout=timeout, follow_redirects=True) as client:
            try:
                response = await client.get(f"/videos/{provider_task_id}", headers=self._headers(config))
                response.raise_for_status()
            except httpx.HTTPStatusError as exc:
                raise VideoGatewayError(self._read_error_detail(exc.response)) from exc
            except httpx.HTTPError as exc:
                raise VideoGatewayError("Failed to reach configured video service") from exc

        try:
            payload = response.json()
        except ValueError as exc:
            raise VideoGatewayError("Configured video service returned invalid JSON") from exc

        status = str(payload.get("status") or "").lower()
        if status in {"completed", "succeeded", "success"}:
            payload["video_url"] = await local_media_service.ensure_video_file(
                task_id=task_id,
                provider_task_id=provider_task_id,
                content_fetcher=lambda video_id: self.download_video_content(
                    config=config,
                    provider_task_id=video_id,
                ),
            )
        return payload

    async def download_video_content(
        self,
        *,
        config: UserAppConfig,
        provider_task_id: str,
    ) -> bytes:
        base_url = (config.video_base_url or "").rstrip("/")
        timeout = httpx.Timeout(connect=20.0, read=240.0, write=240.0, pool=20.0)

        async with httpx.AsyncClient(base_url=base_url, timeout=timeout, follow_redirects=True) as client:
            try:
                response = await client.get(
                    f"/videos/{provider_task_id}/content",
                    headers=self._headers(config),
                )
                response.raise_for_status()
            except httpx.HTTPStatusError as exc:
                raise VideoGatewayError(self._read_error_detail(exc.response)) from exc
            except httpx.HTTPError as exc:
                raise VideoGatewayError("Failed to download configured video content") from exc

        return response.content

    async def _create_with_reference_image(
        self,
        *,
        client: httpx.AsyncClient,
        config: UserAppConfig,
        prompt: str,
        duration: int,
        image_location: str,
    ) -> httpx.Response:
        image_name, image_bytes, content_type = await local_media_service.read_remote_bytes(image_location)
        files = [
            ("model", (None, config.video_model)),
            ("prompt", (None, prompt)),
            ("seconds", (None, str(duration))),
            ("size", (None, "720x1280")),
            ("input_reference", (image_name, image_bytes, content_type)),
        ]
        return await client.post("/videos", headers=self._headers(config), files=files)

    @staticmethod
    def _headers(config: UserAppConfig) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {config.video_api_key}",
        }

    @staticmethod
    def _read_error_detail(response: httpx.Response) -> str:
        try:
            payload = response.json()
        except ValueError:
            payload = response.text

        if isinstance(payload, dict):
            error = payload.get("error")
            if isinstance(error, dict):
                for key in ("message", "detail", "code"):
                    if error.get(key):
                        return str(error[key])
            for key in ("message", "detail", "error"):
                if payload.get(key):
                    return str(payload[key])
        if isinstance(payload, str) and payload.strip():
            return payload.strip()
        return f"Configured video service request failed with status {response.status_code}"


video_gateway_service = OpenAICompatibleVideoService()
