from fastapi import APIRouter, Query

from app.controllers.task import task_controller
from app.schemas.base import SuccessExtra

router = APIRouter()


@router.get("/list", summary="List voice transcription logs")
async def list_voice_logs(
    page: int = Query(1, description="Page"),
    page_size: int = Query(10, description="Page size"),
    username: str = Query("", description="Username search"),
    status: str = Query("", description="Recognition status"),
    provider: str = Query("", description="Provider"),
):
    total, items = await task_controller.list_voice_logs(
        page=page,
        page_size=page_size,
        username=username,
        status=status,
        provider=provider,
    )
    data = [await task_controller.serialize_voice_log(item) for item in items]
    return SuccessExtra(data=data, total=total, page=page, page_size=page_size)
