from __future__ import annotations

import mimetypes
import secrets
from collections.abc import Sequence
from pathlib import Path
from urllib.parse import urlparse

import httpx

from app.settings import settings


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
        target_dir = self._media_root / "generated_videos"
        target_dir.mkdir(parents=True, exist_ok=True)
        target_file = target_dir / f"task_{task_id}.mp4"

        if not target_file.exists():
            content = await content_fetcher(provider_task_id)
            target_file.write_bytes(content)

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
        public_base = settings.PUBLIC_BASE_URL.rstrip("/")
        normalized = location
        if normalized.startswith(public_base):
            normalized = normalized[len(public_base) :]

        if not normalized.startswith("/media/"):
            return None

        relative = normalized.removeprefix("/media/")
        target_file = self._media_root / relative
        if not target_file.exists():
            raise LocalMediaError("Local media file not found")
        return target_file.name, target_file.read_bytes()

    @staticmethod
    def _guess_suffix(content_type: str | None) -> str:
        if not content_type:
            return ""
        return mimetypes.guess_extension(content_type.split(";")[0].strip()) or ""

    @staticmethod
    def _guess_content_type(file_name: str) -> str:
        return mimetypes.guess_type(file_name)[0] or "application/octet-stream"


local_media_service = LocalMediaService()
