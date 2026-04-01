from fastapi import APIRouter

from .app_releases import router

app_releases_router = APIRouter()
app_releases_router.include_router(router, tags=["App Release Admin"])

__all__ = ["app_releases_router"]
