from tortoise import fields

from .base import BaseModel, TimestampMixin


class PlatformAIConfig(BaseModel, TimestampMixin):
    config_key = fields.CharField(max_length=32, unique=True, default="default", description="Config key", index=True)
    provider_base_url = fields.CharField(
        max_length=255,
        default="https://api.99hub.top",
        description="Shared provider base URL",
    )
    provider_api_key = fields.CharField(
        max_length=255,
        default="",
        description="Shared provider API key",
    )
    llm_base_url = fields.CharField(max_length=255, default="", description="LLM base URL override")
    llm_api_key = fields.CharField(max_length=255, default="", description="LLM API key override")
    llm_model = fields.CharField(max_length=120, default="gpt-5.4-mini", description="LLM model")
    video_base_url = fields.CharField(max_length=255, default="", description="Video base URL override")
    video_api_key = fields.CharField(max_length=255, default="", description="Video API key override")
    video_model = fields.CharField(max_length=120, default="veo_3_1-fast-components-4K", description="Video model")
    speech_base_url = fields.CharField(max_length=255, default="", description="Speech base URL override")
    speech_api_key = fields.CharField(max_length=255, default="", description="Speech API key override")
    speech_model = fields.CharField(max_length=120, default="gpt-4o-mini-audio-preview", description="Speech model")
    image_base_url = fields.CharField(max_length=255, default="", description="Image base URL override")
    image_api_key = fields.CharField(max_length=255, default="", description="Image API key override")
    image_model = fields.CharField(max_length=120, default="", description="Image model")

    class Meta:
        table = "platform_ai_config"


class UserAppConfig(BaseModel, TimestampMixin):
    user_id = fields.BigIntField(unique=True, description="User ID", index=True)
    override_enabled = fields.BooleanField(default=False, description="Private override enabled", index=True)
    provider_base_url = fields.CharField(max_length=255, default="", description="Shared provider base URL")
    provider_api_key = fields.CharField(max_length=255, default="", description="Shared provider API key")
    llm_base_url = fields.CharField(max_length=255, default="", description="LLM base URL override")
    llm_api_key = fields.CharField(max_length=255, default="", description="LLM API key override")
    llm_model = fields.CharField(max_length=120, default="", description="LLM model override")
    video_base_url = fields.CharField(max_length=255, default="", description="Video base URL override")
    video_api_key = fields.CharField(max_length=255, default="", description="Video API key override")
    video_model = fields.CharField(max_length=120, default="", description="Video model override")
    speech_base_url = fields.CharField(max_length=255, default="", description="Speech base URL override")
    speech_api_key = fields.CharField(max_length=255, default="", description="Speech API key override")
    speech_model = fields.CharField(max_length=120, default="", description="Speech model override")
    image_base_url = fields.CharField(max_length=255, default="", description="Image base URL override")
    image_api_key = fields.CharField(max_length=255, default="", description="Image API key override")
    image_model = fields.CharField(max_length=120, default="", description="Image model override")

    class Meta:
        table = "user_app_config"
