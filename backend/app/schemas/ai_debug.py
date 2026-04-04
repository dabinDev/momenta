from typing import Any

from pydantic import BaseModel, Field, field_validator


class AIDebugTextRequest(BaseModel):
    user_id: int = Field(description="Target user ID")
    text: str = Field(description="Source text", min_length=1, max_length=4000)


class AIDebugTaskCreateRequest(BaseModel):
    user_id: int = Field(description="Target user ID")
    input_text: str | None = Field(default=None, description="Original input text")
    polished_text: str | None = Field(default=None, description="Polished text")
    prompt: str = Field(description="Prompt", min_length=1, max_length=8000)
    images: list[str] = Field(default_factory=list, description="Uploaded image URLs")
    duration: int = Field(default=5, description="Video duration", ge=1, le=60)

    @field_validator("images", mode="before")
    @classmethod
    def normalize_images(cls, value: Any) -> list[str]:
        if value in (None, ""):
            return []
        if not isinstance(value, list):
            return []

        normalized: list[str] = []
        for item in value:
            if isinstance(item, str):
                text = item.strip()
            elif isinstance(item, dict):
                text = str(item.get("url") or item.get("path") or "").strip()
            else:
                text = ""
            if text:
                normalized.append(text)
        return normalized
