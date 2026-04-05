from fastapi import APIRouter

from .point_ledgers import router

point_ledgers_router = APIRouter()
point_ledgers_router.include_router(router, tags=["积分流水"])

__all__ = ["point_ledgers_router"]
