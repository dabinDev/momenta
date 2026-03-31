from pydantic import BaseModel, Field


class AppConfigBase(BaseModel):
    llm_base_url: str = Field(
        default="https://api.moonshot.cn/v1",
        alias="llmBaseUrl",
    )
    llm_api_key: str = Field(default="", alias="llmApiKey")
    llm_model: str = Field(default="moonshot-v1-8k", alias="llmModel")
    video_base_url: str = Field(
        default="https://api.openai.com/v1",
        alias="videoBaseUrl",
    )
    video_api_key: str = Field(default="", alias="videoApiKey")
    video_model: str = Field(default="video-generation", alias="videoModel")

    model_config = {
        "populate_by_name": True,
    }


class AppConfigIn(AppConfigBase):
    pass


class AppConfigOut(AppConfigBase):
    pass
