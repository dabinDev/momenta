from pydantic import BaseModel, Field


class AppConfigAdminBase(BaseModel):
    llm_base_url: str = Field(default="https://api.moonshot.cn/v1", description="LLM base URL")
    llm_api_key: str = Field(default="", description="LLM API key")
    llm_model: str = Field(default="moonshot-v1-8k", description="LLM model")
    video_base_url: str = Field(default="https://api.openai.com/v1", description="Video base URL")
    video_api_key: str = Field(default="", description="Video API key")
    video_model: str = Field(default="video-generation", description="Video model")


class AppConfigAdminUpdate(AppConfigAdminBase):
    user_id: int = Field(description="User ID")

