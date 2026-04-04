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
    user_exists = await user_controller.model.exists()
    if not user_exists:
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
    legacy_parent = await Menu.filter(path="/system", parent_id=0).first()
    if legacy_parent:
        legacy_parent.name = "系统入口"
        legacy_parent.order = 99
        legacy_parent.icon = "carbon:gui-management"
        legacy_parent.is_hidden = True
        legacy_parent.component = "Layout"
        legacy_parent.keepalive = False
        legacy_parent.redirect = ""
        await legacy_parent.save()

    groups = [
        {
            "path": "/access",
            "name": "用户与权限",
            "order": 1,
            "icon": "material-symbols:admin-panel-settings-outline-rounded",
            "redirect": "/access/user",
            "children": [
                {"path": "user", "name": "用户管理", "order": 1, "icon": "material-symbols:person-outline-rounded", "component": "/system/user"},
                {"path": "invite-code", "name": "邀请码管理", "order": 2, "icon": "material-symbols:key-outline-rounded", "component": "/system/invite-code"},
                {"path": "role", "name": "角色管理", "order": 3, "icon": "carbon:user-role", "component": "/system/role"},
                {"path": "dept", "name": "部门管理", "order": 4, "icon": "mingcute:department-line", "component": "/system/dept"},
            ],
        },
        {
            "path": "/operation",
            "name": "运营与任务",
            "order": 2,
            "icon": "material-symbols:movie-info-outline-rounded",
            "redirect": "/operation/task",
            "children": [
                {"path": "task", "name": "视频任务", "order": 1, "icon": "material-symbols:movie-outline-rounded", "component": "/system/task"},
                {"path": "voice-log", "name": "语音日志", "order": 2, "icon": "material-symbols:graphic-eq-rounded", "component": "/system/voice-log"},
                {"path": "app-release", "name": "版本发布", "order": 3, "icon": "material-symbols:system-update-alt-rounded", "component": "/system/app-release"},
            ],
        },
        {
            "path": "/config",
            "name": "配置与审计",
            "order": 3,
            "icon": "material-symbols:tune-rounded",
            "redirect": "/config/app-config",
            "children": [
                {"path": "app-config", "name": "平台配置", "order": 1, "icon": "material-symbols:hub-rounded", "component": "/system/app-config"},
                {"path": "model-center", "name": "模型管理", "order": 2, "icon": "material-symbols:view-in-ar-outline-rounded", "component": "/system/model-center"},
                {"path": "menu", "name": "菜单管理", "order": 3, "icon": "material-symbols:list-alt-outline", "component": "/system/menu"},
                {"path": "api", "name": "接口管理", "order": 4, "icon": "ant-design:api-outlined", "component": "/system/api"},
                {"path": "auditlog", "name": "审计日志", "order": 5, "icon": "ph:clipboard-text-bold", "component": "/system/auditlog"},
                {"path": "ai-debug", "name": "AI调试台", "order": 6, "icon": "material-symbols:experiment-outline-rounded", "component": "/system/ai-debug"},
            ],
        },
    ]

    for group in groups:
        parent = await Menu.filter(path=group["path"], parent_id=0).first()
        if not parent:
            parent = await Menu.create(
                menu_type=MenuType.CATALOG,
                name=group["name"],
                path=group["path"],
                order=group["order"],
                parent_id=0,
                icon=group["icon"],
                is_hidden=False,
                component="Layout",
                keepalive=False,
                redirect=group["redirect"],
            )
        else:
            parent.name = group["name"]
            parent.order = group["order"]
            parent.icon = group["icon"]
            parent.is_hidden = False
            parent.component = "Layout"
            parent.keepalive = False
            parent.redirect = group["redirect"]
            await parent.save()

        for item in group["children"]:
            menu = await Menu.filter(component=item["component"]).first()
            if not menu:
                await Menu.create(
                    menu_type=MenuType.MENU,
                    name=item["name"],
                    path=item["path"],
                    order=item["order"],
                    parent_id=parent.id,
                    icon=item["icon"],
                    is_hidden=False,
                    component=item["component"],
                    keepalive=False,
                )
                continue

            menu.name = item["name"]
            menu.path = item["path"]
            menu.order = item["order"]
            menu.parent_id = parent.id
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
            order=10,
            parent_id=0,
            icon="material-symbols:featured-play-list-outline",
            is_hidden=False,
            component="/top-menu",
            keepalive=False,
            redirect="",
        )
    else:
        top_menu.name = "顶部菜单"
        top_menu.order = 10
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
        "override_enabled": "INTEGER NOT NULL DEFAULT 0",
        "provider_base_url": "VARCHAR(255) NOT NULL DEFAULT ''",
        "provider_api_key": "VARCHAR(255) NOT NULL DEFAULT ''",
        "speech_base_url": "VARCHAR(255) NOT NULL DEFAULT ''",
        "speech_api_key": "VARCHAR(255) NOT NULL DEFAULT ''",
        "speech_model": "VARCHAR(120) NOT NULL DEFAULT ''",
        "image_base_url": "VARCHAR(255) NOT NULL DEFAULT ''",
        "image_api_key": "VARCHAR(255) NOT NULL DEFAULT ''",
        "image_model": "VARCHAR(120) NOT NULL DEFAULT ''",
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
        "allow_private_ai_override": "INTEGER NOT NULL DEFAULT 0",
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
        "override_enabled": "TINYINT(1) NOT NULL DEFAULT 0",
        "provider_base_url": "VARCHAR(255) NOT NULL DEFAULT ''",
        "provider_api_key": "VARCHAR(255) NOT NULL DEFAULT ''",
        "speech_base_url": "VARCHAR(255) NOT NULL DEFAULT ''",
        "speech_api_key": "VARCHAR(255) NOT NULL DEFAULT ''",
        "speech_model": "VARCHAR(120) NOT NULL DEFAULT ''",
        "image_base_url": "VARCHAR(255) NOT NULL DEFAULT ''",
        "image_api_key": "VARCHAR(255) NOT NULL DEFAULT ''",
        "image_model": "VARCHAR(120) NOT NULL DEFAULT ''",
    }
    for column, definition in app_config_missing_columns.items():
        if column not in existing_app_config_columns:
            await connection.execute_script(f"ALTER TABLE `user_app_config` ADD COLUMN `{column}` {definition};")

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
        "allow_private_ai_override": "TINYINT(1) NOT NULL DEFAULT 0",
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
