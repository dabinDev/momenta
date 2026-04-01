from __future__ import annotations

from collections.abc import Sequence
from typing import Any

import httpx

from app.settings import settings


class LegacyGatewayError(Exception):
    pass


class LegacyGatewayService:
    def _ensure_base_url(self) -> str:
        base_url = (settings.SERVER_BASE_URL or "").strip()
        if not base_url:
            raise LegacyGatewayError("SERVER_BASE_URL is not configured")
        return base_url.rstrip("/")

    async def upload_images(self, files: Sequence[tuple[str, bytes, str]]) -> Any:
        request_files = [
            ("images", (filename, content, content_type))
            for filename, content, content_type in files
        ]
        return await self._request("POST", "/api/upload-images", files=request_files)

    async def polish_text(self, text: str) -> Any:
        return await self._request("POST", "/api/polish-text", json={"text": text})

    async def generate_prompt(self, text: str) -> Any:
        return await self._request("POST", "/api/generate-prompt", json={"text": text})

    async def generate_video(self, *, prompt: str, images: list[str], duration: int) -> Any:
        return await self._request(
            "POST",
            "/api/generate-video",
            json={
                "prompt": prompt,
                "images": images,
                "duration": duration,
            },
        )

    async def video_status(self, provider_task_id: str) -> Any:
        return await self._request("GET", f"/api/video-status/{provider_task_id}")

    async def _request(self, method: str, path: str, **kwargs) -> Any:
        base_url = self._ensure_base_url()
        timeout = httpx.Timeout(connect=20.0, read=120.0, write=120.0, pool=20.0)
        async with httpx.AsyncClient(base_url=base_url, timeout=timeout, follow_redirects=True) as client:
            try:
                response = await client.request(method, path, **kwargs)
                response.raise_for_status()
            except httpx.HTTPStatusError as exc:
                detail = self._read_error_detail(exc.response)
                raise LegacyGatewayError(detail) from exc
            except httpx.HTTPError as exc:
                raise LegacyGatewayError("Failed to reach legacy business service") from exc

        try:
            return response.json()
        except ValueError as exc:
            raise LegacyGatewayError("Legacy business service returned invalid JSON") from exc

    @staticmethod
    def _read_error_detail(response: httpx.Response) -> str:
        try:
            payload = response.json()
        except ValueError:
            payload = response.text

        if isinstance(payload, dict):
            for key in ("msg", "message", "detail", "error"):
                value = payload.get(key)
                if value:
                    return str(value)
        if isinstance(payload, str) and payload.strip():
            return payload.strip()
        return f"Legacy business service request failed with status {response.status_code}"


legacy_gateway_service = LegacyGatewayService()
