from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class PromptTemplate:
    key: str
    name: str
    description: str
    generation_instruction: str
    render_instruction: str
    preview: str
    is_default: bool = False

    def to_dict(self) -> dict[str, Any]:
        return {
            "key": self.key,
            "name": self.name,
            "description": self.description,
            "preview": self.preview,
            "is_default": self.is_default,
        }


@dataclass(frozen=True)
class VideoTemplate:
    key: str
    name: str
    description: str
    style_hint: str
    shot_hint: str
    subtitle_hint: str
    preview: str
    default_duration: int
    size: str = "720x1280"
    is_default: bool = False
    preview_video_url: str = ""
    popularity: int = 0
    tags: tuple[str, ...] = field(default_factory=tuple)
    supports_reference_link: bool = False
    supports_reference_video: bool = False
    supports_reference_image: bool = True

    def to_dict(self) -> dict[str, Any]:
        return {
            "key": self.key,
            "name": self.name,
            "description": self.description,
            "preview": self.preview,
            "default_duration": self.default_duration,
            "size": self.size,
            "is_default": self.is_default,
            "preview_video_url": self.preview_video_url,
            "popularity": self.popularity,
            "tags": list(self.tags),
            "supports_reference_link": self.supports_reference_link,
            "supports_reference_video": self.supports_reference_video,
            "supports_reference_image": self.supports_reference_image,
        }


@dataclass(frozen=True)
class WorkbenchMode:
    code: str
    label: str
    title: str
    subtitle: str
    highlights: tuple[str, ...] = field(default_factory=tuple)
    default_prompt_template_key: str | None = None
    default_video_template_key: str | None = None
    supports_voice_input: bool = False
    supports_text_correction: bool = False
    supports_prompt_generation: bool = False
    requires_reference_link: bool = False
    requires_images: bool = False
    supports_reference_video: bool = False

    def to_dict(self) -> dict[str, Any]:
        return {
            "code": self.code,
            "label": self.label,
            "title": self.title,
            "subtitle": self.subtitle,
            "highlights": list(self.highlights),
            "default_prompt_template_key": self.default_prompt_template_key,
            "default_video_template_key": self.default_video_template_key,
            "supports_voice_input": self.supports_voice_input,
            "supports_text_correction": self.supports_text_correction,
            "supports_prompt_generation": self.supports_prompt_generation,
            "requires_reference_link": self.requires_reference_link,
            "requires_images": self.requires_images,
            "supports_reference_video": self.supports_reference_video,
        }


class AITemplateRegistryService:
    def __init__(self) -> None:
        self._durations: tuple[int, ...] = (5, 10, 20)
        self._prompt_templates: tuple[PromptTemplate, ...] = (
            PromptTemplate(
                key="family_memory",
                name="家庭回忆",
                description="适合家庭团聚、陪伴、旧照片回忆等温暖内容。",
                generation_instruction=(
                    "Focus on family companionship, gentle emotion, warm lighting, "
                    "clear subtitles, and a calm vertical short-video rhythm."
                ),
                render_instruction=(
                    "Keep the visual language warm, natural, and emotionally sincere. "
                    "Prioritize stable framing, realistic family-life details, and readable subtitles."
                ),
                preview="暖色调、家庭氛围自然、字幕清晰、节奏舒缓。",
                is_default=True,
            ),
            PromptTemplate(
                key="festival_blessing",
                name="节日祝福",
                description="适合生日、节庆、问候、感恩祝福类创作。",
                generation_instruction=(
                    "Emphasize celebration, blessing, sincerity, and a festive atmosphere "
                    "without becoming overly flashy or noisy."
                ),
                render_instruction=(
                    "Make the theme feel celebratory and heartfelt, with readable subtitles, "
                    "clear blessing moments, and a shareable short-video structure."
                ),
                preview="节日元素明确，祝福语自然，画面热闹但不杂乱。",
            ),
            PromptTemplate(
                key="health_share",
                name="健康分享",
                description="适合养生提醒、生活建议、科普提醒类内容。",
                generation_instruction=(
                    "Highlight practical information, trustworthy tone, structured delivery, "
                    "clean composition, and large readable subtitles."
                ),
                render_instruction=(
                    "Make the message easy to follow, visually clean, and suitable for elderly viewers, "
                    "with calm pacing and obvious information hierarchy."
                ),
                preview="重点突出、信息清晰、镜头简洁、阅读压力低。",
            ),
        )
        self._video_templates: tuple[VideoTemplate, ...] = (
            VideoTemplate(
                key="warm_album",
                name="暖心相册",
                description="适合照片串联、家庭合影、回忆记录等场景。",
                style_hint=(
                    "Warm color palette, soft indoor lighting, natural facial expressions, "
                    "and an intimate family-memory atmosphere."
                ),
                shot_hint=(
                    "Use gentle push-ins, slow pans, soft transitions, and stable medium-close framing."
                ),
                subtitle_hint=(
                    "Use large, high-contrast subtitles that remain easy to read on a vertical screen."
                ),
                preview="适合家庭相册、陪伴记录、节日问候。",
                default_duration=10,
                is_default=True,
                preview_video_url=(
                    "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4"
                ),
                popularity=98,
                tags=("亲情", "照片成片", "暖色字幕"),
                supports_reference_link=True,
                supports_reference_video=True,
            ),
            VideoTemplate(
                key="story_narration",
                name="字幕讲述",
                description="适合有旁白感、文字驱动、口播转视频的成片方式。",
                style_hint=(
                    "Keep visuals restrained and clear, with subtitles carrying the main information "
                    "and a calm, trustworthy tone."
                ),
                shot_hint=(
                    "Prefer even pacing, fixed shots, and light transitions that support narration."
                ),
                subtitle_hint=(
                    "Break subtitles into readable phrases, highlight key words, and keep text easy to scan."
                ),
                preview="适合口述故事、生活感悟、问候表达。",
                default_duration=20,
                preview_video_url=(
                    "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4"
                ),
                popularity=93,
                tags=("讲述", "大字幕", "旁白感"),
                supports_reference_link=True,
                supports_reference_video=True,
            ),
            VideoTemplate(
                key="life_record",
                name="生活记录",
                description="适合日常生活、散步、做饭、陪伴等轻纪实视频。",
                style_hint=(
                    "Use natural daylight, realistic home-life scenes, bright but not oversaturated colors, "
                    "and a documentary-like texture."
                ),
                shot_hint=(
                    "Favor observational shots, gentle tracking, and environment details that feel grounded."
                ),
                subtitle_hint=(
                    "Keep subtitles simple and unobtrusive so the scene remains the focus."
                ),
                preview="适合日常片段、活动记录、生活分享。",
                default_duration=10,
                preview_video_url=(
                    "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4"
                ),
                popularity=89,
                tags=("纪实", "生活感", "跟拍"),
                supports_reference_link=True,
                supports_reference_video=True,
            ),
        )
        self._workbench_modes: tuple[WorkbenchMode, ...] = (
            WorkbenchMode(
                code="simple",
                label="简单",
                title="AI快速创作",
                subtitle="输入内容后，完成语音转文字、AI校验、英文提示词生成和视频生成。",
                highlights=("语音转文字", "AI校验", "少参数"),
                default_prompt_template_key=None,
                default_video_template_key="warm_album",
                supports_voice_input=True,
                supports_text_correction=True,
                supports_prompt_generation=True,
                requires_images=True,
            ),
            WorkbenchMode(
                code="starter",
                label="入门",
                title="链接入门创作",
                subtitle="在简单模式基础上增加链接地址，结合图片快速生成相关视频。",
                highlights=("视频链接", "上传图片", "快速跟做"),
                default_prompt_template_key=None,
                default_video_template_key="warm_album",
                supports_voice_input=True,
                supports_text_correction=True,
                supports_prompt_generation=True,
                requires_reference_link=True,
                requires_images=True,
            ),
            WorkbenchMode(
                code="custom",
                label="自定义",
                title="模板自定义创作",
                subtitle="在入门模式基础上增加模板选择，可按模板风格生成目标视频。",
                highlights=("热门模板", "样片预览", "自定义生成"),
                default_prompt_template_key="family_memory",
                default_video_template_key="warm_album",
                supports_voice_input=True,
                supports_text_correction=True,
                supports_prompt_generation=True,
                requires_images=True,
                supports_reference_video=True,
            ),
        )

    def list_prompt_templates(self) -> list[dict[str, Any]]:
        return [template.to_dict() for template in self._prompt_templates]

    def list_video_templates(self) -> list[dict[str, Any]]:
        return [template.to_dict() for template in self._video_templates]

    def list_workbench_modes(self) -> list[dict[str, Any]]:
        return [mode.to_dict() for mode in self._workbench_modes]

    def get_workbench_manifest(self) -> dict[str, Any]:
        return {
            "default_mode": self._workbench_modes[0].code,
            "durations": list(self._durations),
            "modes": self.list_workbench_modes(),
            "prompt_templates": self.list_prompt_templates(),
            "video_templates": self.list_video_templates(),
        }

    def get_workbench_mode(self, code: str | None) -> WorkbenchMode:
        if code:
            normalized = code.strip().lower()
            for mode in self._workbench_modes:
                if mode.code == normalized:
                    return mode
        return self._workbench_modes[0]

    def find_prompt_template(self, key: str | None) -> PromptTemplate | None:
        if key:
            normalized = key.strip().lower()
            for template in self._prompt_templates:
                if template.key == normalized:
                    return template
        return None

    def get_prompt_template(self, key: str | None) -> PromptTemplate:
        template = self.find_prompt_template(key)
        if template is not None:
            return template
        return self._prompt_templates[0]

    def get_video_template(self, key: str | None) -> VideoTemplate:
        if key:
            normalized = key.strip().lower()
            for template in self._video_templates:
                if template.key == normalized:
                    return template
        return self._video_templates[0]

    def build_prompt_system_prompt(self, *, prompt_template_key: str | None) -> str:
        template = self.find_prompt_template(prompt_template_key)
        parts = [
            "You are an expert prompt writer for vertical AI video generation. "
            "Convert the user's Chinese requirement into one polished English prompt that can be used directly "
            "by a video model. The prompt should be vivid, concise, and production-ready. "
            "Cover subject, scene, action, camera language, lighting, composition, emotion, subtitle style when useful, "
            "and pacing. Keep the result elderly-friendly with warm, natural visuals, stable framing, readable hierarchy, "
            "and comfortable pacing. If subtitles or on-screen text are needed, they must be in Simplified Chinese. "
            "Preserve every concrete user detail that is provided, including people, location, expression, action, "
            "camera intent, and mood. Never replace explicit content with generic placeholders like 'no specific story "
            "content provided'. Follow the user's requested content first and do not force a fixed preset story, "
            "family-memory framing, or other template unless it is explicitly requested."
        ]
        if template is not None:
            parts.append(
                "When it helps the user's request, you may also apply this optional creative direction: "
                f"{template.generation_instruction}"
            )
        parts.append(
            "Return only the final English prompt with no title, list, explanation, or quotation marks."
        )
        return " ".join(parts)

    def compose_simple_video_request(
        self,
        *,
        prompt: str,
        prompt_template_key: str | None,
        video_template_key: str | None,
        duration: int,
        has_images: bool,
    ) -> dict[str, Any]:
        return self._compose_video_request(
            prompt=prompt,
            prompt_template_key=prompt_template_key,
            video_template_key=video_template_key,
            duration=duration,
            has_images=has_images,
            creation_mode="simple",
        )

    def compose_starter_video_request(
        self,
        *,
        prompt: str | None,
        input_text: str | None,
        prompt_template_key: str | None,
        video_template_key: str | None,
        duration: int,
        has_images: bool,
        reference_link: str,
        supplemental_text: str | None = None,
    ) -> dict[str, Any]:
        requested_prompt = (prompt or "").strip() or self.build_starter_prompt(input_text=input_text)
        return self._compose_video_request(
            prompt=requested_prompt,
            prompt_template_key=prompt_template_key,
            video_template_key=video_template_key,
            duration=duration,
            has_images=has_images,
            creation_mode="starter",
            reference_link=reference_link,
            supplemental_text=supplemental_text,
        )

    def compose_custom_video_request(
        self,
        *,
        prompt: str | None,
        input_text: str | None,
        prompt_template_key: str | None,
        video_template_key: str | None,
        duration: int,
        has_images: bool,
        reference_link: str | None = None,
        reference_video_path: str | None = None,
        supplemental_text: str | None = None,
    ) -> dict[str, Any]:
        video_template = self.get_video_template(video_template_key)
        requested_prompt = (prompt or "").strip() or self.build_custom_prompt(
            template=video_template,
            input_text=input_text,
        )
        return self._compose_video_request(
            prompt=requested_prompt,
            prompt_template_key=prompt_template_key,
            video_template_key=video_template.key,
            duration=duration,
            has_images=has_images,
            creation_mode="custom",
            reference_link=reference_link,
            reference_video_path=reference_video_path,
            supplemental_text=supplemental_text,
        )

    @staticmethod
    def build_starter_prompt(*, input_text: str | None) -> str:
        note = (input_text or "").strip()
        if note:
            return (
                "Create a vertical short video inspired by the linked reference video, "
                "but rebuilt around the uploaded images. "
                f"Additional requirement: {note}"
            )
        return (
            "Create a warm vertical short video inspired by the linked reference video, "
            "using the uploaded images as the main visual references."
        )

    @staticmethod
    def build_custom_prompt(*, template: VideoTemplate, input_text: str | None) -> str:
        note = (input_text or "").strip()
        if note:
            return (
                f"Create a vertical short video based on the '{template.name}' template style. "
                f"Additional requirement: {note}"
            )
        return (
            f"Create a new vertical short video following the '{template.name}' template style, "
            "while adapting the content to the uploaded user materials."
        )

    def _compose_video_request(
        self,
        *,
        prompt: str,
        prompt_template_key: str | None,
        video_template_key: str | None,
        duration: int,
        has_images: bool,
        creation_mode: str | None = None,
        reference_link: str | None = None,
        reference_video_path: str | None = None,
        supplemental_text: str | None = None,
    ) -> dict[str, Any]:
        prompt_template = self.find_prompt_template(prompt_template_key)
        video_template = self.get_video_template(video_template_key)

        segments = [
            f"Core request: {prompt.strip()}",
            (
                "Follow the user's requested subject and story first, and do not force any unrelated preset template, "
                "fixed copy, or stock narrative."
            ),
            (
                "Keep the result suitable for elderly viewers: warm and natural visuals, natural expressions, "
                "stable framing, clean composition, and easy-to-follow pacing."
            ),
            (
                "If subtitles or any on-screen text are used, they must be in Simplified Chinese with large, "
                "clear, high-contrast typography."
            ),
            "Generate a vertical short video and avoid distracting flashy effects.",
        ]
        if prompt_template is not None:
            segments.append(f"Prompt direction: {prompt_template.render_instruction}")
        if creation_mode == "custom":
            segments.extend(
                [
                    f"Visual style: {video_template.style_hint}",
                    f"Camera rhythm: {video_template.shot_hint}",
                    f"Subtitle guidance: {video_template.subtitle_hint}",
                ]
            )
        else:
            segments.extend(
                [
                    (
                        "Visual style: realistic daily-life scenes, natural lighting, and a friendly vertical-video look "
                        "that stays grounded in the user's request."
                    ),
                    (
                        "Camera rhythm: gentle movement, stable medium and close framing, and smooth transitions that support "
                        "the story without becoming flashy."
                    ),
                ]
            )
        if has_images:
            segments.append(
                "Use the uploaded images as references for subject identity, clothing details, and scene elements."
            )
        else:
            segments.append("You may build a realistic home-life scene that matches the request.")

        if creation_mode == "starter":
            segments.append(
                "Reference the linked public video for opening hook, transition rhythm, and overall pacing."
            )
        if reference_link and reference_link.strip():
            segments.append(
                "A public reference video link is provided and can guide structure, tempo, and shot progression."
            )
        if creation_mode == "custom":
            segments.append(
                "Keep the selected template's camera organization, subtitle style, and emotional progression."
            )
        if supplemental_text and supplemental_text.strip():
            segments.append(f"Additional creation note: {supplemental_text.strip()}")
        if reference_video_path:
            segments.append(
                "An extra reference video is uploaded. Mirror its shot pacing and narrative structure when appropriate."
            )

        provider_prompt = "; ".join(
            segment.strip().rstrip(";.")
            for segment in segments
            if segment and segment.strip()
        )

        return {
            "requested_prompt": prompt.strip(),
            "provider_prompt": provider_prompt,
            "duration": duration if duration > 0 else video_template.default_duration,
            "size": video_template.size,
            "prompt_template": prompt_template.to_dict() if prompt_template is not None else None,
            "video_template": video_template.to_dict(),
            "creation_mode": creation_mode or "simple",
            "reference_link": (reference_link or "").strip(),
            "reference_video_path": (reference_video_path or "").strip(),
            "supplemental_text": (supplemental_text or "").strip(),
        }


ai_template_registry_service = AITemplateRegistryService()
