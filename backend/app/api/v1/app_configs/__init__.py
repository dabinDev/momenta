from fastapi import APIRouter

from .app_configs import router

app_configs_router = APIRouter()
app_configs_router.include_router(router, tags=["应用配置"])

__all__ = ["app_configs_router"]
