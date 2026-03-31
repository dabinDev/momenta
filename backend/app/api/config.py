from fastapi import APIRouter

from app.core.ctx import CTX_USER_ID
from app.core.dependency import DependAuth
from app.models.app_config import UserAppConfig
from app.schemas.app_config import AppConfigIn, AppConfigOut
from app.schemas.base import Success

router = APIRouter(prefix="/config", tags=["基础模块"])


async def _get_or_create_config(user_id: int) -> UserAppConfig:
    config_obj = await UserAppConfig.filter(user_id=user_id).first()
    if config_obj:
        return config_obj
    return await UserAppConfig.create(
        user_id=user_id,
        llm_base_url=AppConfigOut.model_fields["llm_base_url"].default,
        llm_model=AppConfigOut.model_fields["llm_model"].default,
        video_base_url=AppConfigOut.model_fields["video_base_url"].default,
        video_model=AppConfigOut.model_fields["video_model"].default,
    )


def _to_schema(config_obj: UserAppConfig) -> AppConfigOut:
    return AppConfigOut(
        llm_base_url=config_obj.llm_base_url,
        llm_api_key=config_obj.llm_api_key or "",
        llm_model=config_obj.llm_model,
        video_base_url=config_obj.video_base_url,
        video_api_key=config_obj.video_api_key or "",
        video_model=config_obj.video_model,
    )


@router.get("", summary="获取当前用户应用配置", dependencies=[DependAuth])
async def get_config():
    user_id = CTX_USER_ID.get()
    config_obj = await _get_or_create_config(user_id)
    return Success(data=_to_schema(config_obj).model_dump(by_alias=True))


@router.post("", summary="保存当前用户应用配置", dependencies=[DependAuth])
async def save_config(config_in: AppConfigIn):
    user_id = CTX_USER_ID.get()
    config_obj = await _get_or_create_config(user_id)
    config_obj.llm_base_url = config_in.llm_base_url
    config_obj.llm_api_key = config_in.llm_api_key
    config_obj.llm_model = config_in.llm_model
    config_obj.video_base_url = config_in.video_base_url
    config_obj.video_api_key = config_in.video_api_key
    config_obj.video_model = config_in.video_model
    await config_obj.save()
    return Success(data=_to_schema(config_obj).model_dump(by_alias=True))


config_router = router
