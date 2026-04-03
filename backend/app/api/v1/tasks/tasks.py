from pathlib import Path
from urllib.parse import urlparse

import httpx
from fastapi import APIRouter, HTTPException, Query
from starlette.background import BackgroundTask
from starlette.responses import StreamingResponse

from app.controllers.task import task_controller
from app.schemas.base import Success, SuccessExtra
from app.services.legacy_gateway import LegacyGatewayError
from app.services.local_media import LocalMediaError
from app.services.video_gateway import VideoGatewayError
from app.settings.config import settings

router = APIRouter()


def _resolve_video_url(raw_url: str) -> str:
    normalized = str(raw_url or "").strip()
    if not normalized:
        return ""
    if normalized.startswith("http://") or normalized.startswith("https://"):
        return normalized
    base_url = settings.PUBLIC_BASE_URL.rstrip("/")
    if not normalized.startswith("/"):
        normalized = f"/{normalized}"
    return f"{base_url}{normalized}"


def _download_filename(task_id: int, target_url: str) -> str:
    suffix = Path(urlparse(target_url).path).suffix or ".mp4"
    return f"task_{task_id}{suffix}"


async def _close_download_stream(
    response: httpx.Response,
    client: httpx.AsyncClient,
) -> None:
    await response.aclose()
    await client.aclose()


@router.get("/list", summary="List video tasks")
async def list_tasks(
    page: int = Query(1, description="Page"),
    page_size: int = Query(10, description="Page size"),
    username: str = Query("", description="Username search"),
    status: str = Query("", description="Task status"),
    task_type: str = Query("", description="Task type"),
    include_deleted: bool = Query(False, description="Include deleted tasks"),
):
    total, tasks = await task_controller.list_admin_tasks(
        page=page,
        page_size=page_size,
        username=username,
        status=status,
        task_type=task_type,
        include_deleted=include_deleted,
    )
    data = [await task_controller.serialize_task(task, include_user=True) for task in tasks]
    return SuccessExtra(data=data, total=total, page=page, page_size=page_size)


@router.post("/sync", summary="Refresh task status from upstream")
async def sync_task(task_id: int = Query(..., description="Task ID")):
    task = await task_controller.get_task(task_id=task_id)
    try:
        task = await task_controller.sync_task_status(task, force=True)
    except (LegacyGatewayError, VideoGatewayError, LocalMediaError) as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    return Success(data=await task_controller.serialize_task(task, include_user=True))


@router.get("/download", summary="Download task video")
async def download_task_video(task_id: int = Query(..., description="Task ID")):
    task = await task_controller.get_task(task_id=task_id)
    target_url = _resolve_video_url(task.video_url or "")
    if not target_url:
        raise HTTPException(status_code=404, detail="Task video is not ready")

    client = httpx.AsyncClient(
        timeout=httpx.Timeout(connect=20.0, read=240.0, write=240.0, pool=20.0),
        follow_redirects=True,
    )
    try:
        response = await client.send(
            client.build_request("GET", target_url),
            stream=True,
        )
        response.raise_for_status()
    except httpx.HTTPStatusError as exc:
        await client.aclose()
        raise HTTPException(status_code=exc.response.status_code, detail="Failed to download task video") from exc
    except httpx.HTTPError as exc:
        await client.aclose()
        raise HTTPException(status_code=502, detail="Failed to download task video") from exc

    headers = {
        "Content-Disposition": f'attachment; filename="{_download_filename(task.id, target_url)}"',
    }
    content_length = response.headers.get("content-length")
    if content_length:
        headers["Content-Length"] = content_length

    return StreamingResponse(
        response.aiter_bytes(),
        media_type=response.headers.get("content-type") or "application/octet-stream",
        headers=headers,
        background=BackgroundTask(_close_download_stream, response, client),
    )
