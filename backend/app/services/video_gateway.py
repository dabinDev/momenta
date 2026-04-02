from __future__ import annotations

from typing import Any
from urllib.parse import urlparse

import httpx

from app.models.app_config import UserAppConfig
from app.services.local_media import local_media_service


class VideoGatewayError(Exception):
    pass


class HybridVideoService:
    relay_provider = "relay_video"
    openai_provider = "openai_compatible"

    @staticmethod
    def is_configured(config: UserAppConfig) -> bool:
        return bool(
            (config.video_base_url or "").strip()
            and (config.video_api_key or "").strip()
            and (config.video_model or "").strip()
        )

    def provider_name(self, config: UserAppConfig) -> str:
        if self._uses_relay_api(config):
            return self.relay_provider
        return self.openai_provider

    async def create_video(
        self,
        *,
        config: UserAppConfig,
        prompt: str,
        images: list[str],
        duration: int,
        size: str = "720x1280",
    ) -> dict[str, Any]:
        if self._uses_relay_api(config):
            return await self._create_relay_video(
                config=config,
                prompt=prompt,
                images=images,
                size=size,
            )
        return await self._create_openai_compatible_video(
            config=config,
            prompt=prompt,
            images=images,
            duration=duration,
            size=size,
        )

    async def get_video_status(
        self,
        *,
        config: UserAppConfig,
        provider_kind: str,
        provider_task_id: str,
        task_id: int,
    ) -> dict[str, Any]:
        if provider_kind == self.relay_provider:
            return await self._get_relay_video_status(
                config=config,
                provider_task_id=provider_task_id,
                task_id=task_id,
            )
        return await self._get_openai_compatible_video_status(
            config=config,
            provider_task_id=provider_task_id,
            task_id=task_id,
        )

    async def _create_relay_video(
        self,
        *,
        config: UserAppConfig,
        prompt: str,
        images: list[str],
        size: str,
    ) -> dict[str, Any]:
        base_url = (config.video_base_url or "").strip().rstrip("/")
        timeout = httpx.Timeout(connect=20.0, read=240.0, write=240.0, pool=20.0)
        payload: dict[str, Any] = {
            "model": config.video_model,
            "prompt": prompt,
            "enhance_prompt": True,
            "enable_upsample": True,
            "aspect_ratio": self._size_to_aspect_ratio(size),
        }
        if images:
            payload["images"] = [image for image in images if image]

        async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
            try:
                response = await client.post(
                    self._build_url(base_url, "/v1/video/create"),
                    headers=self._headers(config),
                    json=payload,
                )
                response.raise_for_status()
            except httpx.HTTPStatusError as exc:
                raise VideoGatewayError(self._read_error_detail(exc.response)) from exc
            except httpx.HTTPError as exc:
                raise VideoGatewayError("Failed to reach configured video service") from exc

        try:
            data = response.json()
        except ValueError as exc:
            raise VideoGatewayError("Configured video service returned invalid JSON") from exc

        if isinstance(data, dict):
            data.setdefault("status", "pending")
            data.setdefault("progress", 0)
        return data

    async def _get_relay_video_status(
        self,
        *,
        config: UserAppConfig,
        provider_task_id: str,
        task_id: int,
    ) -> dict[str, Any]:
        base_url = (config.video_base_url or "").strip().rstrip("/")
        timeout = httpx.Timeout(connect=20.0, read=240.0, write=240.0, pool=20.0)

        async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
            try:
                response = await client.get(
                    self._build_url(base_url, "/v1/video/query"),
                    headers=self._headers(config),
                    params={"id": provider_task_id},
                )
                response.raise_for_status()
            except httpx.HTTPStatusError as exc:
                raise VideoGatewayError(self._read_error_detail(exc.response)) from exc
            except httpx.HTTPError as exc:
                raise VideoGatewayError("Failed to reach configured video service") from exc

        try:
            payload = response.json()
        except ValueError as exc:
            raise VideoGatewayError("Configured video service returned invalid JSON") from exc

        data = self._payload_data(payload)
        status = str(data.get("status") or "").lower()
        remote_video_url = str(data.get("video_url") or data.get("videoUrl") or "").strip()

        if status in {"completed", "succeeded", "success"} and remote_video_url:
            data["video_url"] = await local_media_service.ensure_video_file(
                task_id=task_id,
                provider_task_id=provider_task_id,
                content_fetcher=lambda _: self._download_remote_video(remote_video_url),
            )
            data["progress"] = 1
        elif status in {"processing", "running", "in_progress"}:
            data.setdefault("progress", 0.5)
        else:
            data.setdefault("progress", 0)

        return payload

    async def _download_remote_video(self, url: str) -> bytes:
        timeout = httpx.Timeout(connect=20.0, read=240.0, write=240.0, pool=20.0)
        async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
            try:
                response = await client.get(url)
                response.raise_for_status()
            except httpx.HTTPStatusError as exc:
                raise VideoGatewayError(self._read_error_detail(exc.response)) from exc
            except httpx.HTTPError as exc:
                raise VideoGatewayError("Failed to download configured video content") from exc
        return response.content

    async def _create_openai_compatible_video(
        self,
        *,
        config: UserAppConfig,
        prompt: str,
        images: list[str],
        duration: int,
        size: str,
    ) -> dict[str, Any]:
        base_url = (config.video_base_url or "").strip().rstrip("/")
        timeout = httpx.Timeout(connect=20.0, read=240.0, write=240.0, pool=20.0)

        async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
            try:
                if images:
                    response = await self._create_with_reference_image(
                        client=client,
                        config=config,
                        prompt=prompt,
                        duration=duration,
                        size=size,
                        image_location=images[0],
                    )
                else:
                    response = await client.post(
                        self._build_url(base_url, "/v1/videos"),
                        headers=self._headers(config),
                        files=[
                            ("model", (None, config.video_model)),
                            ("prompt", (None, prompt)),
                            ("seconds", (None, str(duration))),
                            ("size", (None, size)),
                            ("watermark", (None, "false")),
                        ],
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

    async def _get_openai_compatible_video_status(
        self,
        *,
        config: UserAppConfig,
        provider_task_id: str,
        task_id: int,
    ) -> dict[str, Any]:
        base_url = (config.video_base_url or "").strip().rstrip("/")
        timeout = httpx.Timeout(connect=20.0, read=240.0, write=240.0, pool=20.0)

        async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
            try:
                response = await client.get(
                    self._build_url(base_url, f"/v1/videos/{provider_task_id}"),
                    headers=self._headers(config),
                )
                response.raise_for_status()
            except httpx.HTTPStatusError as exc:
                raise VideoGatewayError(self._read_error_detail(exc.response)) from exc
            except httpx.HTTPError as exc:
                raise VideoGatewayError("Failed to reach configured video service") from exc

        try:
            payload = response.json()
        except ValueError as exc:
            raise VideoGatewayError("Configured video service returned invalid JSON") from exc

        data = self._payload_data(payload)
        status = str(data.get("status") or "").lower()
        if status in {"completed", "succeeded", "success"}:
            data["video_url"] = await local_media_service.ensure_video_file(
                task_id=task_id,
                provider_task_id=provider_task_id,
                content_fetcher=lambda video_id: self._download_openai_compatible_video_content(
                    config=config,
                    provider_task_id=video_id,
                ),
            )
        return payload

    async def _download_openai_compatible_video_content(
        self,
        *,
        config: UserAppConfig,
        provider_task_id: str,
    ) -> bytes:
        base_url = (config.video_base_url or "").strip().rstrip("/")
        timeout = httpx.Timeout(connect=20.0, read=240.0, write=240.0, pool=20.0)

        async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
            try:
                response = await client.get(
                    self._build_url(base_url, f"/v1/videos/{provider_task_id}/content"),
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
        size: str,
        image_location: str,
    ) -> httpx.Response:
        base_url = (config.video_base_url or "").strip().rstrip("/")
        image_name, image_bytes, content_type = await local_media_service.read_remote_bytes(image_location)
        files = [
            ("model", (None, config.video_model)),
            ("prompt", (None, prompt)),
            ("seconds", (None, str(duration))),
            ("size", (None, size)),
            ("watermark", (None, "false")),
            ("input_reference", (image_name, image_bytes, content_type)),
        ]
        return await client.post(
            self._build_url(base_url, "/v1/videos"),
            headers=self._headers(config),
            files=files,
        )

    @staticmethod
    def _uses_relay_api(config: UserAppConfig) -> bool:
        base_url = (config.video_base_url or "").strip().lower()
        model = (config.video_model or "").strip().lower()
        if model.startswith("veo_"):
            return False
        if model.startswith(("veo3", "veo-")):
            return True
        return any(host in base_url for host in ("api.99hub.top", "api3.wlai.vip", "api.apiplus.org", "zhongzhuan.chat"))

    @staticmethod
    def _build_url(base_url: str, versioned_path: str) -> str:
        normalized_base_url = base_url.rstrip("/")
        parsed = urlparse(normalized_base_url)
        if parsed.path.rstrip("/").endswith("/v1") and versioned_path.startswith("/v1/"):
            return f"{normalized_base_url}{versioned_path.removeprefix('/v1')}"
        return f"{normalized_base_url}{versioned_path}"

    @staticmethod
    def _payload_data(payload: dict[str, Any]) -> dict[str, Any]:
        data = payload.get("data")
        if isinstance(data, dict):
            return data
        return payload

    @staticmethod
    def _headers(config: UserAppConfig) -> dict[str, str]:
        return {
            "Accept": "application/json",
            "Authorization": f"Bearer {config.video_api_key}",
        }

    @staticmethod
    def _size_to_aspect_ratio(size: str) -> str:
        normalized = (size or "").lower().replace(" ", "")
        if "x" not in normalized:
            return "9:16"

        width_text, height_text = normalized.split("x", 1)
        try:
            width = int(width_text)
            height = int(height_text)
        except ValueError:
            return "9:16"

        if width == height:
            return "1:1"
        if width > height:
            return "16:9"
        return "9:16"

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


video_gateway_service = HybridVideoService()
