from fastapi import APIRouter, Query

from app.controllers.points import points_controller
from app.schemas.base import SuccessExtra

router = APIRouter()


@router.get("/list", summary="获取积分流水列表")
async def list_point_ledgers(
    page: int = Query(1, ge=1, description="页码"),
    page_size: int = Query(20, ge=1, le=100, description="每页数量"),
    user_id: int | None = Query(None, description="用户 ID"),
    transaction_type: str = Query("", description="流水类型"),
):
    total, items = await points_controller.list_ledgers(
        page=page,
        page_size=page_size,
        user_id=user_id,
        transaction_type=transaction_type or None,
    )
    data = [await points_controller.serialize_ledger(item) for item in items]
    return SuccessExtra(data=data, total=total, page=page, page_size=page_size)
