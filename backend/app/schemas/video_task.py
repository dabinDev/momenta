from pydantic import BaseModel, Field


class TextTransformIn(BaseModel):
    text: str = Field(description="Source text", min_length=1, max_length=4000)


class VideoTaskCreateIn(BaseModel):
    input_text: str | None = Field(default=None, description="Original input text")
    polished_text: str | None = Field(default=None, description="Polished text")
    prompt: str = Field(description="Prompt used for generation", min_length=1, max_length=8000)
    images: list[str] = Field(default_factory=list, description="Reference image URLs")
    duration: int = Field(default=5, description="Video duration", ge=1, le=60)
