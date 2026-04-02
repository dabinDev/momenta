from tortoise import fields

from .base import BaseModel, TimestampMixin


class UserAppConfig(BaseModel, TimestampMixin):
    user_id = fields.BigIntField(unique=True, description="用户ID", index=True)
    llm_base_url = fields.CharField(
        max_length=255,
        default="https://api.99hub.top",
        description="文案服务地址",
    )
    llm_api_key = fields.CharField(
        max_length=255,
        default="",
        description="文案服务密钥",
    )
    llm_model = fields.CharField(
        max_length=100,
        default="gpt-5.4-mini",
        description="文案模型名称",
    )
    video_base_url = fields.CharField(
        max_length=255,
        default="https://api.99hub.top",
        description="视频服务地址",
    )
    video_api_key = fields.CharField(
        max_length=255,
        default="",
        description="视频服务密钥",
    )
    video_model = fields.CharField(
        max_length=100,
        default="veo_3_1-fast-components-4K",
        description="视频模型名称",
    )
    speech_base_url = fields.CharField(
        max_length=255,
        default="https://api.99hub.top",
        description="语音服务地址",
    )
    speech_api_key = fields.CharField(
        max_length=255,
        default="",
        description="语音服务密钥",
    )
    speech_model = fields.CharField(
        max_length=100,
        default="gpt-4o-mini-audio-preview",
        description="语音模型名称",
    )

    class Meta:
        table = "user_app_config"
