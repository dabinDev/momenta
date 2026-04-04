from pathlib import Path
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from tortoise import Tortoise

from app.core.exceptions import SettingNotFound
from app.core.openapi import INFO_DESCRIPTION, INFO_TITLE, apply_custom_openapi
from app.core.init_app import (
    init_data,
    make_middlewares,
    register_exceptions,
    register_routers,
)
from app.services import local_media_service

try:
    from app.settings.config import settings
except ImportError:
    raise SettingNotFound("Can not import settings")


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_data()
    yield
    await Tortoise.close_connections()


def create_app() -> FastAPI:
    local_media_service.ensure_root()
    Path(settings.MEDIA_ROOT).mkdir(parents=True, exist_ok=True)

    app_title = settings.APP_TITLE if settings.APP_TITLE and settings.APP_TITLE != "Vue FastAPI Admin" else INFO_TITLE
    app_description = (
        settings.APP_DESCRIPTION
        if settings.APP_DESCRIPTION and settings.APP_DESCRIPTION != "Description"
        else INFO_DESCRIPTION
    )

    app = FastAPI(
        title=app_title,
        description=app_description,
        version=settings.VERSION,
        openapi_url="/openapi.json",
        middleware=make_middlewares(),
        lifespan=lifespan,
    )
    apply_custom_openapi(app)
    register_exceptions(app)
    register_routers(app, prefix="/api")
    app.mount("/media", StaticFiles(directory=settings.MEDIA_ROOT), name="media")
    return app


app = create_app()
