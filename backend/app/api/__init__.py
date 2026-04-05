from fastapi import APIRouter

from .app_release import app_release_router
from .points import points_router
from .tasks import tasks_router
from .v1 import v1_router
from .voice import voice_router

api_router = APIRouter()
api_router.include_router(app_release_router)
api_router.include_router(points_router)
api_router.include_router(tasks_router)
api_router.include_router(voice_router)
api_router.include_router(v1_router, prefix="/v1")


__all__ = ["api_router"]
