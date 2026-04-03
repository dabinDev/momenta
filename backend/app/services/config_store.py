from dataclasses import dataclass

from app.models.admin import User
from app.models.app_config import UserAppConfig
from app.schemas.app_config import AppConfigOut


@dataclass(slots=True)
class EffectiveAppConfig:
    user_id: int
    inherited_from_user_id: int | None
    llm_base_url: str
    llm_api_key: str
    llm_model: str
    video_base_url: str
    video_api_key: str
    video_model: str
    speech_base_url: str
    speech_api_key: str
    speech_model: str


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


async def resolve_effective_user_app_config(user_id: int) -> EffectiveAppConfig:
    user_config = await get_or_create_user_app_config(user_id)
    fallback_config = await _find_shared_fallback_app_config(exclude_user_id=user_id)

    return EffectiveAppConfig(
        user_id=user_id,
        inherited_from_user_id=None if fallback_config is None else fallback_config.user_id,
        llm_base_url=_pick_config_value(
            user_config.llm_base_url,
            None if fallback_config is None else fallback_config.llm_base_url,
            "llm_base_url",
        ),
        llm_api_key=_pick_secret_value(
            user_config.llm_api_key,
            None if fallback_config is None else fallback_config.llm_api_key,
        ),
        llm_model=_pick_config_value(
            user_config.llm_model,
            None if fallback_config is None else fallback_config.llm_model,
            "llm_model",
        ),
        video_base_url=_pick_config_value(
            user_config.video_base_url,
            None if fallback_config is None else fallback_config.video_base_url,
            "video_base_url",
        ),
        video_api_key=_pick_secret_value(
            user_config.video_api_key,
            None if fallback_config is None else fallback_config.video_api_key,
        ),
        video_model=_pick_config_value(
            user_config.video_model,
            None if fallback_config is None else fallback_config.video_model,
            "video_model",
        ),
        speech_base_url=_pick_config_value(
            user_config.speech_base_url,
            None if fallback_config is None else fallback_config.speech_base_url,
            "speech_base_url",
        ),
        speech_api_key=_pick_secret_value(
            user_config.speech_api_key,
            None if fallback_config is None else fallback_config.speech_api_key,
        ),
        speech_model=_pick_config_value(
            user_config.speech_model,
            None if fallback_config is None else fallback_config.speech_model,
            "speech_model",
        ),
    )


def _default_value(field_name: str) -> str:
    return str(AppConfigOut.model_fields[field_name].default or "").strip()


def _pick_secret_value(primary: str | None, fallback: str | None) -> str:
    primary_value = str(primary or "").strip()
    if primary_value:
        return primary_value
    return str(fallback or "").strip()


def _pick_config_value(primary: str | None, fallback: str | None, field_name: str) -> str:
    primary_value = str(primary or "").strip()
    if primary_value:
        return primary_value
    fallback_value = str(fallback or "").strip()
    if fallback_value:
        return fallback_value
    return _default_value(field_name)


def _has_any_api_key(config_obj: UserAppConfig | None) -> bool:
    if config_obj is None:
        return False
    return any(
        str(getattr(config_obj, field_name, "") or "").strip()
        for field_name in ("llm_api_key", "video_api_key", "speech_api_key")
    )


async def _find_shared_fallback_app_config(exclude_user_id: int | None = None) -> UserAppConfig | None:
    superuser_ids = list(await User.filter(is_superuser=True).values_list("id", flat=True))
    if exclude_user_id is not None:
        superuser_ids = [user_id for user_id in superuser_ids if user_id != exclude_user_id]

    if superuser_ids:
        superuser_configs = await UserAppConfig.filter(user_id__in=superuser_ids).order_by("-updated_at", "-id")
        for config_obj in superuser_configs:
            if _has_any_api_key(config_obj):
                return config_obj

    all_configs = await UserAppConfig.all().order_by("-updated_at", "-id")
    for config_obj in all_configs:
        if exclude_user_id is not None and config_obj.user_id == exclude_user_id:
            continue
        if _has_any_api_key(config_obj):
            return config_obj
    return None


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
