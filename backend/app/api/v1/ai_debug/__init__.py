from fastapi import APIRouter

from .ai_debug import router

ai_debug_router = APIRouter()
ai_debug_router.include_router(router, tags=["AI Debug Admin"])

__all__ = ["ai_debug_router"]

