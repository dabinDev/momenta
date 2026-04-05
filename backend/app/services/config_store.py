from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from app.models.admin import User
from app.models.app_config import PlatformAIConfig, UserAppConfig
from app.schemas.app_config import AppConfigOut

GLOBAL_CONFIG_KEY = "default"
SERVICE_TYPES = ("llm", "video", "speech", "image")
FEATURE_SWITCH_FIELDS = (
    "points_enabled",
    "recharge_enabled",
    "wechat_pay_enabled",
    "alipay_pay_enabled",
)
DEFAULT_VIDEO_GENERATION_COST = 10


@dataclass(slots=True)
class EffectiveAppConfig:
    user_id: int
    config_source: str
    using_private_override: bool
    provider_base_url: str
    provider_api_key: str
    llm_base_url: str
    llm_api_key: str
    llm_model: str
    video_base_url: str
    video_api_key: str
    video_model: str
    speech_base_url: str
    speech_api_key: str
    speech_model: str
    image_base_url: str
    image_api_key: str
    image_model: str


def default_app_config_values() -> dict[str, str]:
    return {
        "provider_base_url": _default_value("provider_base_url"),
        "provider_api_key": _default_value("provider_api_key"),
        "llm_base_url": _default_value("llm_base_url"),
        "llm_api_key": _default_value("llm_api_key"),
        "llm_model": _default_value("llm_model"),
        "video_base_url": _default_value("video_base_url"),
        "video_api_key": _default_value("video_api_key"),
        "video_model": _default_value("video_model"),
        "speech_base_url": _default_value("speech_base_url"),
        "speech_api_key": _default_value("speech_api_key"),
        "speech_model": _default_value("speech_model"),
        "image_base_url": _default_value("image_base_url"),
        "image_api_key": _default_value("image_api_key"),
        "image_model": _default_value("image_model"),
    }


def default_app_feature_values() -> dict[str, bool | int]:
    return {
        "points_enabled": True,
        "recharge_enabled": True,
        "video_generation_cost": DEFAULT_VIDEO_GENERATION_COST,
        "wechat_pay_enabled": True,
        "alipay_pay_enabled": False,
    }


def default_private_override_values() -> dict[str, str | bool]:
    return {
        "override_enabled": False,
        "provider_base_url": "",
        "provider_api_key": "",
        "llm_base_url": "",
        "llm_api_key": "",
        "llm_model": "",
        "video_base_url": "",
        "video_api_key": "",
        "video_model": "",
        "speech_base_url": "",
        "speech_api_key": "",
        "speech_model": "",
        "image_base_url": "",
        "image_api_key": "",
        "image_model": "",
    }


async def get_or_create_global_ai_config() -> PlatformAIConfig:
    config_obj = await PlatformAIConfig.filter(config_key=GLOBAL_CONFIG_KEY).first()
    if config_obj:
        if await _normalize_platform_config(config_obj):
            await config_obj.save()
        return config_obj

    payload = {
        **default_app_config_values(),
        **default_app_feature_values(),
    }
    seed = await _find_seed_user_config()
    if seed is not None:
        payload["provider_base_url"] = _first_nonempty(
            getattr(seed, "provider_base_url", ""),
            getattr(seed, "llm_base_url", ""),
            getattr(seed, "video_base_url", ""),
            getattr(seed, "speech_base_url", ""),
            payload["provider_base_url"],
        )
        payload["provider_api_key"] = _first_nonempty(
            getattr(seed, "provider_api_key", ""),
            getattr(seed, "llm_api_key", ""),
            getattr(seed, "video_api_key", ""),
            getattr(seed, "speech_api_key", ""),
        )
        for field_name in (
            "llm_base_url",
            "llm_api_key",
            "llm_model",
            "video_base_url",
            "video_api_key",
            "video_model",
            "speech_base_url",
            "speech_api_key",
            "speech_model",
            "image_base_url",
            "image_api_key",
            "image_model",
        ):
            payload[field_name] = _first_nonempty(getattr(seed, field_name, ""), payload[field_name])

    return await PlatformAIConfig.create(config_key=GLOBAL_CONFIG_KEY, **payload)


async def get_user_app_config(user_id: int, *, create: bool = False) -> UserAppConfig | None:
    config_obj = await UserAppConfig.filter(user_id=user_id).first()
    if config_obj is not None or not create:
        return config_obj
    return await UserAppConfig.create(user_id=user_id, **default_private_override_values())


async def get_or_create_user_app_config(user_id: int) -> UserAppConfig:
    config_obj = await get_user_app_config(user_id, create=True)
    if config_obj is None:
        raise RuntimeError("failed to create user override config")
    return config_obj


async def resolve_effective_user_app_config(user_id: int) -> EffectiveAppConfig:
    user = await User.get(id=user_id)
    global_config = await get_or_create_global_ai_config()
    user_config = await get_user_app_config(user_id, create=False)
    use_private_override = bool(
        user.allow_private_ai_override
        and user_config is not None
        and bool(getattr(user_config, "override_enabled", False))
    )

    primary_config = user_config if use_private_override else None
    provider_base_url = _pick_config_value(
        getattr(primary_config, "provider_base_url", ""),
        getattr(global_config, "provider_base_url", ""),
        "provider_base_url",
    )
    provider_api_key = _pick_secret_value(
        getattr(primary_config, "provider_api_key", ""),
        getattr(global_config, "provider_api_key", ""),
    )

    return EffectiveAppConfig(
        user_id=user_id,
        config_source="user" if use_private_override else "global",
        using_private_override=use_private_override,
        provider_base_url=provider_base_url,
        provider_api_key=provider_api_key,
        llm_base_url=_resolve_service_base_url(primary_config, global_config, "llm", provider_base_url),
        llm_api_key=_resolve_service_api_key(primary_config, global_config, "llm", provider_api_key),
        llm_model=_resolve_model_value(primary_config, global_config, "llm_model"),
        video_base_url=_resolve_service_base_url(primary_config, global_config, "video", provider_base_url),
        video_api_key=_resolve_service_api_key(primary_config, global_config, "video", provider_api_key),
        video_model=_resolve_model_value(primary_config, global_config, "video_model"),
        speech_base_url=_resolve_service_base_url(primary_config, global_config, "speech", provider_base_url),
        speech_api_key=_resolve_service_api_key(primary_config, global_config, "speech", provider_api_key),
        speech_model=_resolve_model_value(primary_config, global_config, "speech_model"),
        image_base_url=_resolve_service_base_url(primary_config, global_config, "image", provider_base_url),
        image_api_key=_resolve_service_api_key(primary_config, global_config, "image", provider_api_key),
        image_model=_resolve_model_value(primary_config, global_config, "image_model"),
    )


def read_global_feature_settings(config_obj) -> dict[str, bool | int]:
    defaults = default_app_feature_values()
    normalized = normalize_global_feature_settings(
        {
            "points_enabled": bool(getattr(config_obj, "points_enabled", defaults["points_enabled"])),
            "recharge_enabled": bool(getattr(config_obj, "recharge_enabled", defaults["recharge_enabled"])),
            "wechat_pay_enabled": bool(getattr(config_obj, "wechat_pay_enabled", defaults["wechat_pay_enabled"])),
            "alipay_pay_enabled": bool(getattr(config_obj, "alipay_pay_enabled", defaults["alipay_pay_enabled"])),
            "video_generation_cost": _normalize_non_negative_int(
                getattr(config_obj, "video_generation_cost", defaults["video_generation_cost"]),
                default=int(defaults["video_generation_cost"]),
            ),
        }
    )
    return normalized


def read_global_feature_switches(config_obj) -> dict[str, bool]:
    settings = read_global_feature_settings(config_obj)
    return {
        field_name: bool(settings[field_name])
        for field_name in FEATURE_SWITCH_FIELDS
    }


def build_client_feature_flags(config_obj) -> dict[str, bool]:
    switches = read_global_feature_switches(config_obj)
    return {
        "points_enabled": bool(switches["points_enabled"]),
        "recharge_enabled": bool(switches["recharge_enabled"]),
        "wechat_pay_enabled": bool(switches["wechat_pay_enabled"]),
        "alipay_pay_enabled": bool(switches["alipay_pay_enabled"]),
    }


async def get_client_feature_flags() -> dict[str, bool]:
    config_obj = await get_or_create_global_ai_config()
    return build_client_feature_flags(config_obj)


def build_client_feature_payload(config_obj) -> dict[str, bool | int | list[str]]:
    settings = read_global_feature_settings(config_obj)
    payment_methods: list[str] = []
    if bool(settings["wechat_pay_enabled"]):
        payment_methods.append("wechat")
    if bool(settings["alipay_pay_enabled"]):
        payment_methods.append("alipay")
    return {
        **settings,
        "payment_methods": payment_methods,
        "payment_enabled": bool(payment_methods),
    }


async def get_client_feature_payload() -> dict[str, bool | int | list[str]]:
    config_obj = await get_or_create_global_ai_config()
    return build_client_feature_payload(config_obj)


def read_service_base_url(config_obj, service_type: str) -> str:
    service_prefix = normalize_service_type(service_type)
    direct_value = str(getattr(config_obj, f"{service_prefix}_base_url", "") or "").strip()
    if direct_value:
        return direct_value
    return str(getattr(config_obj, "provider_base_url", "") or "").strip()


def read_service_api_key(config_obj, service_type: str) -> str:
    service_prefix = normalize_service_type(service_type)
    direct_value = str(getattr(config_obj, f"{service_prefix}_api_key", "") or "").strip()
    if direct_value:
        return direct_value
    return str(getattr(config_obj, "provider_api_key", "") or "").strip()


def normalize_service_type(service_type: str) -> str:
    normalized = str(service_type or "").strip().lower()
    aliases = {
        "text": "llm",
        "llm": "llm",
        "video": "video",
        "speech": "speech",
        "audio": "speech",
        "image": "image",
        "images": "image",
    }
    return aliases.get(normalized, "video")


def _default_value(field_name: str) -> str:
    return str(AppConfigOut.model_fields[field_name].default or "").strip()


def _first_nonempty(*values: str | None) -> str:
    for value in values:
        normalized = str(value or "").strip()
        if normalized:
            return normalized
    return ""


def _pick_secret_value(primary: str | None, fallback: str | None) -> str:
    return _first_nonempty(primary, fallback)


def _pick_config_value(primary: str | None, fallback: str | None, field_name: str) -> str:
    return _first_nonempty(primary, fallback, _default_value(field_name))


def _resolve_service_base_url(primary_config, global_config, service_type: str, provider_base_url: str) -> str:
    primary_value = read_service_base_url(primary_config, service_type) if primary_config is not None else ""
    fallback_value = read_service_base_url(global_config, service_type)
    return _first_nonempty(primary_value, fallback_value, provider_base_url, _default_value(f"{service_type}_base_url"))


def _resolve_service_api_key(primary_config, global_config, service_type: str, provider_api_key: str) -> str:
    primary_value = read_service_api_key(primary_config, service_type) if primary_config is not None else ""
    fallback_value = read_service_api_key(global_config, service_type)
    return _first_nonempty(primary_value, fallback_value, provider_api_key)


def _resolve_model_value(primary_config, global_config, field_name: str) -> str:
    primary_value = str(getattr(primary_config, field_name, "") or "").strip() if primary_config is not None else ""
    fallback_value = str(getattr(global_config, field_name, "") or "").strip()
    return _pick_config_value(primary_value, fallback_value, field_name)


def _has_any_api_key(config_obj) -> bool:
    if config_obj is None:
        return False
    return any(
        str(getattr(config_obj, field_name, "") or "").strip()
        for field_name in (
            "provider_api_key",
            "llm_api_key",
            "video_api_key",
            "speech_api_key",
            "image_api_key",
        )
    )


async def _find_seed_user_config() -> UserAppConfig | None:
    superuser_ids = list(await User.filter(is_superuser=True).values_list("id", flat=True))
    if superuser_ids:
        superuser_configs = await UserAppConfig.filter(user_id__in=superuser_ids).order_by("-updated_at", "-id")
        for config_obj in superuser_configs:
            if _has_any_api_key(config_obj):
                return config_obj

    all_configs = await UserAppConfig.all().order_by("-updated_at", "-id")
    for config_obj in all_configs:
        if _has_any_api_key(config_obj):
            return config_obj
    return None


async def _normalize_platform_config(config_obj: PlatformAIConfig) -> bool:
    changed = False
    defaults = default_app_config_values()
    feature_defaults = default_app_feature_values()

    if not str(config_obj.provider_base_url or "").strip():
        config_obj.provider_base_url = defaults["provider_base_url"]
        changed = True

    for field_name, default_value in feature_defaults.items():
        current_value = getattr(config_obj, field_name, None)
        if current_value is None:
            setattr(config_obj, field_name, default_value)
            changed = True

    normalized_feature_settings = normalize_global_feature_settings(
        {
            field_name: getattr(config_obj, field_name, feature_defaults[field_name])
            for field_name in feature_defaults
        }
    )
    for field_name, normalized_value in normalized_feature_settings.items():
        if getattr(config_obj, field_name, None) != normalized_value:
            setattr(config_obj, field_name, normalized_value)
            changed = True

    for field_name in ("llm_model", "video_model", "speech_model"):
        if not str(getattr(config_obj, field_name, "") or "").strip():
            setattr(config_obj, field_name, defaults[field_name])
            changed = True

    for service_type in SERVICE_TYPES:
        base_field = f"{service_type}_base_url"
        key_field = f"{service_type}_api_key"
        if service_type != "image" and not str(getattr(config_obj, base_field, "") or "").strip():
            setattr(config_obj, base_field, "")
        if not str(getattr(config_obj, key_field, "") or "").strip():
            setattr(config_obj, key_field, getattr(config_obj, key_field, "") or "")

    return changed


def normalize_global_feature_settings(values: dict[str, Any]) -> dict[str, bool | int]:
    defaults = default_app_feature_values()

    points_enabled = bool(values.get("points_enabled", defaults["points_enabled"]))
    recharge_enabled = bool(values.get("recharge_enabled", defaults["recharge_enabled"]))
    wechat_pay_enabled = bool(values.get("wechat_pay_enabled", defaults["wechat_pay_enabled"]))
    alipay_pay_enabled = bool(values.get("alipay_pay_enabled", defaults["alipay_pay_enabled"]))
    video_generation_cost = _normalize_non_negative_int(
        values.get("video_generation_cost", defaults["video_generation_cost"]),
        default=int(defaults["video_generation_cost"]),
    )

    if not points_enabled:
        recharge_enabled = False
        wechat_pay_enabled = False
        alipay_pay_enabled = False
    elif not recharge_enabled:
        wechat_pay_enabled = False
        alipay_pay_enabled = False
    elif wechat_pay_enabled or alipay_pay_enabled:
        points_enabled = True
        recharge_enabled = True

    return {
        "points_enabled": points_enabled,
        "recharge_enabled": recharge_enabled,
        "wechat_pay_enabled": wechat_pay_enabled,
        "alipay_pay_enabled": alipay_pay_enabled,
        "video_generation_cost": video_generation_cost,
    }


def _normalize_non_negative_int(value: Any, *, default: int) -> int:
    try:
        normalized = int(value)
    except (TypeError, ValueError):
        return default
    return max(normalized, 0)
