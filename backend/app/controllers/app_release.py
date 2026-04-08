from __future__ import annotations

import mimetypes
from datetime import datetime
from pathlib import Path
from urllib.parse import quote, unquote, urlparse

from fastapi.exceptions import HTTPException
from tortoise.expressions import Q

from app.core.crud import CRUDBase
from app.models.app_release import AppRelease
from app.schemas.app_release import AppReleaseCreate, AppReleaseUpdate
from app.services.object_storage import ObjectStorageError, object_storage_service
from app.settings.config import settings


class AppReleaseController(CRUDBase[AppRelease, AppReleaseCreate, AppReleaseUpdate]):
    def __init__(self):
        super().__init__(model=AppRelease)

    async def list_releases(
        self,
        *,
        page: int,
        page_size: int,
        platform: str = "",
        channel: str = "",
        keyword: str = "",
        is_active: bool | None = None,
    ):
        query = Q()
        if platform:
            query &= Q(platform=platform)
        if channel:
            query &= Q(channel=channel)
        if keyword:
            query &= Q(version_name__contains=keyword) | Q(title__contains=keyword)
        if is_active is not None:
            query &= Q(is_active=is_active)
        return await self.list(
            page=page,
            page_size=page_size,
            search=query,
            order=["-is_active", "-published_at", "-build_number", "-id"],
        )

    async def create_release(self, obj_in: AppReleaseCreate) -> AppRelease:
        self._normalize_release_payload(obj_in)
        self._validate_release(obj_in)
        release = await self.create(obj_in)
        if release.is_active:
            await self._activate_release(release)
        return release

    async def update_release(self, obj_in: AppReleaseUpdate) -> AppRelease:
        self._normalize_release_payload(obj_in)
        self._validate_release(obj_in)
        release = await self.update(id=obj_in.id, obj_in=obj_in)
        if release.is_active:
            await self._activate_release(release)
        return release

    async def get_latest_active_release(
        self,
        *,
        platform: str,
        channel: str,
    ) -> AppRelease | None:
        return await AppRelease.filter(
            platform=platform,
            channel=channel,
            is_active=True,
        ).order_by("-published_at", "-build_number", "-id").first()

    async def serialize_release(self, release: AppRelease) -> dict:
        data = await release.to_dict()
        data["download_url"] = self.normalize_download_url(data.get("download_url"))
        return data

    def release_package_path(self, *, file_name: str) -> Path:
        normalized_name = object_storage_service._sanitize_object_name(file_name or "app-release.apk")
        return Path(settings.RELEASE_PACKAGE_ROOT) / normalized_name

    def release_package_download_url(self, *, file_name: str) -> str:
        normalized_name = object_storage_service._sanitize_object_name(file_name or "app-release.apk")
        base_url = (settings.RELEASE_PACKAGE_PUBLIC_BASE_URL or settings.PUBLIC_BASE_URL).rstrip("/")
        return f"{base_url}/api/app/releases/files/{quote(normalized_name)}"

    def normalize_download_url(self, raw_url: str | None) -> str:
        candidate = str(raw_url or "").strip()
        if not candidate:
            return ""

        if self._is_proxy_release_package_url(candidate):
            file_name = self._extract_package_file_name(candidate)
            if file_name:
                return self.release_package_download_url(file_name=file_name)
            return candidate

        file_name = self._extract_package_file_name(candidate)
        if not file_name:
            return candidate

        if (
            self._is_forbidden_default_cos_package_url(candidate)
            or self._is_local_release_package_url(candidate)
        ):
            return self.release_package_download_url(file_name=file_name)
        return candidate

    async def open_release_package_stream(self, *, file_name: str) -> dict | None:
        return await object_storage_service.open_release_package_stream(file_name=file_name)

    async def upload_release_package(
        self,
        *,
        file_name: str,
        content: bytes,
        content_type: str | None,
    ) -> dict[str, str]:
        if not object_storage_service.generated_video_storage_enabled():
            raise HTTPException(status_code=400, detail="COS 存储未启用，无法上传安装包")
        if not file_name.strip():
            raise HTTPException(status_code=400, detail="安装包文件名不能为空")
        if not content:
            raise HTTPException(status_code=400, detail="安装包内容不能为空")

        normalized_content_type = (
            (content_type or "").strip()
            or mimetypes.guess_type(file_name)[0]
            or "application/vnd.android.package-archive"
        )
        try:
            payload = await object_storage_service.upload_release_package(
                file_name=file_name,
                content=content,
                content_type=normalized_content_type,
            )
        except ObjectStorageError as exc:
            raise HTTPException(status_code=502, detail=str(exc)) from exc

        local_path = self.release_package_path(file_name=payload["name"])
        local_path.parent.mkdir(parents=True, exist_ok=True)
        local_path.write_bytes(content)

        payload["storage_url"] = payload["download_url"]
        payload["download_url"] = self.release_package_download_url(file_name=payload["name"])
        return payload

    async def _activate_release(self, release: AppRelease) -> None:
        if release.published_at is None:
            release.published_at = datetime.now()
            await release.save()
        await AppRelease.filter(
            platform=release.platform,
            channel=release.channel,
            is_active=True,
        ).exclude(id=release.id).update(is_active=False)

    def _normalize_release_payload(self, obj_in: AppReleaseCreate | AppReleaseUpdate) -> None:
        obj_in.download_url = self.normalize_download_url(getattr(obj_in, "download_url", ""))

    def _validate_release(self, obj_in: AppReleaseCreate | AppReleaseUpdate) -> None:
        download_url = (obj_in.download_url or "").strip()
        if obj_in.is_active and not download_url:
            raise HTTPException(status_code=400, detail="启用中的版本必须提供下载地址")
        if self._is_forbidden_default_cos_package_url(download_url):
            raise HTTPException(
                status_code=400,
                detail="腾讯 COS 默认域名不能直接公开分发 APK/IPA，请使用系统下载地址或自定义域名",
            )

    @staticmethod
    def _extract_package_file_name(raw_url: str | None) -> str:
        candidate = str(raw_url or "").strip()
        if not candidate:
            return ""
        parsed = urlparse(candidate)
        path_name = unquote(Path(parsed.path).name)
        return object_storage_service._sanitize_object_name(path_name)

    @staticmethod
    def _is_forbidden_default_cos_package_url(raw_url: str | None) -> bool:
        candidate = str(raw_url or "").strip()
        if not candidate:
            return False

        parsed = urlparse(candidate)
        host = (parsed.netloc or "").lower()
        path = (parsed.path or "").lower()
        if not host.endswith(".myqcloud.com"):
            return False
        if ".cos." not in host:
            return False
        return path.endswith(".apk") or path.endswith(".ipa")

    @staticmethod
    def _is_proxy_release_package_url(raw_url: str | None) -> bool:
        candidate = str(raw_url or "").strip()
        if not candidate:
            return False

        parsed = urlparse(candidate)
        return (parsed.path or "").startswith("/api/app/releases/files/")

    @staticmethod
    def _is_local_release_package_url(raw_url: str | None) -> bool:
        candidate = str(raw_url or "").strip()
        if not candidate:
            return False

        parsed = urlparse(candidate)
        return (parsed.path or "").startswith("/file/")


app_release_controller = AppReleaseController()
