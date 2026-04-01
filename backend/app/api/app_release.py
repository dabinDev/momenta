from fastapi import APIRouter, Query

from app.controllers.app_release import app_release_controller
from app.schemas.base import Success

router = APIRouter(prefix="/app/releases", tags=["App Release"])


@router.get("/latest", summary="Get latest app release")
async def latest_release(
    platform: str = Query("android", description="Target platform"),
    channel: str = Query("lan", description="Release channel"),
    current_version: str = Query("", description="Current version"),
    current_build_number: int = Query(0, ge=0, description="Current build number"),
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
                "message": "No active release found",
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
            "message": "Update available" if has_update else "Current version is up to date",
            "latest": latest_data,
        }
    )


app_release_router = router
