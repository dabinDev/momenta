from pydantic import BaseModel, Field


class ModelCatalogScopeBase(BaseModel):
    scope: str = Field(default="global", description="Config scope: global or user")
    user_id: int | None = Field(default=None, description="User ID for private scope")
    service_type: str = Field(default="video", description="Service type")


class ModelCatalogSyncIn(ModelCatalogScopeBase):
    pass


class ModelCatalogRecommendIn(ModelCatalogScopeBase):
    prioritize: str = Field(default="balanced", description="Preference strategy")
    need_image_input: bool = Field(default=True, description="Whether image input support is required")


class ModelCatalogApplyIn(ModelCatalogScopeBase):
    model_id: str = Field(description="Model ID")
