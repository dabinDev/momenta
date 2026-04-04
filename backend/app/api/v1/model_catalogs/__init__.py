from fastapi import APIRouter

from .model_catalogs import router

model_catalogs_router = APIRouter()
model_catalogs_router.include_router(router, tags=["模型目录"])

__all__ = ["model_catalogs_router"]
