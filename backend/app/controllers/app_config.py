from __future__ import annotations

from datetime import datetime

from tortoise.expressions import Q

from app.models.admin import User
from app.models.app_config import PlatformAIConfig, UserAppConfig
from app.schemas.app_config_admin import AppConfigAdminUpdate, GlobalAppConfigAdminUpdate
from app.services.config_store import (
    default_app_config_values,
    default_private_override_values,
    get_or_create_global_ai_config,
    get_or_create_user_app_config,
    get_user_app_config,
    read_service_api_key,
    resolve_effective_user_app_config,
)
from app.settings import settings


class AppConfigController:
    config_fields = (
        "provider_base_url",
        "provider_api_key",
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
    )

    def defaults(self) -> dict[str, str]:
        return default_app_config_values()

    def private_defaults(self) -> dict[str, str | bool]:
        return default_private_override_values()

    async def list_configs(
        self,
        *,
        page: int,
        page_size: int,
        keyword: str = "",
    ) -> tuple[int, list[dict]]:
        query = Q()
        if keyword:
            query &= (
                Q(username__contains=keyword)
                | Q(alias__contains=keyword)
                | Q(email__contains=keyword)
            )

        user_query = User.filter(query)
        total = await user_query.count()
        users = await user_query.offset((page - 1) * page_size).limit(page_size).order_by("-updated_at", "id")
        if not users:
            return total, []

        user_ids = [user.id for user in users]
        configs = await UserAppConfig.filter(user_id__in=user_ids)
        config_map = {config.user_id: config for config in configs}
        data = [
            await self.serialize_user_override(user=user, config=config_map.get(user.id), include_secrets=False)
            for user in users
        ]
        return total, data

    async def get_config(self, *, user_id: int) -> dict:
        user = await User.get(id=user_id)
        config = await get_user_app_config(user_id, create=False)
        return await self.serialize_user_override(user=user, config=config, include_secrets=True)

    async def update_config(self, *, obj_in: AppConfigAdminUpdate) -> dict:
        user = await User.get(id=obj_in.user_id)
        config = await get_or_create_user_app_config(obj_in.user_id)
        user.allow_private_ai_override = bool(obj_in.allow_private_ai_override)
        await user.save()
        config.override_enabled = bool(obj_in.override_enabled)
        for field in self.config_fields:
            setattr(config, field, getattr(obj_in, field))
        await config.save()
        return await self.serialize_user_override(user=user, config=config, include_secrets=True)

    async def reset_config(self, *, user_id: int) -> dict:
        user = await User.get(id=user_id)
        config = await get_or_create_user_app_config(user_id)
        user.allow_private_ai_override = False
        await user.save()
        for field, value in self.private_defaults().items():
            setattr(config, field, value)
        await config.save()
        return await self.serialize_user_override(user=user, config=config, include_secrets=True)

    async def get_global_config(self) -> dict:
        config = await get_or_create_global_ai_config()
        return await self.serialize_global_config(config=config, include_secrets=True)

    async def update_global_config(self, *, obj_in: GlobalAppConfigAdminUpdate) -> dict:
        config = await get_or_create_global_ai_config()
        for field in self.config_fields:
            setattr(config, field, getattr(obj_in, field))
        await config.save()
        return await self.serialize_global_config(config=config, include_secrets=True)

    async def reset_global_config(self) -> dict:
        config = await get_or_create_global_ai_config()
        for field, value in self.defaults().items():
            setattr(config, field, value)
        await config.save()
        return await self.serialize_global_config(config=config, include_secrets=True)

    async def get_effective_config(self, *, user_id: int) -> dict:
        user = await User.get(id=user_id)
        effective = await resolve_effective_user_app_config(user_id)
        return {
            "user_id": user.id,
            "user": {
                "id": user.id,
                "username": user.username,
                "alias": user.alias,
                "email": user.email,
                "phone": user.phone,
                "is_active": user.is_active,
            },
            "config_source": effective.config_source,
            "using_private_override": effective.using_private_override,
            "provider_base_url": effective.provider_base_url,
            "llm_base_url": effective.llm_base_url,
            "llm_model": effective.llm_model,
            "video_base_url": effective.video_base_url,
            "video_model": effective.video_model,
            "speech_base_url": effective.speech_base_url,
            "speech_model": effective.speech_model,
            "image_base_url": effective.image_base_url,
            "image_model": effective.image_model,
            "llm_configured": bool(effective.llm_api_key and effective.llm_base_url and effective.llm_model),
            "video_configured": bool(effective.video_api_key and effective.video_base_url and effective.video_model),
            "speech_configured": bool(effective.speech_api_key and effective.speech_base_url and effective.speech_model),
            "image_configured": bool(effective.image_api_key and effective.image_base_url and effective.image_model),
        }

    async def serialize_user_override(
        self,
        *,
        user: User,
        config: UserAppConfig | None,
        include_secrets: bool,
    ) -> dict:
        values = self.private_defaults()
        if config:
            for field in self.config_fields:
                values[field] = getattr(config, field)
            values["override_enabled"] = bool(getattr(config, "override_enabled", False))

        provider_api_key = str(values.get("provider_api_key") or "").strip()
        llm_api_key = str(values.get("llm_api_key") or "").strip()
        video_api_key = str(values.get("video_api_key") or "").strip()
        speech_api_key = str(values.get("speech_api_key") or "").strip()
        image_api_key = str(values.get("image_api_key") or "").strip()

        return {
            "id": str(config.id) if config else None,
            "user_id": user.id,
            "user": {
                "id": user.id,
                "username": user.username,
                "alias": user.alias,
                "email": user.email,
                "phone": user.phone,
                "is_active": user.is_active,
            },
            "allow_private_ai_override": bool(user.allow_private_ai_override),
            "override_enabled": bool(values["override_enabled"]),
            "using_private_override": bool(user.allow_private_ai_override and values["override_enabled"]),
            "provider_base_url": values["provider_base_url"],
            "provider_api_key": provider_api_key if include_secrets else "",
            "provider_api_key_masked": self._mask_secret(provider_api_key),
            "llm_base_url": values["llm_base_url"],
            "llm_api_key": llm_api_key if include_secrets else "",
            "llm_api_key_masked": self._mask_secret(llm_api_key),
            "llm_model": values["llm_model"],
            "video_base_url": values["video_base_url"],
            "video_api_key": video_api_key if include_secrets else "",
            "video_api_key_masked": self._mask_secret(video_api_key),
            "video_model": values["video_model"],
            "speech_base_url": values["speech_base_url"],
            "speech_api_key": speech_api_key if include_secrets else "",
            "speech_api_key_masked": self._mask_secret(speech_api_key),
            "speech_model": values["speech_model"],
            "image_base_url": values["image_base_url"],
            "image_api_key": image_api_key if include_secrets else "",
            "image_api_key_masked": self._mask_secret(image_api_key),
            "image_model": values["image_model"],
            "provider_configured": bool(provider_api_key),
            "llm_configured": bool(llm_api_key or provider_api_key),
            "video_configured": bool(video_api_key or provider_api_key),
            "speech_configured": bool(speech_api_key or provider_api_key),
            "image_configured": bool(image_api_key or provider_api_key),
            "has_custom_config": config is not None,
            "created_at": self._format_datetime(config.created_at if config else None),
            "updated_at": self._format_datetime(config.updated_at if config else None),
        }

    async def serialize_global_config(
        self,
        *,
        config: PlatformAIConfig,
        include_secrets: bool,
    ) -> dict:
        provider_api_key = str(config.provider_api_key or "").strip()
        llm_api_key = read_service_api_key(config, "llm")
        video_api_key = read_service_api_key(config, "video")
        speech_api_key = read_service_api_key(config, "speech")
        image_api_key = read_service_api_key(config, "image")

        return {
            "id": str(config.id),
            "config_key": config.config_key,
            "provider_base_url": config.provider_base_url,
            "provider_api_key": provider_api_key if include_secrets else "",
            "provider_api_key_masked": self._mask_secret(provider_api_key),
            "llm_base_url": config.llm_base_url or config.provider_base_url,
            "llm_api_key": llm_api_key if include_secrets else "",
            "llm_api_key_masked": self._mask_secret(llm_api_key),
            "llm_model": config.llm_model,
            "video_base_url": config.video_base_url or config.provider_base_url,
            "video_api_key": video_api_key if include_secrets else "",
            "video_api_key_masked": self._mask_secret(video_api_key),
            "video_model": config.video_model,
            "speech_base_url": config.speech_base_url or config.provider_base_url,
            "speech_api_key": speech_api_key if include_secrets else "",
            "speech_api_key_masked": self._mask_secret(speech_api_key),
            "speech_model": config.speech_model,
            "image_base_url": config.image_base_url or config.provider_base_url,
            "image_api_key": image_api_key if include_secrets else "",
            "image_api_key_masked": self._mask_secret(image_api_key),
            "image_model": config.image_model,
            "provider_configured": bool(provider_api_key),
            "llm_configured": bool(llm_api_key and (config.llm_model or "").strip()),
            "video_configured": bool(video_api_key and (config.video_model or "").strip()),
            "speech_configured": bool(speech_api_key and (config.speech_model or "").strip()),
            "image_configured": bool(image_api_key and (config.image_model or "").strip()),
            "created_at": self._format_datetime(config.created_at),
            "updated_at": self._format_datetime(config.updated_at),
        }

    @staticmethod
    def _mask_secret(secret: str) -> str:
        if not secret:
            return ""
        if len(secret) <= 8:
            return "*" * len(secret)
        return f"{secret[:4]}{'*' * (len(secret) - 8)}{secret[-4:]}"

    @staticmethod
    def _format_datetime(value: datetime | None) -> str | None:
        return value.strftime(settings.DATETIME_FORMAT) if value else None


app_config_controller = AppConfigController()
