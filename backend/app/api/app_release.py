from fastapi import APIRouter, Query

from app.controllers.app_release import app_release_controller
from app.schemas.base import Success

router = APIRouter(prefix="/app/releases", tags=["版本发布"])


@router.get("/latest", summary="获取最新版本信息")
async def latest_release(
    platform: str = Query("android", description="平台类型，例如 android。"),
    channel: str = Query("lan", description="发布渠道。"),
    current_version: str = Query("", description="当前版本号。"),
    current_build_number: int = Query(0, ge=0, description="当前构建号。"),
):
    latest = await app_release_controller.get_latest_active_release(platform=platform, channel=channel)
    if latest is None:
        return Success(
            data={
                "platform": platform,
                "channel": channel,
                "current_version": current_version,
                "current_build_number": current_build_number,
                "has_update": False,
                "is_force_update": False,
                "message": "暂无可用版本",
                "latest": None,
            }
        )

    latest_data = await app_release_controller.serialize_release(latest)
    has_update = latest.build_number > current_build_number
    return Success(
        data={
            "platform": platform,
            "channel": channel,
            "current_version": current_version,
            "current_build_number": current_build_number,
            "has_update": has_update,
            "is_force_update": bool(has_update and latest.force_update),
            "message": "发现新版本" if has_update else "当前已是最新版本",
            "latest": latest_data,
        }
    )


app_release_router = router
