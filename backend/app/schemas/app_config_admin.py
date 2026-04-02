from pydantic import BaseModel, Field


class AppConfigAdminBase(BaseModel):
    llm_base_url: str = Field(default="https://api.99hub.top", description="LLM base URL")
    llm_api_key: str = Field(default="", description="LLM API key")
    llm_model: str = Field(default="gpt-5.4-mini", description="LLM model")
    video_base_url: str = Field(default="https://api.99hub.top", description="Video base URL")
    video_api_key: str = Field(default="", description="Video API key")
    video_model: str = Field(default="veo_3_1-fast-components-4K", description="Video model")
    speech_base_url: str = Field(default="https://api.99hub.top", description="Speech base URL")
    speech_api_key: str = Field(default="", description="Speech API key")
    speech_model: str = Field(default="gpt-4o-mini-audio-preview", description="Speech model")


class AppConfigAdminUpdate(AppConfigAdminBase):
    user_id: int = Field(description="User ID")
