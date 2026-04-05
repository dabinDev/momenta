from fastapi import APIRouter

from app.core.dependency import DependPermission

from .ai_debug import ai_debug_router
from .apis import apis_router
from .app_configs import app_configs_router
from .app_releases import app_releases_router
from .auditlog import auditlog_router
from .base import base_router
from .depts import depts_router
from .invite_codes import invite_codes_router
from .menus import menus_router
from .model_catalogs import model_catalogs_router
from .point_ledgers import point_ledgers_router
from .recharge_orders import recharge_orders_router
from .roles import roles_router
from .tasks import tasks_router
from .users import users_router
from .voice_logs import voice_logs_router

v1_router = APIRouter()

v1_router.include_router(base_router, prefix="/base")
v1_router.include_router(invite_codes_router, prefix="/invite_code", dependencies=[DependPermission])
v1_router.include_router(users_router, prefix="/user", dependencies=[DependPermission])
v1_router.include_router(roles_router, prefix="/role", dependencies=[DependPermission])
v1_router.include_router(menus_router, prefix="/menu", dependencies=[DependPermission])
v1_router.include_router(apis_router, prefix="/api", dependencies=[DependPermission])
v1_router.include_router(app_configs_router, prefix="/app_config", dependencies=[DependPermission])
v1_router.include_router(model_catalogs_router, prefix="/model_catalog", dependencies=[DependPermission])
v1_router.include_router(point_ledgers_router, prefix="/point_ledger", dependencies=[DependPermission])
v1_router.include_router(recharge_orders_router, prefix="/recharge_order", dependencies=[DependPermission])
v1_router.include_router(ai_debug_router, prefix="/ai_debug", dependencies=[DependPermission])
v1_router.include_router(app_releases_router, prefix="/app_release", dependencies=[DependPermission])
v1_router.include_router(depts_router, prefix="/dept", dependencies=[DependPermission])
v1_router.include_router(auditlog_router, prefix="/auditlog", dependencies=[DependPermission])
v1_router.include_router(tasks_router, prefix="/task", dependencies=[DependPermission])
v1_router.include_router(voice_logs_router, prefix="/voice_log", dependencies=[DependPermission])
