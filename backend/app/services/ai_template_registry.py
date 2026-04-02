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
                description="适合家人团聚、陪伴、老照片回忆等暖心内容。",
                generation_instruction=(
                    "突出家庭陪伴、亲切情绪、温暖光线、清晰字幕和适合中老年观看的慢节奏表达。"
                ),
                render_instruction=(
                    "画面以家庭情感和真实生活场景为核心，镜头稳定，情绪温暖自然，适合做回忆类短视频。"
                ),
                preview="暖色调、真实家庭氛围、字幕清楚、节奏舒缓。",
                is_default=True,
            ),
            PromptTemplate(
                key="festival_blessing",
                name="节日祝福",
                description="适合生日、节庆、问候、感恩祝福类创作。",
                generation_instruction=(
                    "突出节日仪式感、祝福表达、喜庆但不过度花哨的视觉风格，语言真诚易懂。"
                ),
                render_instruction=(
                    "强化祝福主题、节日元素和情绪传递，字幕醒目，适合长辈观看和转发。"
                ),
                preview="节日元素明确，祝福语自然，画面热闹但不杂乱。",
            ),
            PromptTemplate(
                key="health_share",
                name="健康分享",
                description="适合养生提醒、生活建议、科普提醒类内容。",
                generation_instruction=(
                    "强调重点信息、条理表达、可信赖的日常分享感，画面整洁，字幕字号偏大。"
                ),
                render_instruction=(
                    "突出信息重点和阅读友好度，镜头简洁平稳，适合做生活提醒和知识分享。"
                ),
                preview="重点突出、信息清楚、镜头简洁、阅读压力低。",
            ),
        )
        self._video_templates: tuple[VideoTemplate, ...] = (
            VideoTemplate(
                key="warm_album",
                name="暖心相册",
                description="照片串联、家庭合影、回忆记录的默认模板。",
                style_hint="暖色调，柔和光线，家庭纪念感，人物表情自然。",
                shot_hint="多用慢推拉、轻微运镜和稳定中近景，转场柔和。",
                subtitle_hint="字幕字号较大，颜色对比清楚，阅读轻松。",
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
                style_hint="画面克制，主体清晰，字幕承载主要信息，风格稳重。",
                shot_hint="镜头节奏均匀，以固定镜头和轻缓切换为主。",
                subtitle_hint="分段字幕清晰，重点词突出，适合边看边读。",
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
                style_hint="自然写实，生活化场景，色彩明亮不过饱和。",
                shot_hint="以纪实镜头为主，可加入少量跟拍与环境特写。",
                subtitle_hint="字幕简洁，不遮挡主体，保留生活氛围。",
                preview="适合日常片段、活动记录、生活分享。",
                default_duration=10,
                preview_video_url=(
                    "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4"
                ),
                popularity=89,
                tags=("纪实", "生活感", "跟拍"),
                supports_reference_link=False,
                supports_reference_video=True,
            ),
        )
        self._workbench_modes: tuple[WorkbenchMode, ...] = (
            WorkbenchMode(
                code="simple",
                label="简单",
                title="AI 快速创作",
                subtitle="保留语音转写、AI 校准、提示词生成和基础成片能力。",
                highlights=("语音转文字", "AI 校准", "少参数"),
                default_prompt_template_key="family_memory",
                default_video_template_key="warm_album",
                supports_voice_input=True,
                supports_text_correction=True,
                supports_prompt_generation=True,
            ),
            WorkbenchMode(
                code="starter",
                label="入门",
                title="链接跟做",
                subtitle="复制公开视频链接，结合上传图片快速生成同主题短视频。",
                highlights=("视频链接", "上传图片", "快速跟做"),
                default_prompt_template_key="family_memory",
                default_video_template_key="warm_album",
                requires_reference_link=True,
                requires_images=True,
            ),
            WorkbenchMode(
                code="custom",
                label="自定义",
                title="模板复刻",
                subtitle="查看热门模板样片，按模板或参考短视频去复刻成片。",
                highlights=("热门模板", "样片预览", "图片和短视频"),
                default_prompt_template_key="family_memory",
                default_video_template_key="warm_album",
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

    def get_prompt_template(self, key: str | None) -> PromptTemplate:
        if key:
            normalized = key.strip().lower()
            for template in self._prompt_templates:
                if template.key == normalized:
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
        template = self.get_prompt_template(prompt_template_key)
        return (
            "你是短视频创作提示词专家。"
            "请把用户输入转换成适合视频生成模型理解的中文提示词。"
            "需要覆盖主体、场景、镜头、光线、构图、情绪、字幕和节奏。"
            f"优先遵循这个创作模板方向：{template.generation_instruction}"
            "输出一段完整的中文提示词，不要添加解释、标题或序号。"
        )

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
            reference_video_path=reference_video_path,
            supplemental_text=supplemental_text,
        )

    @staticmethod
    def build_starter_prompt(*, input_text: str | None) -> str:
        note = (input_text or "").strip()
        if note:
            return f"参考公开视频的节奏和结构，结合上传图片生成竖屏短视频，重点要求：{note}"
        return "参考公开视频的节奏和结构，结合上传图片生成一条适合家庭分享的竖屏短视频。"

    @staticmethod
    def build_custom_prompt(*, template: VideoTemplate, input_text: str | None) -> str:
        note = (input_text or "").strip()
        if note:
            return f"参考{template.name}模板生成竖屏短视频，并满足以下要求：{note}"
        return f"参考{template.name}模板的镜头节奏、字幕风格和情绪推进，结合上传素材生成新的家庭短视频。"

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
        prompt_template = self.get_prompt_template(prompt_template_key)
        video_template = self.get_video_template(video_template_key)

        segments = [
            f"主题提示词：{prompt.strip()}",
            f"提示词模板要求：{prompt_template.render_instruction}",
            f"视频模板风格：{video_template.style_hint}",
            f"镜头节奏：{video_template.shot_hint}",
            f"字幕要求：{video_template.subtitle_hint}",
            "适合中老年用户观看，字幕清晰，人物表情自然，画面稳定。",
            "请生成竖屏短视频，避免复杂特效和眩光。",
        ]
        if has_images:
            segments.append("请参考上传图片中的人物关系、服饰特征和场景元素。")
        else:
            segments.append("可自由补充贴近家庭生活的真实场景。")

        if creation_mode == "starter":
            segments.append("整体节奏参考热门短视频的开场、转场和收束方式。")
        if reference_link and reference_link.strip():
            segments.append("用户提供了公开视频链接，可将其视为节奏与结构参考。")
        if creation_mode == "custom":
            segments.append("保持样片模板的镜头组织、字幕风格和情绪推进，但主体内容换成用户素材。")
        if supplemental_text and supplemental_text.strip():
            segments.append(f"额外创作要求：{supplemental_text.strip()}")
        if reference_video_path:
            segments.append("用户提供了参考短视频，请尽量模仿其镜头节奏与叙事结构。")

        provider_prompt = "；".join(
            segment.strip().rstrip("；。")
            for segment in segments
            if segment and segment.strip()
        )

        return {
            "requested_prompt": prompt.strip(),
            "provider_prompt": provider_prompt,
            "duration": duration if duration > 0 else video_template.default_duration,
            "size": video_template.size,
            "prompt_template": prompt_template.to_dict(),
            "video_template": video_template.to_dict(),
            "creation_mode": creation_mode or "simple",
            "reference_link": (reference_link or "").strip(),
            "reference_video_path": (reference_video_path or "").strip(),
            "supplemental_text": (supplemental_text or "").strip(),
        }


ai_template_registry_service = AITemplateRegistryService()
