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
                "/media",
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
            name="系统管理",
            path="/system",
            order=1,
            parent_id=0,
            icon="carbon:gui-management",
            is_hidden=False,
            component="Layout",
            keepalive=False,
            redirect="/system/user",
        )
    else:
        parent_menu.name = "系统管理"
        parent_menu.order = 1
        parent_menu.icon = "carbon:gui-management"
        parent_menu.is_hidden = False
        parent_menu.component = "Layout"
        parent_menu.keepalive = False
        parent_menu.redirect = "/system/user"
        await parent_menu.save()

    desired_children = [
        {
            "name": "用户管理",
            "path": "user",
            "order": 1,
            "icon": "material-symbols:person-outline-rounded",
            "component": "/system/user",
        },
        {
            "name": "邀请码管理",
            "path": "invite-code",
            "order": 2,
            "icon": "material-symbols:key-outline-rounded",
            "component": "/system/invite-code",
        },
        {
            "name": "角色管理",
            "path": "role",
            "order": 3,
            "icon": "carbon:user-role",
            "component": "/system/role",
        },
        {
            "name": "菜单管理",
            "path": "menu",
            "order": 4,
            "icon": "material-symbols:list-alt-outline",
            "component": "/system/menu",
        },
        {
            "name": "接口管理",
            "path": "api",
            "order": 5,
            "icon": "ant-design:api-outlined",
            "component": "/system/api",
        },
        {
            "name": "部门管理",
            "path": "dept",
            "order": 6,
            "icon": "mingcute:department-line",
            "component": "/system/dept",
        },
        {
            "name": "审计日志",
            "path": "auditlog",
            "order": 7,
            "icon": "ph:clipboard-text-bold",
            "component": "/system/auditlog",
        },
        {
            "name": "视频任务",
            "path": "task",
            "order": 8,
            "icon": "material-symbols:movie-outline-rounded",
            "component": "/system/task",
        },
        {
            "name": "语音日志",
            "path": "voice-log",
            "order": 9,
            "icon": "material-symbols:graphic-eq-rounded",
            "component": "/system/voice-log",
        },
        {
            "name": "版本发布",
            "path": "app-release",
            "order": 10,
            "icon": "material-symbols:system-update-alt-rounded",
            "component": "/system/app-release",
        },
        {
            "name": "应用配置",
            "path": "app-config",
            "order": 11,
            "icon": "material-symbols:tune-rounded",
            "component": "/system/app-config",
        },
        {
            "name": "AI调试",
            "path": "ai-debug",
            "order": 12,
            "icon": "material-symbols:experiment-outline-rounded",
            "component": "/system/ai-debug",
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
            name="顶部菜单",
            path="/top-menu",
            order=2,
            parent_id=0,
            icon="material-symbols:featured-play-list-outline",
            is_hidden=False,
            component="/top-menu",
            keepalive=False,
            redirect="",
        )
    else:
        top_menu.name = "顶部菜单"
        top_menu.order = 2
        top_menu.icon = "material-symbols:featured-play-list-outline"
        top_menu.is_hidden = False
        top_menu.component = "/top-menu"
        top_menu.keepalive = False
        top_menu.redirect = ""
        await top_menu.save()


async def init_apis():
    await api_controller.refresh_api()


async def init_db():
    await Tortoise.init(config=settings.TORTOISE_ORM)
    await Tortoise.generate_schemas(safe=True)
    await ensure_runtime_schema()


async def ensure_runtime_schema():
    default_connection = settings.TORTOISE_ORM["apps"]["models"]["default_connection"]
    connection = Tortoise.get_connection(default_connection)
    dialect = connection.capabilities.dialect

    if dialect == "sqlite":
        await _ensure_sqlite_schema(connection)
        return

    if dialect == "mysql":
        await _ensure_mysql_schema(connection)


async def _ensure_sqlite_schema(connection):
    statements: list[str] = []

    app_config_columns = await connection.execute_query_dict("PRAGMA table_info('user_app_config')")
    existing_app_config_columns = {str(item.get("name") or "").strip() for item in app_config_columns}
    app_config_missing_columns = {
        "speech_base_url": "VARCHAR(255) NOT NULL DEFAULT 'https://api.99hub.top'",
        "speech_api_key": "VARCHAR(255) NOT NULL DEFAULT ''",
        "speech_model": "VARCHAR(100) NOT NULL DEFAULT 'gpt-4o-mini-audio-preview'",
    }
    statements.extend(
        f'ALTER TABLE "user_app_config" ADD COLUMN "{column}" {definition};'
        for column, definition in app_config_missing_columns.items()
        if column not in existing_app_config_columns
    )

    user_columns = await connection.execute_query_dict("PRAGMA table_info('user')")
    existing_user_columns = {str(item.get("name") or "").strip() for item in user_columns}
    user_missing_columns = {
        "registration_source": "VARCHAR(20) NOT NULL DEFAULT 'admin'",
        "invite_code_id": "BIGINT NULL",
    }
    statements.extend(
        f'ALTER TABLE "user" ADD COLUMN "{column}" {definition};'
        for column, definition in user_missing_columns.items()
        if column not in existing_user_columns
    )

    invite_code_tables = await connection.execute_query_dict(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='invite_code'"
    )
    if not invite_code_tables:
        statements.append(
            """
            CREATE TABLE "invite_code" (
              "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
              "code" VARCHAR(64) NOT NULL UNIQUE,
              "remark" VARCHAR(255),
              "max_uses" INT NOT NULL DEFAULT 1,
              "used_count" INT NOT NULL DEFAULT 0,
              "is_active" INT NOT NULL DEFAULT 1,
              "expires_at" TIMESTAMP,
              "created_by_user_id" BIGINT,
              "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
              "updated_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            CREATE INDEX "idx_invite_code_code" ON "invite_code" ("code");
            CREATE INDEX "idx_invite_code_is_active" ON "invite_code" ("is_active");
            """
        )

    if statements:
        await connection.execute_script("".join(statements))


async def _ensure_mysql_schema(connection):
    current_db = settings.DB_NAME

    app_config_columns = await connection.execute_query_dict(
        f"""
        SELECT COLUMN_NAME AS name
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = '{current_db}' AND TABLE_NAME = 'user_app_config'
        """
    )
    existing_app_config_columns = {str(item.get("name") or "").strip() for item in app_config_columns}
    app_config_missing_columns = {
        "speech_base_url": "VARCHAR(255) NOT NULL DEFAULT 'https://api.99hub.top'",
        "speech_api_key": "VARCHAR(255) NOT NULL DEFAULT ''",
        "speech_model": "VARCHAR(100) NOT NULL DEFAULT 'gpt-4o-mini-audio-preview'",
    }
    for column, definition in app_config_missing_columns.items():
        if column not in existing_app_config_columns:
            await connection.execute_script(
                f"ALTER TABLE `user_app_config` ADD COLUMN `{column}` {definition};"
            )

    user_columns = await connection.execute_query_dict(
        f"""
        SELECT COLUMN_NAME AS name
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = '{current_db}' AND TABLE_NAME = 'user'
        """
    )
    existing_user_columns = {str(item.get("name") or "").strip() for item in user_columns}
    user_missing_columns = {
        "registration_source": "VARCHAR(20) NOT NULL DEFAULT 'admin'",
        "invite_code_id": "BIGINT NULL",
    }
    for column, definition in user_missing_columns.items():
        if column not in existing_user_columns:
            await connection.execute_script(f"ALTER TABLE `user` ADD COLUMN `{column}` {definition};")

    invite_code_tables = await connection.execute_query_dict(
        f"""
        SELECT TABLE_NAME AS name
        FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = '{current_db}' AND TABLE_NAME = 'invite_code'
        """
    )
    if not invite_code_tables:
        await connection.execute_script(
            """
            CREATE TABLE `invite_code` (
              `id` BIGINT NOT NULL AUTO_INCREMENT,
              `code` VARCHAR(64) NOT NULL,
              `remark` VARCHAR(255) NULL,
              `max_uses` INT NOT NULL DEFAULT 1,
              `used_count` INT NOT NULL DEFAULT 0,
              `is_active` TINYINT(1) NOT NULL DEFAULT 1,
              `expires_at` DATETIME NULL,
              `created_by_user_id` BIGINT NULL,
              `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
              `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
              PRIMARY KEY (`id`),
              UNIQUE KEY `uid_invite_code_code` (`code`),
              KEY `idx_invite_code_is_active` (`is_active`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """
        )


async def init_roles():
    admin_role = await Role.filter(name="Admin").first()
    if not admin_role:
        admin_role = await Role.create(name="Admin", desc="Administrator")

    user_role = await Role.filter(name="User").first()
    if not user_role:
        user_role = await Role.create(name="User", desc="Regular user")

    all_apis = await Api.all()
    admin_api_ids = set(await admin_role.apis.all().values_list("id", flat=True))
    missing_admin_apis = [api for api in all_apis if api.id not in admin_api_ids]
    if missing_admin_apis:
        await admin_role.apis.add(*missing_admin_apis)

    all_menus = await Menu.all()
    admin_menu_ids = set(await admin_role.menus.all().values_list("id", flat=True))
    missing_admin_menus = [menu for menu in all_menus if menu.id not in admin_menu_ids]
    if missing_admin_menus:
        await admin_role.menus.add(*missing_admin_menus)

    if not await user_role.menus.all().exists():
        await user_role.menus.add(*all_menus)

    if not await user_role.apis.all().exists():
        basic_apis = await Api.filter(Q(method__in=["GET"]) | Q(tags__icontains="base"))
        if basic_apis:
            await user_role.apis.add(*basic_apis)


async def init_data():
    await init_db()
    await init_superuser()
    await init_menus()
    await init_apis()
    await init_roles()
