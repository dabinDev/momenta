from fastapi import APIRouter

from .app_configs import router

app_configs_router = APIRouter()
app_configs_router.include_router(router, tags=["App Config Admin"])

__all__ = ["app_configs_router"]

