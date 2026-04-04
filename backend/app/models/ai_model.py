from tortoise import fields

from .base import BaseModel, TimestampMixin


class AIModelCatalog(BaseModel, TimestampMixin):
    service_type = fields.CharField(max_length=20, description="Service type", index=True)
    model_id = fields.CharField(max_length=120, description="Model ID", index=True)
    display_name = fields.CharField(max_length=120, null=True, description="Display name")
    source_base_url = fields.CharField(max_length=255, default="", description="Source base URL", index=True)
    source_kind = fields.CharField(max_length=20, default="remote", description="Catalog source", index=True)
    owned_by = fields.CharField(max_length=50, null=True, description="Owned by")
    endpoint_types = fields.JSONField(null=True, description="Supported endpoint types")
    supports_video = fields.BooleanField(default=False, description="Supports video generation", index=True)
    supports_image_input = fields.BooleanField(default=False, description="Supports image input")
    price_level = fields.IntField(default=3, description="Price score from 1 to 5")
    speed_level = fields.IntField(default=3, description="Speed score from 1 to 5")
    quality_level = fields.IntField(default=3, description="Quality score from 1 to 5")
    capability_score = fields.FloatField(default=0, description="Calculated capability score")
    is_active = fields.BooleanField(default=True, description="Catalog entry active", index=True)
    is_recommended = fields.BooleanField(default=False, description="Recommended entry", index=True)
    tags = fields.JSONField(null=True, description="Tags")
    notes = fields.CharField(max_length=255, null=True, description="Notes")
    raw_payload = fields.JSONField(null=True, description="Raw model payload")

    class Meta:
        table = "ai_model_catalog"
