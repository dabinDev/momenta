from tortoise import fields

from .base import BaseModel, TimestampMixin


class AppRelease(BaseModel, TimestampMixin):
    platform = fields.CharField(max_length=20, default="android", description="Target platform", index=True)
    channel = fields.CharField(max_length=30, default="lan", description="Release channel", index=True)
    version_name = fields.CharField(max_length=30, description="Version name", index=True)
    build_number = fields.IntField(default=1, description="Build number", index=True)
    title = fields.CharField(max_length=100, null=True, description="Release title")
    release_notes = fields.TextField(null=True, description="Release notes")
    download_url = fields.CharField(max_length=500, null=True, description="Download URL")
    force_update = fields.BooleanField(default=False, description="Force update flag", index=True)
    is_active = fields.BooleanField(default=True, description="Active release flag", index=True)
    published_at = fields.DatetimeField(auto_now_add=True, description="Published time", index=True)

    class Meta:
        table = "app_release"
        unique_together = (("platform", "channel", "build_number"),)
