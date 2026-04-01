from fastapi import FastAPI
from fastapi.middleware import Middleware
from fastapi.middleware.cors import CORSMiddleware
from tortoise import Tortoise
from tortoise.expressions import Q

from app.api import api_router
from app.controllers.api import api_controller
from app.controllers.user import UserCreate, user_controller
from app.core.exceptions import (
    DoesNotExist,
    DoesNotExistHandle,
    HTTPException,
    HttpExcHandle,
    IntegrityError,
    IntegrityHandle,
    RequestValidationError,
    RequestValidationHandle,
    ResponseValidationError,
    ResponseValidationHandle,
)
from app.models.admin import Api, Menu, Role
from app.schemas.menus import MenuType
from app.settings.config import settings

from .middlewares import BackGroundTaskMiddleware, HttpAuditLogMiddleware


def make_middlewares():
    return [
        Middleware(
            CORSMiddleware,
            allow_origins=settings.CORS_ORIGINS,
            allow_credentials=settings.CORS_ALLOW_CREDENTIALS,
            allow_methods=settings.CORS_ALLOW_METHODS,
            allow_headers=settings.CORS_ALLOW_HEADERS,
        ),
        Middleware(BackGroundTaskMiddleware),
        Middleware(
            HttpAuditLogMiddleware,
            methods=["GET", "POST", "PUT", "DELETE"],
            exclude_paths=[
                "/api/v1/base/access_token",
                "/docs",
                "/openapi.json",
            ],
        ),
    ]


def register_exceptions(app: FastAPI):
    app.add_exception_handler(DoesNotExist, DoesNotExistHandle)
    app.add_exception_handler(HTTPException, HttpExcHandle)
    app.add_exception_handler(IntegrityError, IntegrityHandle)
    app.add_exception_handler(RequestValidationError, RequestValidationHandle)
    app.add_exception_handler(ResponseValidationError, ResponseValidationHandle)


def register_routers(app: FastAPI, prefix: str = "/api"):
    app.include_router(api_router, prefix=prefix)


async def init_superuser():
    user = await user_controller.model.exists()
    if not user:
        await user_controller.create_user(
            UserCreate(
                username="admin",
                email="admin@admin.com",
                password="123456",
                is_active=True,
                is_superuser=True,
            )
        )


async def init_menus():
    parent_menu = await Menu.filter(path="/system", parent_id=0).first()
    if not parent_menu:
        parent_menu = await Menu.create(
            menu_type=MenuType.CATALOG,
            name="System",
            path="/system",
            order=1,
            parent_id=0,
            icon="carbon:gui-management",
            is_hidden=False,
            component="Layout",
            keepalive=False,
            redirect="/system/user",
        )

    desired_children = [
        {
            "name": "Users",
            "path": "user",
            "order": 1,
            "icon": "material-symbols:person-outline-rounded",
            "component": "/system/user",
        },
        {
            "name": "Roles",
            "path": "role",
            "order": 2,
            "icon": "carbon:user-role",
            "component": "/system/role",
        },
        {
            "name": "Menus",
            "path": "menu",
            "order": 3,
            "icon": "material-symbols:list-alt-outline",
            "component": "/system/menu",
        },
        {
            "name": "APIs",
            "path": "api",
            "order": 4,
            "icon": "ant-design:api-outlined",
            "component": "/system/api",
        },
        {
            "name": "Departments",
            "path": "dept",
            "order": 5,
            "icon": "mingcute:department-line",
            "component": "/system/dept",
        },
        {
            "name": "Audit Logs",
            "path": "auditlog",
            "order": 6,
            "icon": "ph:clipboard-text-bold",
            "component": "/system/auditlog",
        },
        {
            "name": "Video Tasks",
            "path": "task",
            "order": 7,
            "icon": "material-symbols:movie-outline-rounded",
            "component": "/system/task",
        },
        {
            "name": "Voice Logs",
            "path": "voice-log",
            "order": 8,
            "icon": "material-symbols:graphic-eq-rounded",
            "component": "/system/voice-log",
        },
    ]

    for item in desired_children:
        menu = await Menu.filter(parent_id=parent_menu.id, path=item["path"]).first()
        if not menu:
            await Menu.create(
                menu_type=MenuType.MENU,
                name=item["name"],
                path=item["path"],
                order=item["order"],
                parent_id=parent_menu.id,
                icon=item["icon"],
                is_hidden=False,
                component=item["component"],
                keepalive=False,
            )
            continue

        menu.name = item["name"]
        menu.order = item["order"]
        menu.icon = item["icon"]
        menu.component = item["component"]
        menu.is_hidden = False
        menu.keepalive = False
        await menu.save()

    top_menu = await Menu.filter(path="/top-menu", parent_id=0).first()
    if not top_menu:
        await Menu.create(
            menu_type=MenuType.MENU,
            name="Top Menu",
            path="/top-menu",
            order=2,
            parent_id=0,
            icon="material-symbols:featured-play-list-outline",
            is_hidden=False,
            component="/top-menu",
            keepalive=False,
            redirect="",
        )


async def init_apis():
    await api_controller.refresh_api()


async def init_db():
    await Tortoise.init(config=settings.TORTOISE_ORM)
    await Tortoise.generate_schemas(safe=True)


async def init_roles():
    roles = await Role.exists()
    if not roles:
        admin_role = await Role.create(name="Admin", desc="Administrator")
        user_role = await Role.create(name="User", desc="Regular user")

        all_apis = await Api.all()
        await admin_role.apis.add(*all_apis)

        all_menus = await Menu.all()
        await admin_role.menus.add(*all_menus)
        await user_role.menus.add(*all_menus)

        basic_apis = await Api.filter(Q(method__in=["GET"]) | Q(tags__icontains="base"))
        if basic_apis:
            await user_role.apis.add(*basic_apis)


async def init_data():
    await init_db()
    await init_superuser()
    await init_menus()
    await init_apis()
    await init_roles()
