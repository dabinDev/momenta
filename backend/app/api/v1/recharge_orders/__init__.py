from fastapi import APIRouter

from .recharge_orders import router

recharge_orders_router = APIRouter()
recharge_orders_router.include_router(router, tags=["充值订单"])

__all__ = ["recharge_orders_router"]
