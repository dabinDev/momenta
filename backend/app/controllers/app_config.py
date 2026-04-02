from __future__ import annotations

from datetime import datetime

from tortoise.expressions import Q

from app.models.admin import User
from app.models.app_config import UserAppConfig
from app.schemas.app_config import AppConfigOut
from app.schemas.app_config_admin import AppConfigAdminUpdate
from app.services.config_store import get_or_create_user_app_config
from app.settings import settings


class AppConfigController:
    config_fields = (
        "llm_base_url",
        "llm_api_key",
        "llm_model",
        "video_base_url",
        "video_api_key",
        "video_model",
        "speech_base_url",
        "speech_api_key",
        "speech_model",
    )

    def defaults(self) -> dict[str, str]:
        return {
            "llm_base_url": AppConfigOut.model_fields["llm_base_url"].default,
            "llm_api_key": AppConfigOut.model_fields["llm_api_key"].default,
            "llm_model": AppConfigOut.model_fields["llm_model"].default,
            "video_base_url": AppConfigOut.model_fields["video_base_url"].default,
            "video_api_key": AppConfigOut.model_fields["video_api_key"].default,
            "video_model": AppConfigOut.model_fields["video_model"].default,
            "speech_base_url": AppConfigOut.model_fields["speech_base_url"].default,
            "speech_api_key": AppConfigOut.model_fields["speech_api_key"].default,
            "speech_model": AppConfigOut.model_fields["speech_model"].default,
        }

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
            await self.serialize_config(user=user, config=config_map.get(user.id), include_secrets=False)
            for user in users
        ]
        return total, data

    async def get_config(self, *, user_id: int) -> dict:
        user = await User.get(id=user_id)
        config = await get_or_create_user_app_config(user_id)
        return await self.serialize_config(user=user, config=config, include_secrets=True)

    async def update_config(self, *, obj_in: AppConfigAdminUpdate) -> dict:
        user = await User.get(id=obj_in.user_id)
        config = await get_or_create_user_app_config(obj_in.user_id)
        for field in self.config_fields:
            setattr(config, field, getattr(obj_in, field))
        await config.save()
        return await self.serialize_config(user=user, config=config, include_secrets=True)

    async def reset_config(self, *, user_id: int) -> dict:
        user = await User.get(id=user_id)
        config = await get_or_create_user_app_config(user_id)
        for field, value in self.defaults().items():
            setattr(config, field, value)
        await config.save()
        return await self.serialize_config(user=user, config=config, include_secrets=True)

    async def serialize_config(
        self,
        *,
        user: User,
        config: UserAppConfig | None,
        include_secrets: bool,
    ) -> dict:
        values = self.defaults()
        if config:
            for field in self.config_fields:
                values[field] = getattr(config, field)

        llm_api_key = (values.get("llm_api_key") or "").strip()
        video_api_key = (values.get("video_api_key") or "").strip()
        speech_api_key = (values.get("speech_api_key") or "").strip()

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
            "llm_configured": bool(llm_api_key),
            "video_configured": bool(video_api_key),
            "speech_configured": bool(speech_api_key),
            "has_custom_config": config is not None,
            "created_at": self._format_datetime(config.created_at if config else None),
            "updated_at": self._format_datetime(config.updated_at if config else None),
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
