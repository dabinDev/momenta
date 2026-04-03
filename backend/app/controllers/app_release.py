from __future__ import annotations

from datetime import datetime

from tortoise.expressions import Q

from app.core.crud import CRUDBase
from fastapi.exceptions import HTTPException
from app.models.app_release import AppRelease
from app.schemas.app_release import AppReleaseCreate, AppReleaseUpdate


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
        self._validate_release(obj_in)
        release = await self.create(obj_in)
        if release.is_active:
            await self._activate_release(release)
        return release

    async def update_release(self, obj_in: AppReleaseUpdate) -> AppRelease:
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

    @staticmethod
    async def serialize_release(release: AppRelease) -> dict:
        return await release.to_dict()

    async def _activate_release(self, release: AppRelease) -> None:
        if release.published_at is None:
            release.published_at = datetime.now()
            await release.save()
        await AppRelease.filter(
            platform=release.platform,
            channel=release.channel,
            is_active=True,
        ).exclude(id=release.id).update(is_active=False)

    @staticmethod
    def _validate_release(obj_in: AppReleaseCreate | AppReleaseUpdate) -> None:
        if obj_in.is_active and not (obj_in.download_url or "").strip():
            raise HTTPException(status_code=400, detail="Active release must provide download URL")


app_release_controller = AppReleaseController()
