from fastapi import APIRouter

from .invite_codes import router

invite_codes_router = APIRouter()
invite_codes_router.include_router(router, tags=["邀请码管理"])

__all__ = ["invite_codes_router"]
