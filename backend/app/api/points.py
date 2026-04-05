from fastapi import APIRouter, Query

from app.controllers.invite_code import invite_code_controller
from app.controllers.points import points_controller
from app.controllers.recharge import recharge_controller
from app.core.ctx import CTX_USER_ID
from app.core.dependency import DependAuth
from app.models.admin import User
from app.schemas.base import Success
from app.schemas.recharge import RechargeOrderCreateIn

router = APIRouter(tags=["积分与充值"])


@router.get("/points/summary", summary="获取当前用户积分概况", dependencies=[DependAuth])
async def get_points_summary():
    user_id = CTX_USER_ID.get()
    return Success(data=await points_controller.get_user_summary(user_id=user_id))


@router.get("/invite/overview", summary="获取我的邀请概况", dependencies=[DependAuth])
async def get_invite_overview():
    user_id = CTX_USER_ID.get()
    return Success(data=await invite_code_controller.get_owner_invite_overview(user_id))


@router.get("/points/transactions", summary="获取当前用户积分流水", dependencies=[DependAuth])
async def list_point_transactions(
    page: int = Query(1, ge=1, description="页码"),
    page_size: int = Query(20, ge=1, le=100, description="每页数量"),
):
    user_id = CTX_USER_ID.get()
    total, items = await points_controller.list_ledgers(page=page, page_size=page_size, user_id=user_id)
    return Success(
        data={
            "items": [await points_controller.serialize_ledger(item) for item in items],
            "page": page,
            "page_size": page_size,
            "total": total,
        }
    )


@router.get("/recharge/products", summary="获取积分充值套餐", dependencies=[DependAuth])
async def list_recharge_products():
    user_id = CTX_USER_ID.get()
    user = await User.get(id=user_id)
    feature_flags = await points_controller.get_feature_flags()
    return Success(
        data={
            "items": recharge_controller.list_packages_for_user(user, feature_flags=feature_flags),
            "summary": points_controller.build_user_summary(user, feature_flags=feature_flags),
            "feature_flags": feature_flags,
        }
    )


@router.post("/recharge/orders", summary="创建积分充值订单", dependencies=[DependAuth])
async def create_recharge_order(req_in: RechargeOrderCreateIn):
    user_id = CTX_USER_ID.get()
    order = await recharge_controller.create_order(
        user_id=user_id,
        package_code=req_in.package_code,
        pay_method=req_in.pay_method,
        source="app",
    )
    data = await recharge_controller.serialize_order(order)
    meta = order.meta if isinstance(order.meta, dict) else {}
    return Success(
        msg="充值订单已创建",
        data={
            "order": data,
            "payment_status": order.status,
            "payment_hint": str(meta.get("payment_hint") or ""),
        },
    )


@router.get("/recharge/orders", summary="获取当前用户充值订单", dependencies=[DependAuth])
async def list_current_user_recharge_orders(
    page: int = Query(1, ge=1, description="页码"),
    page_size: int = Query(20, ge=1, le=100, description="每页数量"),
):
    user_id = CTX_USER_ID.get()
    total, items = await recharge_controller.list_orders(page=page, page_size=page_size, user_id=user_id)
    return Success(
        data={
            "items": [await recharge_controller.serialize_order(item) for item in items],
            "page": page,
            "page_size": page_size,
            "total": total,
        }
    )


points_router = router
