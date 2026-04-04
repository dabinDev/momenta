from __future__ import annotations

import asyncio
import re
from pathlib import PurePosixPath
from typing import Any
from urllib.parse import quote

from app.settings.config import settings


class ObjectStorageError(Exception):
    pass


class ObjectStorageService:
    def __init__(self) -> None:
        self._cos_client: Any | None = None
        self._cos_client_signature: tuple[str, ...] | None = None

    def generated_video_storage_enabled(self) -> bool:
        backend = (settings.GENERATED_VIDEO_STORAGE_BACKEND or "").strip().lower()
        return backend == "cos" and self._cos_configured()

    async def upload_generated_video(
        self,
        *,
        task_id: int,
        file_name: str,
        content: bytes,
        content_type: str = "video/mp4",
    ) -> str:
        if not self.generated_video_storage_enabled():
            raise ObjectStorageError("Generated video object storage is disabled")

        if not content:
            raise ObjectStorageError("Generated video content is empty")

        key = self._build_generated_video_key(task_id=task_id, file_name=file_name)
        await asyncio.to_thread(
            self._upload_to_cos,
            object_key=key,
            content=content,
            content_type=content_type,
        )
        return self._build_public_url(key)

    async def upload_release_package(
        self,
        *,
        file_name: str,
        content: bytes,
        content_type: str = "application/vnd.android.package-archive",
    ) -> dict[str, str]:
        if not self.generated_video_storage_enabled():
            raise ObjectStorageError("COS object storage is disabled")

        if not content:
            raise ObjectStorageError("Release package content is empty")

        normalized_name = self._sanitize_object_name(file_name or "app-release.apk")
        key = self._build_release_package_key(file_name=normalized_name)
        await asyncio.to_thread(
            self._upload_to_cos,
            object_key=key,
            content=content,
            content_type="application/octet-stream",
            content_disposition=self._build_attachment_disposition(normalized_name),
        )
        return {
            "name": normalized_name,
            "object_key": key,
            "download_url": self._build_public_url(key),
            "original_content_type": content_type or "application/vnd.android.package-archive",
        }

    def _cos_configured(self) -> bool:
        return all(
            (
                (settings.COS_SECRET_ID or "").strip(),
                (settings.COS_SECRET_KEY or "").strip(),
                (settings.COS_BUCKET or "").strip(),
            )
        )

    def _build_generated_video_key(self, *, task_id: int, file_name: str) -> str:
        prefix = (settings.COS_VIDEO_KEY_PREFIX or "videos").strip().strip("/")
        base_name = (file_name or f"task_{task_id}.mp4").strip() or f"task_{task_id}.mp4"
        if prefix:
            return f"{prefix}/{base_name}"
        return base_name

    def _build_release_package_key(self, *, file_name: str) -> str:
        prefix = (settings.COS_RELEASE_KEY_PREFIX or "file").strip().strip("/")
        storage_name = self._build_release_package_storage_name(file_name=file_name)
        if prefix:
            return f"{prefix}/{storage_name}"
        return storage_name

    @staticmethod
    def _build_release_package_storage_name(*, file_name: str) -> str:
        normalized_name = ObjectStorageService._sanitize_object_name(file_name or "app-release.apk")
        path = PurePosixPath(normalized_name)
        stem = ObjectStorageService._sanitize_object_name(path.stem or "app-release")
        suffix = path.suffix.lower().lstrip(".")

        if suffix == "apk":
            suffix_hint = "android-package"
        elif suffix == "ipa":
            suffix_hint = "ios-package"
        elif suffix:
            suffix_hint = f"{suffix}-package"
        else:
            suffix_hint = "package"

        return f"{stem}.{suffix_hint}.bin"

    def _upload_to_cos(
        self,
        *,
        object_key: str,
        content: bytes,
        content_type: str,
        content_disposition: str | None = None,
    ) -> None:
        client = self._get_cos_client()
        try:
            object_acl = (settings.COS_OBJECT_ACL or "").strip()
            put_kwargs: dict[str, Any] = {
                "Bucket": (settings.COS_BUCKET or "").strip(),
                "Key": object_key,
                "Body": content,
                "ContentType": content_type or "application/octet-stream",
                "EnableMD5": False,
            }
            if object_acl:
                put_kwargs["ACL"] = object_acl
            if content_disposition:
                put_kwargs["ContentDisposition"] = content_disposition
            client.put_object(**put_kwargs)
        except Exception as exc:  # pragma: no cover
            raise ObjectStorageError(f"Failed to upload generated video to Tencent COS: {exc}") from exc

    def _get_cos_client(self):
        signature = (
            (settings.COS_SECRET_ID or "").strip(),
            (settings.COS_SECRET_KEY or "").strip(),
            (settings.COS_REGION or "").strip(),
            (settings.COS_TOKEN or "").strip(),
            (settings.COS_SCHEME or "https").strip().lower(),
            (settings.COS_ENDPOINT or "").strip(),
        )
        if self._cos_client is not None and self._cos_client_signature == signature:
            return self._cos_client

        try:
            from qcloud_cos import CosConfig, CosS3Client
        except ImportError as exc:
            raise ObjectStorageError(
                "COS SDK is not installed. Run `pip install -U cos-python-sdk-v5` in backend environment."
            ) from exc

        region = (settings.COS_REGION or "").strip() or None
        token = (settings.COS_TOKEN or "").strip() or None
        scheme = (settings.COS_SCHEME or "https").strip().lower() or "https"
        endpoint = (settings.COS_ENDPOINT or "").strip() or None

        config_kwargs: dict[str, Any] = {
            "Region": region,
            "SecretId": (settings.COS_SECRET_ID or "").strip(),
            "SecretKey": (settings.COS_SECRET_KEY or "").strip(),
            "Token": token,
            "Scheme": scheme,
        }
        if endpoint:
            config_kwargs["Endpoint"] = endpoint

        config = CosConfig(**config_kwargs)
        self._cos_client = CosS3Client(config)
        self._cos_client_signature = signature
        return self._cos_client

    def _build_public_url(self, key: str) -> str:
        domain = (settings.COS_PUBLIC_DOMAIN or "").strip().rstrip("/")
        if not domain:
            bucket = (settings.COS_BUCKET or "").strip()
            region = (settings.COS_REGION or "").strip()
            if not bucket or not region:
                raise ObjectStorageError("COS public domain or COS bucket/region is not configured")
            scheme = (settings.COS_SCHEME or "https").strip().lower() or "https"
            domain = f"{scheme}://{bucket}.cos.{region}.myqcloud.com"
        if not domain.startswith(("http://", "https://")):
            domain = f"https://{domain}"
        return f"{domain}/{quote(key, safe='/')}"

    @staticmethod
    def _build_attachment_disposition(file_name: str) -> str:
        normalized_name = ObjectStorageService._sanitize_object_name(file_name or "app-release.apk")
        ascii_name = normalized_name.encode("ascii", "ignore").decode("ascii") or "app-release.apk"
        encoded_name = quote(normalized_name, safe="")
        return f"attachment; filename=\"{ascii_name}\"; filename*=UTF-8''{encoded_name}"

    @staticmethod
    def _sanitize_object_name(file_name: str) -> str:
        normalized = str(file_name or "").strip().replace("\\", "/").split("/")[-1]
        normalized = re.sub(r"\s+", "-", normalized)
        normalized = re.sub(r"[^0-9A-Za-z._-]+", "-", normalized)
        normalized = normalized.strip("._-")
        return normalized or "file.bin"


object_storage_service = ObjectStorageService()
