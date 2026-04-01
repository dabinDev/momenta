from datetime import datetime

from pydantic import BaseModel, Field


class AppReleaseBase(BaseModel):
    platform: str = Field(default="android", min_length=1, max_length=20)
    channel: str = Field(default="lan", min_length=1, max_length=30)
    version_name: str = Field(min_length=1, max_length=30)
    build_number: int = Field(default=1, ge=1)
    title: str | None = Field(default=None, max_length=100)
    release_notes: str | None = None
    download_url: str | None = Field(default=None, max_length=500)
    force_update: bool = False
    is_active: bool = True


class AppReleaseCreate(AppReleaseBase):
    pass


class AppReleaseUpdate(AppReleaseBase):
    id: int


class LatestReleaseQuery(BaseModel):
    platform: str = Field(default="android", min_length=1, max_length=20)
    channel: str = Field(default="lan", min_length=1, max_length=30)
    current_version: str | None = Field(default=None, max_length=30)
    current_build_number: int = Field(default=0, ge=0)


class AppReleaseOut(AppReleaseBase):
    id: int
    published_at: datetime | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None

