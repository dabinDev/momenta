from __future__ import annotations

from typing import Any

import httpx

from app.models.admin import User
from app.models.ai_model import AIModelCatalog
from app.services.config_store import (
    get_or_create_global_ai_config,
    get_or_create_user_app_config,
    normalize_service_type,
    read_service_api_key,
    read_service_base_url,
)


class ModelCatalogError(Exception):
    pass


class ModelCatalogService:
    default_sync_timeout = httpx.Timeout(connect=20.0, read=60.0, write=60.0, pool=20.0)

    async def sync_models(
        self,
        *,
        scope: str = "global",
        user_id: int | None = None,
        service_type: str,
    ) -> list[dict[str, Any]]:
        config, _, normalized_scope = await self._resolve_scope_config(scope=scope, user_id=user_id)
        normalized_service = normalize_service_type(service_type)
        base_url = read_service_base_url(config, normalized_service)
        api_key = read_service_api_key(config, normalized_service)
        remote_models = await self._fetch_remote_models(base_url=base_url, api_key=api_key)
        catalog = self._build_catalog(
            service_type=normalized_service,
            base_url=base_url,
            remote_models=remote_models,
            current_model=self._read_current_model(config=config, service_type=normalized_service),
        )
        results = []
        for item in catalog:
            row = await self._upsert_catalog_entry(item=item)
            results.append(await self._serialize_row(row=row, current_model=item["current_model"], scope=normalized_scope, user_id=user_id))
        return results

    async def list_models(
        self,
        *,
        scope: str = "global",
        user_id: int | None = None,
        service_type: str,
    ) -> list[dict[str, Any]]:
        config, _, normalized_scope = await self._resolve_scope_config(scope=scope, user_id=user_id)
        normalized_service = normalize_service_type(service_type)
        base_url = read_service_base_url(config, normalized_service)
        current_model = self._read_current_model(config=config, service_type=normalized_service)
        rows = await AIModelCatalog.filter(
            service_type=normalized_service,
            source_base_url=base_url,
            is_active=True,
        ).order_by("-is_recommended", "-capability_score", "model_id")
        if not rows:
            await self.sync_models(scope=normalized_scope, user_id=user_id, service_type=normalized_service)
            rows = await AIModelCatalog.filter(
                service_type=normalized_service,
                source_base_url=base_url,
                is_active=True,
            ).order_by("-is_recommended", "-capability_score", "model_id")
        return [await self._serialize_row(row=row, current_model=current_model, scope=normalized_scope, user_id=user_id) for row in rows]

    async def recommend_models(
        self,
        *,
        scope: str = "global",
        user_id: int | None = None,
        service_type: str,
        prioritize: str = "balanced",
        need_image_input: bool = True,
    ) -> dict[str, Any]:
        normalized_service = normalize_service_type(service_type)
        models = await self.list_models(scope=scope, user_id=user_id, service_type=normalized_service)
        scored = []
        for item in models:
            if need_image_input and normalized_service == "video" and not bool(item.get("supports_image_input")):
                continue
            score = self._score_model(
                service_type=normalized_service,
                prioritize=prioritize,
                price_level=int(item.get("price_level") or 3),
                speed_level=int(item.get("speed_level") or 3),
                quality_level=int(item.get("quality_level") or 3),
                supports_video=bool(item.get("supports_video")),
                supports_image_input=bool(item.get("supports_image_input")),
            )
            if item.get("source_kind") == "curated":
                score += 0.35
            enriched = dict(item)
            enriched["recommendation_score"] = round(score, 2)
            scored.append(enriched)
        scored.sort(key=lambda item: (-float(item["recommendation_score"]), item.get("model_id", "")))
        top = scored[0] if scored else None

        if top:
            await AIModelCatalog.filter(id=top["id"]).update(is_recommended=True)
            await AIModelCatalog.filter(
                service_type=normalized_service,
                source_base_url=top.get("source_base_url", ""),
            ).exclude(id=top["id"]).update(is_recommended=False)

        return {
            "scope": str(scope or "global"),
            "user_id": user_id,
            "recommended": top,
            "items": scored,
            "prioritize": prioritize,
            "service_type": normalized_service,
        }

    async def apply_model(
        self,
        *,
        scope: str = "global",
        user_id: int | None = None,
        service_type: str,
        model_id: str,
    ) -> dict[str, Any]:
        config, user, normalized_scope = await self._resolve_scope_config(scope=scope, user_id=user_id)
        normalized_service = normalize_service_type(service_type)
        value = str(model_id or "").strip()
        if not value:
            raise ModelCatalogError("模型标识不能为空")

        field_name = self._model_field(normalized_service)
        setattr(config, field_name, value)
        if normalized_scope == "user":
            config.override_enabled = True
            if user is not None and not user.allow_private_ai_override:
                user.allow_private_ai_override = True
                await user.save()
        await config.save()
        return {
            "scope": normalized_scope,
            "user_id": user_id,
            "service_type": normalized_service,
            "model_id": value,
        }

    async def _resolve_scope_config(self, *, scope: str, user_id: int | None):
        normalized_scope = str(scope or "global").strip().lower()
        if normalized_scope == "user":
            if not user_id:
                raise ModelCatalogError("私有模型目录必须指定用户")
            user = await User.get(id=user_id)
            if not user.allow_private_ai_override:
                raise ModelCatalogError("当前用户未开通专属模型通道")
            config = await get_or_create_user_app_config(user_id)
            return config, user, normalized_scope

        config = await get_or_create_global_ai_config()
        return config, None, "global"

    async def _fetch_remote_models(self, *, base_url: str, api_key: str) -> list[dict[str, Any]]:
        if not base_url or not api_key:
            raise ModelCatalogError("当前能力未配置可用的服务地址或密钥")

        normalized_base_url = base_url.rstrip("/")
        async with httpx.AsyncClient(timeout=self.default_sync_timeout, follow_redirects=True) as client:
            try:
                response = await client.get(
                    self._build_url(normalized_base_url, "/v1/models"),
                    headers={
                        "Authorization": f"Bearer {api_key}",
                        "Accept": "application/json",
                    },
                )
                response.raise_for_status()
            except httpx.HTTPStatusError as exc:
                raise ModelCatalogError(self._read_error_detail(exc.response)) from exc
            except httpx.HTTPError as exc:
                raise ModelCatalogError("同步模型目录失败，请检查平台地址是否可用") from exc

        payload = response.json()
        data = payload.get("data") if isinstance(payload, dict) else None
        return data if isinstance(data, list) else []

    def _build_catalog(
        self,
        *,
        service_type: str,
        base_url: str,
        remote_models: list[dict[str, Any]],
        current_model: str,
    ) -> list[dict[str, Any]]:
        results: dict[str, dict[str, Any]] = {}

        for model in remote_models:
            normalized = self._normalize_remote_model(
                service_type=service_type,
                base_url=base_url,
                model=model,
                current_model=current_model,
            )
            if normalized is None:
                continue
            results[normalized["model_id"]] = normalized

        for curated in self._curated_models(service_type=service_type, base_url=base_url, current_model=current_model):
            results[curated["model_id"]] = {**results.get(curated["model_id"], {}), **curated}

        return list(results.values())

    def _normalize_remote_model(
        self,
        *,
        service_type: str,
        base_url: str,
        model: dict[str, Any],
        current_model: str,
    ) -> dict[str, Any] | None:
        model_id = str(model.get("id") or "").strip()
        if not model_id:
            return None
        endpoint_types = model.get("supported_endpoint_types")
        endpoint_types = endpoint_types if isinstance(endpoint_types, list) else []

        if service_type == "speech" and not self._is_speech_model(model_id, endpoint_types):
            return None
        if service_type == "video" and not self._is_video_model(model_id, endpoint_types):
            return None
        if service_type == "image" and not self._is_image_model(model_id, endpoint_types):
            return None
        if service_type == "llm" and not self._is_llm_model(model_id, endpoint_types):
            return None

        price_level, speed_level, quality_level = self._estimate_levels(service_type=service_type, model_id=model_id)
        supports_image_input = service_type == "video" and ("components" in model_id.lower() or "image" in model_id.lower())
        capability_score = self._score_model(
            service_type=service_type,
            prioritize="balanced",
            price_level=price_level,
            speed_level=speed_level,
            quality_level=quality_level,
            supports_video=service_type == "video",
            supports_image_input=supports_image_input,
        )
        return {
            "service_type": service_type,
            "model_id": model_id,
            "display_name": str(model.get("display_name") or model_id),
            "source_base_url": base_url,
            "source_kind": "remote",
            "owned_by": str(model.get("owned_by") or ""),
            "endpoint_types": endpoint_types,
            "supports_video": service_type == "video",
            "supports_image_input": supports_image_input,
            "price_level": price_level,
            "speed_level": speed_level,
            "quality_level": quality_level,
            "capability_score": capability_score,
            "is_active": True,
            "is_recommended": model_id == current_model,
            "tags": endpoint_types,
            "notes": "从平台模型目录同步",
            "raw_payload": model,
            "current_model": current_model,
        }

    def _curated_models(self, *, service_type: str, base_url: str, current_model: str) -> list[dict[str, Any]]:
        curated: list[dict[str, Any]] = []
        default_curated = {
            "video": [
                {
                    "model_id": "veo_3_1-fast-components-4K",
                    "display_name": "veo_3_1-fast-components-4K",
                    "supports_video": True,
                    "supports_image_input": True,
                    "price_level": 3,
                    "speed_level": 5,
                    "quality_level": 5,
                    "tags": ["video", "image-to-video", "4k", "relay"],
                    "notes": "当前项目默认的视频生成模型",
                },
            ],
            "speech": [
                {
                    "model_id": "gpt-4o-mini-audio-preview",
                    "display_name": "gpt-4o-mini-audio-preview",
                    "supports_video": False,
                    "supports_image_input": False,
                    "price_level": 3,
                    "speed_level": 4,
                    "quality_level": 4,
                    "tags": ["speech", "audio-preview"],
                    "notes": "当前项目默认的语音解析模型",
                },
            ],
            "llm": [
                {
                    "model_id": "gpt-5.4-mini",
                    "display_name": "gpt-5.4-mini",
                    "supports_video": False,
                    "supports_image_input": False,
                    "price_level": 3,
                    "speed_level": 4,
                    "quality_level": 5,
                    "tags": ["llm", "prompt-generation"],
                    "notes": "当前项目默认的文本解析模型",
                },
            ],
            "image": [
                {
                    "model_id": "gpt-image-1",
                    "display_name": "gpt-image-1",
                    "supports_video": False,
                    "supports_image_input": False,
                    "price_level": 3,
                    "speed_level": 3,
                    "quality_level": 4,
                    "tags": ["image", "generation"],
                    "notes": "图片生成能力的常用推荐模型",
                },
            ],
        }
        for item in default_curated.get(service_type, []):
            curated.append(
                {
                    "service_type": service_type,
                    "source_base_url": base_url,
                    "source_kind": "curated",
                    "owned_by": "curated",
                    "endpoint_types": item["tags"],
                    "capability_score": self._score_model(
                        service_type=service_type,
                        prioritize="balanced",
                        price_level=item["price_level"],
                        speed_level=item["speed_level"],
                        quality_level=item["quality_level"],
                        supports_video=item["supports_video"],
                        supports_image_input=item["supports_image_input"],
                    ),
                    "is_active": True,
                    "is_recommended": item["model_id"] == current_model,
                    "raw_payload": {"curated": True, "model_id": item["model_id"]},
                    "current_model": current_model,
                    **item,
                }
            )
        if current_model and all(item["model_id"] != current_model for item in curated):
            price_level, speed_level, quality_level = self._estimate_levels(service_type=service_type, model_id=current_model)
            curated.append(
                {
                    "service_type": service_type,
                    "model_id": current_model,
                    "display_name": current_model,
                    "source_base_url": base_url,
                    "source_kind": "current_config",
                    "owned_by": "current_config",
                    "endpoint_types": [service_type],
                    "supports_video": service_type == "video",
                    "supports_image_input": service_type == "video",
                    "price_level": price_level,
                    "speed_level": speed_level,
                    "quality_level": quality_level,
                    "capability_score": self._score_model(
                        service_type=service_type,
                        prioritize="balanced",
                        price_level=price_level,
                        speed_level=speed_level,
                        quality_level=quality_level,
                        supports_video=service_type == "video",
                        supports_image_input=service_type == "video",
                    ),
                    "is_active": True,
                    "is_recommended": True,
                    "tags": ["current"],
                    "notes": "当前已应用的模型",
                    "raw_payload": {"current": True, "model_id": current_model},
                    "current_model": current_model,
                }
            )
        return curated

    async def _upsert_catalog_entry(self, *, item: dict[str, Any]) -> AIModelCatalog:
        payload = {key: value for key, value in item.items() if key != "current_model"}
        row = await AIModelCatalog.filter(
            service_type=payload["service_type"],
            model_id=payload["model_id"],
            source_base_url=payload["source_base_url"],
        ).first()
        if row is None:
            row = await AIModelCatalog.create(**payload)
            return row
        row.update_from_dict(payload)
        await row.save()
        return row

    async def _serialize_row(
        self,
        *,
        row: AIModelCatalog,
        current_model: str,
        scope: str,
        user_id: int | None,
    ) -> dict[str, Any]:
        payload = await row.to_dict()
        payload["scope"] = scope
        payload["user_id"] = user_id
        payload["is_current"] = payload.get("model_id") == current_model
        return payload

    @staticmethod
    def _model_field(service_type: str) -> str:
        mapping = {
            "llm": "llm_model",
            "video": "video_model",
            "speech": "speech_model",
            "image": "image_model",
        }
        return mapping.get(service_type, "video_model")

    def _read_current_model(self, *, config, service_type: str) -> str:
        return str(getattr(config, self._model_field(service_type), "") or "").strip()

    @staticmethod
    def _build_url(base_url: str, versioned_path: str) -> str:
        normalized_base = base_url.rstrip("/")
        if normalized_base.endswith("/v1") and versioned_path.startswith("/v1/"):
            return f"{normalized_base}{versioned_path.removeprefix('/v1')}"
        return f"{normalized_base}{versioned_path}"

    @staticmethod
    def _is_speech_model(model_id: str, endpoint_types: list[str]) -> bool:
        lower = model_id.lower()
        joined = " ".join(str(item).lower() for item in endpoint_types)
        return any(token in lower or token in joined for token in ("audio-preview", "whisper", "transcribe", "asr", "audio"))

    @staticmethod
    def _is_video_model(model_id: str, endpoint_types: list[str]) -> bool:
        lower = model_id.lower()
        joined = " ".join(str(item).lower() for item in endpoint_types)
        return any(token in lower or token in joined for token in ("veo", "video", "kling", "wan", "vidu", "sora"))

    @staticmethod
    def _is_image_model(model_id: str, endpoint_types: list[str]) -> bool:
        lower = model_id.lower()
        joined = " ".join(str(item).lower() for item in endpoint_types)
        return any(
            token in lower or token in joined
            for token in ("image", "flux", "dall", "recraft", "imagen", "stable-diffusion", "midjourney", "sdxl")
        )

    def _is_llm_model(self, model_id: str, endpoint_types: list[str]) -> bool:
        if self._is_speech_model(model_id, endpoint_types):
            return False
        if self._is_video_model(model_id, endpoint_types):
            return False
        if self._is_image_model(model_id, endpoint_types):
            return False
        lower = model_id.lower()
        joined = " ".join(str(item).lower() for item in endpoint_types)
        if any(token in lower for token in ("gpt", "claude", "qwen", "deepseek", "glm", "kimi", "gemini", "llama", "mistral", "doubao")):
            return True
        return any(token in joined for token in ("chat", "responses", "completions"))

    @staticmethod
    def _estimate_levels(*, service_type: str, model_id: str) -> tuple[int, int, int]:
        lower = model_id.lower()
        price_level = 3
        speed_level = 3
        quality_level = 3
        if "mini" in lower or "fast" in lower:
            price_level = 2
            speed_level = 5
        if "nano" in lower:
            price_level = 1
            speed_level = 5
            quality_level = 2
        if "4k" in lower or "max" in lower or "pro" in lower:
            price_level = 4
            quality_level = 5
        if "preview" in lower:
            speed_level = max(speed_level, 4)
        if service_type == "video" and "components" in lower:
            quality_level = 5
            speed_level = max(speed_level, 4)
        if service_type == "image" and "image" in lower:
            quality_level = max(quality_level, 4)
        return price_level, speed_level, quality_level

    @staticmethod
    def _score_model(
        *,
        service_type: str,
        prioritize: str,
        price_level: int,
        speed_level: int,
        quality_level: int,
        supports_video: bool,
        supports_image_input: bool,
    ) -> float:
        price_component = 6 - price_level
        if prioritize == "cheap":
            base = price_component * 0.45 + speed_level * 0.3 + quality_level * 0.25
        elif prioritize == "fast":
            base = speed_level * 0.45 + price_component * 0.25 + quality_level * 0.3
        elif prioritize == "quality":
            base = quality_level * 0.5 + speed_level * 0.2 + price_component * 0.3
        else:
            base = quality_level * 0.38 + speed_level * 0.34 + price_component * 0.28
        if service_type == "video":
            if supports_video:
                base += 1.2
            if supports_image_input:
                base += 0.8
        if service_type == "image":
            base += 0.4
        return round(base, 2)

    @staticmethod
    def _read_error_detail(response: httpx.Response) -> str:
        try:
            payload = response.json()
        except ValueError:
            payload = response.text
        if isinstance(payload, dict):
            error = payload.get("error")
            if isinstance(error, dict) and error.get("message"):
                return str(error["message"])
            for key in ("message", "detail", "error"):
                if payload.get(key):
                    return str(payload[key])
        if isinstance(payload, str) and payload.strip():
            return payload.strip()
        return f"平台模型目录请求失败，状态码 {response.status_code}"


model_catalog_service = ModelCatalogService()
