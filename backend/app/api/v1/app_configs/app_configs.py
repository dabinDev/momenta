from fastapi import APIRouter, Body, Query

from app.controllers.app_config import app_config_controller
from app.schemas.app_config_admin import AppConfigAdminUpdate
from app.schemas.base import Success, SuccessExtra

router = APIRouter()


@router.get("/list", summary="List user app configs")
async def list_app_configs(
    page: int = Query(1, description="Page"),
    page_size: int = Query(10, description="Page size"),
    keyword: str = Query("", description="Username or email keyword"),
):
    total, data = await app_config_controller.list_configs(
        page=page,
        page_size=page_size,
        keyword=keyword,
    )
    return SuccessExtra(data=data, total=total, page=page, page_size=page_size)


@router.get("/get", summary="Get user app config")
async def get_app_config(user_id: int = Query(..., description="User ID")):
    return Success(data=await app_config_controller.get_config(user_id=user_id))


@router.post("/update", summary="Update user app config")
async def update_app_config(config_in: AppConfigAdminUpdate):
    return Success(data=await app_config_controller.update_config(obj_in=config_in), msg="Updated successfully")


@router.post("/reset", summary="Reset user app config to defaults")
async def reset_app_config(user_id: int = Body(..., embed=True, description="User ID")):
    return Success(data=await app_config_controller.reset_config(user_id=user_id), msg="Reset successfully")

