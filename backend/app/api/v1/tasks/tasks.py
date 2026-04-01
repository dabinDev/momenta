from fastapi import APIRouter, HTTPException, Query

from app.controllers.task import task_controller
from app.schemas.base import Success, SuccessExtra
from app.services.legacy_gateway import LegacyGatewayError
from app.services.local_media import LocalMediaError
from app.services.video_gateway import VideoGatewayError

router = APIRouter()


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
