from __future__ import annotations

import ipaddress
import mimetypes
import secrets
from collections.abc import Sequence
from pathlib import Path
from urllib.parse import urlparse

import httpx
from loguru import logger

from app.settings import settings
from app.services.object_storage import ObjectStorageError, object_storage_service


class LocalMediaError(Exception):
    pass


class LocalMediaService:
    def __init__(self) -> None:
        self._media_root = Path(settings.MEDIA_ROOT)

    def ensure_root(self) -> None:
        self._media_root.mkdir(parents=True, exist_ok=True)

    def media_url(self, relative_path: str) -> str:
        base_url = settings.PUBLIC_BASE_URL.rstrip("/")
        normalized = relative_path if relative_path.startswith("/") else f"/{relative_path}"
        return f"{base_url}{normalized}"

    def normalize_media_url(self, raw_url: str | None) -> str:
        normalized = str(raw_url or "").strip()
        if not normalized:
            return ""

        parsed = urlparse(normalized)
        if parsed.scheme in {"http", "https"} and parsed.netloc:
            media_path = parsed.path or ""
        else:
            media_path = normalized

        if not media_path.startswith("/media/"):
            return normalized
        return self.media_url(media_path)

    async def save_uploaded_images(
        self,
        *,
        user_id: int,
        files: Sequence[tuple[str, bytes, str]],
    ) -> list[dict[str, str]]:
        return await self._save_uploaded_files(
            user_id=user_id,
            files=files,
            subdir="uploads",
        )

    async def save_uploaded_video(
        self,
        *,
        user_id: int,
        filename: str,
        content: bytes,
        content_type: str | None,
    ) -> dict[str, str]:
        items = await self._save_uploaded_files(
            user_id=user_id,
            files=[(filename, content, content_type or "application/octet-stream")],
            subdir="reference_videos",
        )
        return items[0]

    async def ensure_public_image_url(self, location: str) -> str:
        normalized = (location or "").strip()
        if not normalized:
            raise LocalMediaError("Image location is empty")
        if self._is_public_image_url(normalized):
            return normalized

        file_name, content, content_type = await self.read_remote_bytes(normalized)
        return await self._upload_image_to_proxy(
            file_name=file_name,
            content=content,
            content_type=content_type,
        )

    async def _save_uploaded_files(
        self,
        *,
        user_id: int,
        files: Sequence[tuple[str, bytes, str]],
        subdir: str,
    ) -> list[dict[str, str]]:
        target_dir = self._media_root / subdir / f"user_{user_id}"
        target_dir.mkdir(parents=True, exist_ok=True)

        saved_files: list[dict[str, str]] = []
        for filename, content, content_type in files:
            suffix = Path(filename).suffix or self._guess_suffix(content_type) or ".bin"
            safe_name = f"{secrets.token_hex(8)}{suffix.lower()}"
            target_file = target_dir / safe_name
            target_file.write_bytes(content)

            relative_path = f"/media/{subdir}/user_{user_id}/{safe_name}"
            public_url = self.media_url(relative_path)
            saved_files.append(
                {
                    "path": public_url,
                    "url": public_url,
                    "name": safe_name,
                }
            )
        return saved_files

    async def ensure_video_file(
        self,
        *,
        task_id: int,
        provider_task_id: str,
        content_fetcher,
    ) -> str:
        locations = await self.ensure_video_storage(
            task_id=task_id,
            provider_task_id=provider_task_id,
            content_fetcher=content_fetcher,
        )
        return locations["remote_url"] or locations["cos_url"]

    async def ensure_video_storage(
        self,
        *,
        task_id: int,
        provider_task_id: str,
        content_fetcher,
        file_name: str | None = None,
    ) -> dict[str, str]:
        target_file = self.generated_video_local_file(task_id=task_id, file_name=file_name)
        target_file.parent.mkdir(parents=True, exist_ok=True)

        cached_content: bytes | None = None
        if target_file.exists() and target_file.is_file():
            cached_content = target_file.read_bytes()
        else:
            cached_content = await content_fetcher(provider_task_id)
            target_file.write_bytes(cached_content)

        remote_url = self.generated_video_remote_url(task_id=task_id, file_name=target_file.name)
        cos_url = ""
        if object_storage_service.generated_video_storage_enabled():
            try:
                cos_url = await object_storage_service.upload_generated_video(
                    task_id=task_id,
                    file_name=target_file.name,
                    content=cached_content,
                )
            except ObjectStorageError as exc:
                logger.warning(
                    "generated video upload fallback to local storage for task_id={} provider_task_id={}: {}",
                    task_id,
                    provider_task_id,
                    exc,
                )

        return {
            "file_name": target_file.name,
            "remote_url": remote_url,
            "cos_url": cos_url,
        }

    def generated_video_local_file(self, *, task_id: int, file_name: str | None = None) -> Path:
        normalized_name = (Path(file_name).name if file_name else "").strip() or f"task_{task_id}.mp4"
        return self._media_root / "generated_videos" / normalized_name

    def generated_video_remote_url(self, *, task_id: int, file_name: str | None = None) -> str:
        target_file = self.generated_video_local_file(task_id=task_id, file_name=file_name)
        return self.media_url(f"/media/generated_videos/{target_file.name}")

    async def read_remote_bytes(self, location: str) -> tuple[str, bytes, str]:
        normalized = (location or "").strip()
        if not normalized:
            raise LocalMediaError("Image location is empty")

        local_bytes = self._read_local_media_bytes(normalized)
        if local_bytes is not None:
            file_name, content = local_bytes
            return file_name, content, self._guess_content_type(file_name)

        timeout = httpx.Timeout(connect=20.0, read=120.0, write=120.0, pool=20.0)
        async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
            try:
                response = await client.get(normalized)
                response.raise_for_status()
            except httpx.HTTPError as exc:
                raise LocalMediaError("Failed to fetch reference image") from exc

        file_name = Path(urlparse(normalized).path).name or f"{secrets.token_hex(6)}.jpg"
        content_type = response.headers.get("content-type") or self._guess_content_type(file_name)
        return file_name, response.content, content_type

    def _read_local_media_bytes(self, location: str) -> tuple[str, bytes] | None:
        normalized = str(location or "").strip()
        if not normalized:
            return None

        parsed = urlparse(normalized)
        if parsed.scheme in {"http", "https"} and parsed.netloc:
            normalized = parsed.path or ""
        else:
            public_base = settings.PUBLIC_BASE_URL.rstrip("/")
            if normalized.startswith(public_base):
                normalized = normalized[len(public_base) :]

        if not normalized.startswith("/media/"):
            return None

        relative = normalized.removeprefix("/media/")
        target_file = self._media_root / relative
        if not target_file.exists():
            raise LocalMediaError("Local media file not found")
        return target_file.name, target_file.read_bytes()

    async def _upload_image_to_proxy(
        self,
        *,
        file_name: str,
        content: bytes,
        content_type: str,
    ) -> str:
        timeout = httpx.Timeout(connect=20.0, read=120.0, write=120.0, pool=20.0)
        async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
            try:
                response = await client.post(
                    settings.IMAGE_PROXY_UPLOAD_URL,
                    files={
                        "file": (
                            file_name or f"{secrets.token_hex(6)}.jpg",
                            content,
                            content_type or "application/octet-stream",
                        )
                    },
                )
                response.raise_for_status()
            except httpx.HTTPStatusError as exc:
                raise LocalMediaError(self._read_error_detail(exc.response)) from exc
            except httpx.HTTPError as exc:
                raise LocalMediaError("Failed to upload image to public proxy") from exc

        try:
            payload = response.json()
        except ValueError as exc:
            raise LocalMediaError("Public image proxy returned invalid JSON") from exc

        public_url = str(payload.get("url") or "").strip() if isinstance(payload, dict) else ""
        if not public_url:
            raise LocalMediaError("Public image proxy did not return an image URL")
        return public_url

    @staticmethod
    def _is_public_image_url(location: str) -> bool:
        parsed = urlparse(location)
        if parsed.scheme not in {"http", "https"} or not parsed.hostname:
            return False

        if parsed.port and parsed.port not in {80, 443}:
            return False

        host = parsed.hostname.strip().lower()
        if host in {"localhost", "0.0.0.0"} or host.endswith(".local"):
            return False

        try:
            address = ipaddress.ip_address(host)
        except ValueError:
            return True

        return not (
            address.is_private
            or address.is_loopback
            or address.is_link_local
            or address.is_multicast
            or address.is_reserved
            or address.is_unspecified
        )

    @staticmethod
    def _read_error_detail(response: httpx.Response) -> str:
        try:
            payload = response.json()
        except ValueError:
            payload = response.text

        if isinstance(payload, dict):
            for key in ("error", "message", "detail", "msg", "code"):
                if payload.get(key):
                    return str(payload[key])
        if isinstance(payload, str) and payload.strip():
            return payload.strip()
        return f"Request failed with status {response.status_code}"

    @staticmethod
    def _guess_suffix(content_type: str | None) -> str:
        if not content_type:
            return ""
        return mimetypes.guess_extension(content_type.split(";")[0].strip()) or ""

    @staticmethod
    def _guess_content_type(file_name: str) -> str:
        return mimetypes.guess_type(file_name)[0] or "application/octet-stream"


local_media_service = LocalMediaService()
