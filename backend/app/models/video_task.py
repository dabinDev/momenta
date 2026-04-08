from tortoise import fields

from .base import BaseModel, TimestampMixin


class VideoTask(BaseModel, TimestampMixin):
    user = fields.ForeignKeyField(
        "models.User",
        related_name="video_tasks",
        on_delete=fields.CASCADE,
        db_constraint=False,
    )
    task_source = fields.CharField(max_length=20, default="app", description="Task source", index=True)
    task_type = fields.CharField(max_length=30, default="text_to_video", description="Task type", index=True)
    status = fields.CharField(max_length=20, default="queued", description="Task status", index=True)
    input_text = fields.TextField(null=True, description="Original input text")
    polished_text = fields.TextField(null=True, description="Polished input text")
    prompt = fields.TextField(null=True, description="Final prompt text")
    duration = fields.IntField(default=5, description="Video duration in seconds")
    cover_image_url = fields.CharField(max_length=500, null=True, description="Cover image URL")
    video_url = fields.CharField(max_length=500, null=True, description="Generated video URL")
    remote_video_url = fields.CharField(max_length=500, null=True, description="Generated remote video URL")
    cos_video_url = fields.CharField(max_length=500, null=True, description="Generated COS video URL")
    provider = fields.CharField(max_length=50, default="legacy", description="Upstream provider", index=True)
    provider_task_id = fields.CharField(max_length=120, null=True, description="Upstream task ID", index=True)
    progress = fields.FloatField(default=0, description="Task progress")
    error_code = fields.CharField(max_length=100, null=True, description="Error code")
    error_message = fields.TextField(null=True, description="Error message")
    provider_payload = fields.JSONField(null=True, description="Raw upstream payload")
    points_cost = fields.IntField(default=0, description="Points cost for current attempt")
    points_charge_token = fields.CharField(max_length=64, null=True, description="Charge token", index=True)
    points_refunded = fields.BooleanField(default=False, description="Whether current attempt points were refunded", index=True)
    points_refunded_at = fields.DatetimeField(null=True, description="Points refunded time", index=True)
    is_deleted = fields.BooleanField(default=False, description="User deleted flag", index=True)
    deleted_at = fields.DatetimeField(null=True, description="Deleted time", index=True)
    started_at = fields.DatetimeField(null=True, description="Task start time", index=True)
    finished_at = fields.DatetimeField(null=True, description="Task finish time", index=True)

    class Meta:
        table = "video_task"


class VideoTaskAsset(BaseModel, TimestampMixin):
    task = fields.ForeignKeyField(
        "models.VideoTask",
        related_name="assets",
        on_delete=fields.CASCADE,
        db_constraint=False,
    )
    asset_type = fields.CharField(max_length=30, default="reference_image", description="Asset type", index=True)
    file_url = fields.CharField(max_length=500, description="Asset URL")
    file_name = fields.CharField(max_length=255, null=True, description="Asset file name")
    sort_order = fields.IntField(default=0, description="Display order", index=True)

    class Meta:
        table = "video_task_asset"


class VoiceTranscriptionLog(BaseModel, TimestampMixin):
    user = fields.ForeignKeyField(
        "models.User",
        related_name="voice_logs",
        on_delete=fields.CASCADE,
        db_constraint=False,
    )
    task = fields.ForeignKeyField(
        "models.VideoTask",
        related_name="voice_logs",
        on_delete=fields.SET_NULL,
        null=True,
        db_constraint=False,
    )
    provider = fields.CharField(max_length=50, default="xfyun", description="Speech provider", index=True)
    audio_duration = fields.FloatField(default=0, description="Audio duration in seconds")
    audio_format = fields.CharField(max_length=20, default="pcm", description="Audio format")
    language = fields.CharField(max_length=20, default="zh_cn", description="Recognition language")
    accent = fields.CharField(max_length=20, default="mandarin", description="Recognition accent")
    recognized_text = fields.TextField(null=True, description="Recognized text")
    status = fields.CharField(max_length=20, default="success", description="Recognition status", index=True)
    error_message = fields.TextField(null=True, description="Recognition error")
    file_name = fields.CharField(max_length=255, null=True, description="Original file name")

    class Meta:
        table = "voice_transcription_log"
