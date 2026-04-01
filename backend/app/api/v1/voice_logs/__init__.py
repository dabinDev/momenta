from fastapi import APIRouter

from .voice_logs import router

voice_logs_router = APIRouter()
voice_logs_router.include_router(router, tags=["Voice Log Admin"])

__all__ = ["voice_logs_router"]
