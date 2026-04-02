from app.models.app_config import UserAppConfig
from app.schemas.app_config import AppConfigOut


async def get_or_create_user_app_config(user_id: int) -> UserAppConfig:
    config_obj = await UserAppConfig.filter(user_id=user_id).first()
    if config_obj:
        return config_obj

    return await UserAppConfig.create(
        user_id=user_id,
        llm_base_url=AppConfigOut.model_fields["llm_base_url"].default,
        llm_model=AppConfigOut.model_fields["llm_model"].default,
        video_base_url=AppConfigOut.model_fields["video_base_url"].default,
        video_model=AppConfigOut.model_fields["video_model"].default,
        speech_base_url=AppConfigOut.model_fields["speech_base_url"].default,
        speech_model=AppConfigOut.model_fields["speech_model"].default,
    )
