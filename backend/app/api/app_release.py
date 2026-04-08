import asyncio
import mimetypes
from pathlib import Path

from fastapi import APIRouter, HTTPException, Query
from starlette.background import BackgroundTask
from starlette.responses import FileResponse, StreamingResponse

from app.controllers.app_release import app_release_controller
from app.schemas.base import Success

router = APIRouter(prefix="/app/releases", tags=["版本发布"])


async def _iter_cos_stream(body, chunk_size: int = 1024 * 1024):
    while True:
        chunk = await asyncio.to_thread(body.read, chunk_size)
        if not chunk:
            break
        yield chunk


def _close_cos_stream(body) -> None:
    close = getattr(body, "close", None)
    if callable(close):
        close()
        return

    get_raw_stream = getattr(body, "get_raw_stream", None)
    if not callable(get_raw_stream):
        return

    raw_stream = get_raw_stream()
    raw_close = getattr(raw_stream, "close", None)
    if callable(raw_close):
        raw_close()


@router.get("/latest", summary="获取最新版本信息")
async def latest_release(
    platform: str = Query("android", description="平台类型，例如 android"),
    channel: str = Query("lan", description="发布渠道"),
    current_version: str = Query("", description="当前版本号"),
    current_build_number: int = Query(0, ge=0, description="当前构建号"),
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


@router.get("/files/{file_name:path}", summary="下载安装包")
async def download_release_package(file_name: str):
    storage_payload = await app_release_controller.open_release_package_stream(file_name=file_name)
    if storage_payload is not None:
        storage_response = storage_payload.get("response") or {}
        body = storage_response.get("Body")
        if body is not None:
            media_type = (
                storage_response.get("Content-Type")
                or mimetypes.guess_type(file_name)[0]
                or "application/octet-stream"
            )
            headers = {
                "Content-Disposition": (
                    storage_response.get("Content-Disposition")
                    or f'attachment; filename="{Path(file_name).name or "app-release.apk"}"'
                )
            }
            content_length = storage_response.get("Content-Length")
            if content_length:
                headers["Content-Length"] = str(content_length)
            return StreamingResponse(
                _iter_cos_stream(body),
                media_type=media_type,
                headers=headers,
                background=BackgroundTask(_close_cos_stream, body),
            )

    package_path = app_release_controller.release_package_path(file_name=file_name)
    if not package_path.exists() or not package_path.is_file():
        raise HTTPException(status_code=404, detail="安装包不存在")

    media_type = mimetypes.guess_type(package_path.name)[0] or "application/octet-stream"
    return FileResponse(
        path=package_path,
        media_type=media_type,
        filename=package_path.name,
    )


app_release_router = router
