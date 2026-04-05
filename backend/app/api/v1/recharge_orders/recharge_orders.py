from fastapi import APIRouter, Query

from app.controllers.recharge import recharge_controller
from app.core.ctx import CTX_USER_ID
from app.schemas.base import Success, SuccessExtra
from app.schemas.recharge import RechargeOrderStatusIn

router = APIRouter()


@router.get("/list", summary="获取充值订单列表")
async def list_recharge_orders(
    page: int = Query(1, ge=1, description="页码"),
    page_size: int = Query(10, ge=1, le=100, description="每页数量"),
    user_id: int | None = Query(None, description="用户 ID"),
    status: str = Query("", description="订单状态"),
):
    total, items = await recharge_controller.list_orders(
        page=page,
        page_size=page_size,
        user_id=user_id,
        status=status or None,
    )
    data = [await recharge_controller.serialize_order(item) for item in items]
    return SuccessExtra(data=data, total=total, page=page, page_size=page_size)


@router.post("/update_status", summary="更新充值订单状态")
async def update_recharge_order_status(req_in: RechargeOrderStatusIn):
    order = await recharge_controller.update_order_status(
        order_no=req_in.order_no,
        status=req_in.status,
        operator_user_id=CTX_USER_ID.get(None),
        remark=req_in.remark,
    )
    return Success(msg="充值订单状态已更新", data=await recharge_controller.serialize_order(order))
