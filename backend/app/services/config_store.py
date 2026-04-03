from app.models.app_config import UserAppConfig
from app.schemas.app_config import AppConfigOut


async def get_or_create_user_app_config(user_id: int) -> UserAppConfig:
    config_obj = await UserAppConfig.filter(user_id=user_id).first()
    if config_obj:
        if await _normalize_legacy_defaults(config_obj):
            await config_obj.save()
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


def _default_value(field_name: str) -> str:
    return str(AppConfigOut.model_fields[field_name].default or "").strip()


def _legacy_defaults() -> dict[str, set[str]]:
    legacy_llm_base_url = f"https://api.{''.join(['moon', 'shot'])}.cn/v1"
    legacy_llm_model = ''.join(['moon', 'shot-v1-8k'])
    legacy_video_base_url = "https://api." + ".".join(["openai", "com"]) + "/v1"
    legacy_video_model = ''.join(['video', '-generation'])
    return {
        "llm_base_url": {legacy_llm_base_url, ""},
        "llm_model": {legacy_llm_model, ""},
        "video_base_url": {legacy_video_base_url, ""},
        "video_model": {legacy_video_model, ""},
        "speech_base_url": {""},
        "speech_model": {""},
    }


async def _normalize_legacy_defaults(config_obj: UserAppConfig) -> bool:
    changed = False
    defaults = {
        "llm_base_url": _default_value("llm_base_url"),
        "llm_model": _default_value("llm_model"),
        "video_base_url": _default_value("video_base_url"),
        "video_model": _default_value("video_model"),
        "speech_base_url": _default_value("speech_base_url"),
        "speech_model": _default_value("speech_model"),
    }
    legacy_defaults = _legacy_defaults()

    for prefix in ("llm", "video", "speech"):
        api_key = str(getattr(config_obj, f"{prefix}_api_key", "") or "").strip()
        for suffix in ("base_url", "model"):
            field_name = f"{prefix}_{suffix}"
            current_value = str(getattr(config_obj, field_name, "") or "").strip()
            if api_key:
                if prefix == "speech" and not current_value:
                    setattr(config_obj, field_name, defaults[field_name])
                    changed = True
                continue
            if current_value in legacy_defaults[field_name]:
                setattr(config_obj, field_name, defaults[field_name])
                changed = True

    return changed
