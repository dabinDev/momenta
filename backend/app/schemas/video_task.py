from pydantic import BaseModel, Field


class TextTransformIn(BaseModel):
    text: str = Field(description="Source text", min_length=1, max_length=4000)


class PromptGenerateIn(TextTransformIn):
    prompt_template_key: str | None = Field(
        default=None,
        description="Backend maintained prompt template key",
        max_length=100,
    )


class VideoTaskCreateIn(BaseModel):
    input_text: str | None = Field(default=None, description="Original input text")
    polished_text: str | None = Field(default=None, description="Polished text")
    prompt: str = Field(description="Prompt used for generation", min_length=1, max_length=8000)
    images: list[str] = Field(default_factory=list, description="Reference image URLs")
    duration: int = Field(default=5, description="Video duration", ge=1, le=60)
    prompt_template_key: str | None = Field(
        default=None,
        description="Backend maintained prompt template key",
        max_length=100,
    )
    video_template_key: str | None = Field(
        default=None,
        description="Backend maintained video template key",
        max_length=100,
    )


class StarterVideoTaskCreateIn(BaseModel):
    input_text: str | None = Field(default=None, description="Original input text")
    prompt: str | None = Field(
        default=None,
        description="Prompt used for generation, optional when backend builds it",
        min_length=1,
        max_length=8000,
    )
    images: list[str] = Field(
        default_factory=list,
        description="Reference image URLs",
        min_length=1,
    )
    duration: int = Field(default=5, description="Video duration", ge=1, le=60)
    prompt_template_key: str | None = Field(
        default=None,
        description="Backend maintained prompt template key",
        max_length=100,
    )
    video_template_key: str | None = Field(
        default=None,
        description="Backend maintained video template key",
        max_length=100,
    )
    reference_link: str = Field(
        description="Reference public video link",
        min_length=1,
        max_length=2000,
    )
    supplemental_text: str | None = Field(
        default=None,
        description="Additional creation note",
        max_length=4000,
    )


class CustomVideoTaskCreateIn(BaseModel):
    input_text: str | None = Field(default=None, description="Original input text")
    prompt: str | None = Field(
        default=None,
        description="Prompt used for generation, optional when backend builds it",
        min_length=1,
        max_length=8000,
    )
    images: list[str] = Field(
        default_factory=list,
        description="Reference image URLs",
        min_length=1,
    )
    duration: int = Field(default=5, description="Video duration", ge=1, le=60)
    prompt_template_key: str | None = Field(
        default=None,
        description="Backend maintained prompt template key",
        max_length=100,
    )
    video_template_key: str = Field(
        description="Backend maintained video template key",
        min_length=1,
        max_length=100,
    )
    reference_video_path: str | None = Field(
        default=None,
        description="Uploaded reference video URL",
        max_length=2000,
    )
    supplemental_text: str | None = Field(
        default=None,
        description="Additional creation note",
        max_length=4000,
    )
