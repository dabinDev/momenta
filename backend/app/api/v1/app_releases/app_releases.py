from fastapi import APIRouter, Query

from app.controllers.app_release import app_release_controller
from app.schemas.app_release import AppReleaseCreate, AppReleaseUpdate
from app.schemas.base import Success, SuccessExtra

router = APIRouter()


@router.get("/list", summary="List app releases")
async def list_app_releases(
    page: int = Query(1, description="Page"),
    page_size: int = Query(10, description="Page size"),
    platform: str = Query("", description="Platform"),
    channel: str = Query("", description="Channel"),
    keyword: str = Query("", description="Keyword"),
    is_active: bool | None = Query(None, description="Active flag"),
):
    total, items = await app_release_controller.list_releases(
        page=page,
        page_size=page_size,
        platform=platform,
        channel=channel,
        keyword=keyword,
        is_active=is_active,
    )
    data = [await app_release_controller.serialize_release(item) for item in items]
    return SuccessExtra(data=data, total=total, page=page, page_size=page_size)


@router.post("/create", summary="Create app release")
async def create_app_release(release_in: AppReleaseCreate):
    await app_release_controller.create_release(release_in)
    return Success(msg="Created successfully")


@router.post("/update", summary="Update app release")
async def update_app_release(release_in: AppReleaseUpdate):
    await app_release_controller.update_release(release_in)
    return Success(msg="Updated successfully")


@router.delete("/delete", summary="Delete app release")
async def delete_app_release(id: int = Query(..., description="Release ID")):
    await app_release_controller.remove(id=id)
    return Success(msg="Deleted successfully")
