from pydantic import BaseModel, Field


class AppConfigAdminBase(BaseModel):
    provider_base_url: str = Field(default="https://api.99hub.top", description="Shared provider base URL")
    provider_api_key: str = Field(default="", description="Shared provider API key")
    llm_base_url: str = Field(default="", description="LLM base URL override")
    llm_api_key: str = Field(default="", description="LLM API key override")
    llm_model: str = Field(default="gpt-5.4-mini", description="LLM model")
    video_base_url: str = Field(default="", description="Video base URL override")
    video_api_key: str = Field(default="", description="Video API key override")
    video_model: str = Field(default="veo_3_1-fast-components-4K", description="Video model")
    speech_base_url: str = Field(default="", description="Speech base URL override")
    speech_api_key: str = Field(default="", description="Speech API key override")
    speech_model: str = Field(default="gpt-4o-mini-audio-preview", description="Speech model")
    image_base_url: str = Field(default="", description="Image base URL override")
    image_api_key: str = Field(default="", description="Image API key override")
    image_model: str = Field(default="", description="Image model")


class AppConfigAdminUpdate(AppConfigAdminBase):
    user_id: int = Field(description="User ID")
    allow_private_ai_override: bool = Field(default=False, description="Allow private AI override")
    override_enabled: bool = Field(default=False, description="Enable private AI override")


class GlobalAppConfigAdminUpdate(AppConfigAdminBase):
    points_enabled: bool = Field(default=True, description="是否开启积分系统")
    recharge_enabled: bool = Field(default=True, description="是否开启充值系统")
    video_generation_cost: int = Field(default=10, ge=0, description="每次视频生成消耗积分")
    wechat_pay_enabled: bool = Field(default=True, description="是否开启微信支付")
    alipay_pay_enabled: bool = Field(default=False, description="是否开启支付宝支付")
