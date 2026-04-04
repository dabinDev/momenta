from pydantic import BaseModel, Field


class AppConfigBase(BaseModel):
    provider_base_url: str = Field(default="https://api.99hub.top", alias="providerBaseUrl")
    provider_api_key: str = Field(default="", alias="providerApiKey")
    llm_base_url: str = Field(default="https://api.99hub.top", alias="llmBaseUrl")
    llm_api_key: str = Field(default="", alias="llmApiKey")
    llm_model: str = Field(default="gpt-5.4-mini", alias="llmModel")
    video_base_url: str = Field(default="https://api.99hub.top", alias="videoBaseUrl")
    video_api_key: str = Field(default="", alias="videoApiKey")
    video_model: str = Field(default="veo_3_1-fast-components-4K", alias="videoModel")
    speech_base_url: str = Field(default="https://api.99hub.top", alias="speechBaseUrl")
    speech_api_key: str = Field(default="", alias="speechApiKey")
    speech_model: str = Field(default="gpt-4o-mini-audio-preview", alias="speechModel")
    image_base_url: str = Field(default="https://api.99hub.top", alias="imageBaseUrl")
    image_api_key: str = Field(default="", alias="imageApiKey")
    image_model: str = Field(default="", alias="imageModel")

    model_config = {
        "populate_by_name": True,
    }


class AppConfigIn(AppConfigBase):
    pass


class AppConfigOut(AppConfigBase):
    using_private_override: bool = Field(default=False, alias="usingPrivateOverride")
    config_source: str = Field(default="global", alias="configSource")
