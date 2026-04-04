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
    pass
