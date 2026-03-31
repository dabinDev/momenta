from tortoise import fields

from .base import BaseModel, TimestampMixin


class UserAppConfig(BaseModel, TimestampMixin):
    user_id = fields.BigIntField(unique=True, description="用户ID", index=True)
    llm_base_url = fields.CharField(
        max_length=255,
        default="https://api.moonshot.cn/v1",
        description="文案服务地址",
    )
    llm_api_key = fields.CharField(
        max_length=255,
        default="",
        description="文案服务密钥",
    )
    llm_model = fields.CharField(
        max_length=100,
        default="moonshot-v1-8k",
        description="文案模型名称",
    )
    video_base_url = fields.CharField(
        max_length=255,
        default="https://api.openai.com/v1",
        description="视频服务地址",
    )
    video_api_key = fields.CharField(
        max_length=255,
        default="",
        description="视频服务密钥",
    )
    video_model = fields.CharField(
        max_length=100,
        default="video-generation",
        description="视频模型名称",
    )

    class Meta:
        table = "user_app_config"
