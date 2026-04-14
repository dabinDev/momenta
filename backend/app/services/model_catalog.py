from __future__ import annotations

import json
import re
import time
from datetime import datetime, timedelta, timezone
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
    hub_pricing_cache_ttl_seconds = 180

    def __init__(self) -> None:
        self._hub_pricing_cache: dict[str, dict[str, Any]] = {}

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
        model_ids = [str(item.get("model_id") or "").strip() for item in catalog if str(item.get("model_id") or "").strip()]
        stale_rows = AIModelCatalog.filter(service_type=normalized_service, source_base_url=base_url)
        if model_ids:
            await stale_rows.exclude(model_id__in=model_ids).update(is_active=False, is_recommended=False)
        else:
            await stale_rows.update(is_active=False, is_recommended=False)
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
        api_key = read_service_api_key(config, normalized_service)
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
        items = [await self._serialize_row(row=row, current_model=current_model, scope=normalized_scope, user_id=user_id) for row in rows]
        return await self._enrich_catalog_items(
            items=items,
            service_type=normalized_service,
            base_url=base_url,
            api_key=api_key,
        )

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
        candidates = []
        for item in models:
            if need_image_input and normalized_service == "video" and not bool(item.get("supports_image_input")):
                continue
            candidates.append(item)

        price_components = self._build_price_components(service_type=normalized_service, items=candidates)
        scored = []
        for item in candidates:
            canonical_model_id = self._canonical_model_id(str(item.get("model_id") or ""))
            score = self._score_model(
                service_type=normalized_service,
                prioritize=prioritize,
                price_level=int(item.get("price_level") or 3),
                price_component=price_components.get(canonical_model_id),
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

        for item in scored:
            item["is_recommended"] = bool(top and item.get("id") == top.get("id"))

        if top:
            await AIModelCatalog.filter(id=top["id"]).update(is_recommended=True)
            await AIModelCatalog.filter(
                service_type=normalized_service,
                source_base_url=top.get("source_base_url", ""),
            ).exclude(id=top["id"]).update(is_recommended=False)
        elif models:
            await AIModelCatalog.filter(
                service_type=normalized_service,
                source_base_url=models[0].get("source_base_url", ""),
            ).update(is_recommended=False)

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
        owned_by = str(model.get("owned_by") or "").strip()
        endpoint_types = model.get("supported_endpoint_types")
        endpoint_types = endpoint_types if isinstance(endpoint_types, list) else []

        if service_type == "speech" and not self._is_speech_model(model_id, endpoint_types):
            return None
        if service_type == "speech" and not self._supports_speech_runtime(model_id, endpoint_types, owned_by):
            return None
        if service_type == "video" and not self._is_video_model(model_id, endpoint_types):
            return None
        if service_type == "video" and not self._supports_video_runtime(model_id, endpoint_types, owned_by):
            return None
        if service_type == "image" and not self._is_image_model(model_id, endpoint_types):
            return None
        if service_type == "llm" and not self._is_llm_model(model_id, endpoint_types):
            return None

        price_level, speed_level, quality_level = self._estimate_levels(service_type=service_type, model_id=model_id)
        supports_image_input = service_type == "video" and self._supports_video_image_input(
            model_id,
            endpoint_types,
            owned_by,
        )
        capability_score = self._score_model(
            service_type=service_type,
            prioritize="balanced",
            price_level=price_level,
            price_component=None,
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
            "owned_by": owned_by,
            "endpoint_types": endpoint_types,
            "supports_video": service_type == "video",
            "supports_image_input": supports_image_input,
            "price_level": price_level,
            "speed_level": speed_level,
            "quality_level": quality_level,
            "capability_score": capability_score,
            "is_active": True,
            "is_recommended": False,
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
                    "model_id": "veo3.1-fast",
                    "display_name": "veo3.1-fast",
                    "supports_video": True,
                    "supports_image_input": True,
                    "price_level": 2,
                    "speed_level": 5,
                    "quality_level": 4,
                    "tags": ["video", "image-to-video", "veo-3.1", "relay"],
                    "notes": "99hub doc image-to-video example model",
                },
                {
                    "model_id": "veo3-fast-frames",
                    "display_name": "veo3-fast-frames",
                    "supports_video": True,
                    "supports_image_input": True,
                    "price_level": 2,
                    "speed_level": 5,
                    "quality_level": 4,
                    "tags": ["video", "image-to-video", "veo-3", "relay"],
                    "notes": "99hub doc multi-frame image-to-video model",
                },
                {
                    "model_id": "veo3.1-components",
                    "display_name": "veo3.1-components",
                    "supports_video": True,
                    "supports_image_input": True,
                    "price_level": 3,
                    "speed_level": 4,
                    "quality_level": 5,
                    "tags": ["video", "image-to-video", "veo-3.1", "relay"],
                    "notes": "99hub doc reference-image VEO 3.1 model",
                },
                {
                    "model_id": "veo_3_1-fast-components-4K",
                    "display_name": "veo_3_1-fast-components-4K",
                    "supports_video": True,
                    "supports_image_input": True,
                    "price_level": 2,
                    "speed_level": 5,
                    "quality_level": 5,
                    "tags": ["video", "image-to-video", "4k", "openai-compatible"],
                    "notes": "Current default video model",
                },
                {
                    "model_id": "veo_3_1",
                    "display_name": "veo_3_1",
                    "supports_video": True,
                    "supports_image_input": True,
                    "price_level": 3,
                    "speed_level": 4,
                    "quality_level": 5,
                    "tags": ["video", "image-to-video", "veo-3.1", "openai-compatible"],
                    "notes": "99hub doc OpenAI-compatible VEO 3.1 model",
                },
                {
                    "model_id": "sora_image",
                    "display_name": "sora_image",
                    "supports_video": True,
                    "supports_image_input": True,
                    "price_level": 3,
                    "speed_level": 3,
                    "quality_level": 4,
                    "tags": ["video", "image-to-video", "openai-compatible"],
                    "notes": "OpenAI compatible image-to-video runtime",
                },
                {
                    "model_id": "doubao-seedance-1-0-lite-i2v-250428",
                    "display_name": "doubao-seedance-1-0-lite-i2v-250428",
                    "supports_video": True,
                    "supports_image_input": True,
                    "price_level": 3,
                    "speed_level": 5,
                    "quality_level": 4,
                    "tags": ["video", "image-to-video", "volc", "seedance", "lite"],
                    "notes": "H5 verified image-to-video path on 2026-04-14",
                },
                {
                    "model_id": "gen4_turbo",
                    "display_name": "gen4_turbo",
                    "supports_video": True,
                    "supports_image_input": True,
                    "price_level": 4,
                    "speed_level": 3,
                    "quality_level": 4,
                    "tags": ["video", "image-to-video", "runway", "gen4"],
                    "notes": "Runway image-to-video path supported by current runtime",
                },
                {
                    "model_id": "MiniMax-Hailuo-02",
                    "display_name": "MiniMax-Hailuo-02",
                    "supports_video": True,
                    "supports_image_input": False,
                    "price_level": 5,
                    "speed_level": 4,
                    "quality_level": 4,
                    "tags": ["video", "text-to-video", "minimax", "hailuo"],
                    "notes": "MiniMax text-to-video path supported by current runtime",
                },
                {
                    "model_id": "MiniMax-Hailuo-2.3",
                    "display_name": "MiniMax-Hailuo-2.3",
                    "supports_video": True,
                    "supports_image_input": True,
                    "price_level": 5,
                    "speed_level": 4,
                    "quality_level": 5,
                    "tags": ["video", "image-to-video", "minimax", "hailuo"],
                    "notes": "MiniMax image-to-video path supported by current runtime",
                },
                {
                    "model_id": "minimax/video-01-live",
                    "display_name": "minimax/video-01-live",
                    "supports_video": True,
                    "supports_image_input": True,
                    "price_level": 4,
                    "speed_level": 4,
                    "quality_level": 3,
                    "tags": ["video", "image-to-video", "replicate", "minimax"],
                    "notes": "Replicate image-to-video path supported by current runtime",
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
        if service_type == "video" and not self._is_hub_base_url(base_url):
            default_curated["video"] = [
                item
                for item in default_curated["video"]
                if item["model_id"] in {
                    "veo3.1-fast",
                    "veo3-fast-frames",
                    "veo3.1-components",
                    "veo_3_1-fast-components-4K",
                    "veo_3_1",
                    "sora_image",
                }
            ]
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
                        price_component=None,
                        speed_level=item["speed_level"],
                        quality_level=item["quality_level"],
                        supports_video=item["supports_video"],
                        supports_image_input=item["supports_image_input"],
                    ),
                    "is_active": True,
                    "is_recommended": False,
                    "raw_payload": {"curated": True, "model_id": item["model_id"]},
                    "current_model": current_model,
                    **item,
                }
            )
        if current_model and all(item["model_id"] != current_model for item in curated):
            price_level, speed_level, quality_level = self._estimate_levels(service_type=service_type, model_id=current_model)
            supports_video = service_type == "video" and self._supports_video_runtime(current_model, [service_type], "current_config")
            supports_image_input = service_type == "video" and self._supports_video_image_input(
                current_model,
                [service_type],
                "current_config",
            )
            curated.append(
                {
                    "service_type": service_type,
                    "model_id": current_model,
                    "display_name": current_model,
                    "source_base_url": base_url,
                    "source_kind": "current_config",
                    "owned_by": "current_config",
                    "endpoint_types": [service_type],
                    "supports_video": supports_video,
                    "supports_image_input": supports_image_input,
                    "price_level": price_level,
                    "speed_level": speed_level,
                    "quality_level": quality_level,
                    "capability_score": self._score_model(
                        service_type=service_type,
                        prioritize="balanced",
                        price_level=price_level,
                        price_component=None,
                        speed_level=speed_level,
                        quality_level=quality_level,
                        supports_video=supports_video,
                        supports_image_input=supports_image_input,
                    ),
                    "is_active": True,
                    "is_recommended": False,
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
        if row.is_recommended and not payload.get("is_recommended"):
            payload["is_recommended"] = True
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

    async def _enrich_catalog_items(
        self,
        *,
        items: list[dict[str, Any]],
        service_type: str,
        base_url: str,
        api_key: str,
    ) -> list[dict[str, Any]]:
        if not items or not self._is_hub_base_url(base_url):
            return items

        signals = await self._fetch_hub_pricing_signals(api_key=api_key)
        if not signals:
            return items

        enriched: list[dict[str, Any]] = []
        for item in items:
            payload = dict(item)
            signal = signals.get(self._canonical_model_id(str(payload.get("model_id") or "")))
            if signal:
                payload.update(signal)
            enriched.append(payload)
        return enriched

    @staticmethod
    def _build_url(base_url: str, versioned_path: str) -> str:
        normalized_base = base_url.rstrip("/")
        if normalized_base.endswith("/v1") and versioned_path.startswith("/v1/"):
            return f"{normalized_base}{versioned_path.removeprefix('/v1')}"
        return f"{normalized_base}{versioned_path}"

    async def _fetch_hub_pricing_signals(self, *, api_key: str) -> dict[str, dict[str, Any]]:
        token = str(api_key or "").strip()
        if not token:
            return {}

        cache_key = f"hub-pricing:{token}"
        cached = self._hub_pricing_cache.get(cache_key)
        now = time.time()
        if cached and now - float(cached.get("fetched_at") or 0) < self.hub_pricing_cache_ttl_seconds:
            return dict(cached.get("data") or {})

        end_at = datetime.now(timezone.utc)
        start_at = end_at - timedelta(days=30)
        params = {
            "key": token,
            "page": 1,
            "page_size": 200,
            "start_timestamp": int(start_at.timestamp()),
            "end_timestamp": int(end_at.timestamp()),
        }

        try:
            async with httpx.AsyncClient(timeout=self.default_sync_timeout, follow_redirects=True) as client:
                response = await client.get(
                    "https://api.apiplus.org/api/log/token",
                    params=params,
                    headers={"Accept": "application/json"},
                )
                response.raise_for_status()
        except httpx.HTTPError:
            return {}

        try:
            payload = response.json()
        except ValueError:
            return {}

        raw_data = payload.get("data") if isinstance(payload, dict) else None
        raw_items = raw_data.get("items") if isinstance(raw_data, dict) else None
        raw_items = raw_items if isinstance(raw_items, list) else []

        buckets: dict[str, list[dict[str, Any]]] = {}
        for raw_item in raw_items:
            signal = self._parse_hub_pricing_signal(raw_item)
            if signal is None:
                continue
            buckets.setdefault(signal["model_id"], []).append(signal)

        data: dict[str, dict[str, Any]] = {}
        for model_id, entries in buckets.items():
            request_entries = [item for item in entries if item.get("effective_price") is not None]
            ratio_entries = [item for item in entries if item.get("price_ratio") is not None]
            preferred_entries = request_entries or ratio_entries or entries
            latest = max(preferred_entries, key=lambda item: int(item.get("observed_at_ts") or 0))
            data[model_id] = {key: value for key, value in latest.items() if key != "observed_at_ts"}

        self._hub_pricing_cache[cache_key] = {
            "fetched_at": now,
            "data": data,
        }
        return data

    def _parse_hub_pricing_signal(self, item: dict[str, Any]) -> dict[str, Any] | None:
        if not isinstance(item, dict):
            return None

        model_id = self._canonical_model_id(str(item.get("model_name") or ""))
        if not model_id:
            return None

        log_type = int(item.get("type") or 0)
        quota = int(item.get("quota") or 0)
        if log_type != 2 or quota <= 0:
            return None

        content = str(item.get("content") or "").strip()
        other_payload = item.get("other")
        other: dict[str, Any] = {}
        if isinstance(other_payload, str) and other_payload and other_payload != "null":
            try:
                parsed_other = json.loads(other_payload)
            except ValueError:
                parsed_other = {}
            if isinstance(parsed_other, dict):
                other = parsed_other

        effective_price = round(quota / 500000, 6)
        group_ratio = self._safe_positive_float(other.get("group_ratio"))
        if group_ratio is None:
            group_ratio = self._extract_decimal(content, r"分组倍率\s*([0-9.]+)")

        official_price = self._safe_positive_float(other.get("model_price"))
        if official_price is None:
            for pattern in (
                r"单次价格\s*([0-9.]+)",
                r"模型固定价格\s*([0-9.]+)",
                r"模型价格\s*\$?([0-9.]+)",
            ):
                official_price = self._extract_decimal(content, pattern)
                if official_price is not None:
                    break

        price_ratio = self._extract_decimal(content, r"模型倍率\s*([0-9.]+)")
        completion_price_ratio = self._extract_decimal(content, r"补全倍率\s*([0-9.]+)")

        price_type = "observed"
        if official_price is not None:
            price_type = "request"
        elif price_ratio is not None or completion_price_ratio is not None:
            price_type = "ratio"

        note_parts = [f"观测成本 ${effective_price:.4f}"]
        if official_price is not None:
            note_parts.append(f"官方价 ${official_price:.4f}")
        if group_ratio is not None:
            note_parts.append(f"分组倍率 {group_ratio:.2f}")
        group_name = str(item.get("group") or "").strip()
        if group_name:
            note_parts.append(f"分组 {group_name}")

        return {
            "model_id": model_id,
            "effective_price": effective_price,
            "official_price": official_price,
            "group_ratio": group_ratio,
            "price_ratio": price_ratio,
            "completion_price_ratio": completion_price_ratio,
            "price_source": "99hub_log",
            "price_type": price_type,
            "price_note": " / ".join(note_parts),
            "observed_group": group_name,
            "observed_at": datetime.fromtimestamp(int(item.get("created_at") or 0), tz=timezone.utc).strftime("%Y-%m-%d %H:%M:%S"),
            "observed_at_ts": int(item.get("created_at") or 0),
        }

    @staticmethod
    def _canonical_model_id(model_id: str) -> str:
        value = str(model_id or "").strip()
        lower = value.lower()
        if lower.startswith("runwayml-gen4_turbo"):
            return "gen4_turbo"
        return value

    @staticmethod
    def _extract_decimal(text: str, pattern: str) -> float | None:
        match = re.search(pattern, text or "", re.IGNORECASE)
        if match is None:
            return None
        try:
            return float(match.group(1))
        except (TypeError, ValueError):
            return None

    @staticmethod
    def _safe_positive_float(value: Any) -> float | None:
        try:
            parsed = float(value)
        except (TypeError, ValueError):
            return None
        if parsed <= 0:
            return None
        return parsed

    def _build_price_components(self, *, service_type: str, items: list[dict[str, Any]]) -> dict[str, float]:
        measured: list[tuple[str, float]] = []
        for item in items:
            model_id = self._canonical_model_id(str(item.get("model_id") or ""))
            value: float | None = None
            effective_price = self._safe_positive_float(item.get("effective_price"))
            price_ratio = self._safe_positive_float(item.get("price_ratio"))
            completion_ratio = self._safe_positive_float(item.get("completion_price_ratio"))

            if service_type == "video" and effective_price is not None:
                value = effective_price
            elif price_ratio is not None:
                value = max(price_ratio, completion_ratio or 0)
            elif effective_price is not None:
                value = effective_price

            if value is not None:
                measured.append((model_id, value))

        if not measured:
            return {}

        measured.sort(key=lambda item: (item[1], item[0]))
        if len(measured) == 1:
            return {measured[0][0]: 5.0}

        components: dict[str, float] = {}
        denominator = max(len(measured) - 1, 1)
        for index, (model_id, _) in enumerate(measured):
            components[model_id] = round(5 - (index * 4 / denominator), 2)
        return components

    @staticmethod
    def _is_speech_model(model_id: str, endpoint_types: list[str]) -> bool:
        text = ModelCatalogService._classifier_text(model_id, endpoint_types)
        if "tts" in text or "text-to-speech" in text:
            return False
        return any(
            token in text
            for token in ("audio-preview", "transcribe", "transcription", "whisper", "asr", "speech-to-text", "audio")
        )

    @staticmethod
    def _is_video_model(model_id: str, endpoint_types: list[str]) -> bool:
        text = ModelCatalogService._classifier_text(model_id, endpoint_types)
        return any(
            token in text
            for token in (
                "veo",
                "video",
                "kling",
                "wan",
                "vidu",
                "sora",
                "gen4",
                "runway",
                "luma",
                "hailuo",
                "seedance",
                "minimax",
                "pika",
                "i2v",
                "t2v",
                "image-to-video",
                "text-to-video",
                "reference-video",
            )
        )

    @staticmethod
    def _is_image_model(model_id: str, endpoint_types: list[str]) -> bool:
        lower = model_id.lower()
        text = ModelCatalogService._classifier_text(model_id, endpoint_types)
        if lower == "sora_image":
            return False
        if ModelCatalogService._looks_like_video_runtime_model(model_id, endpoint_types, ""):
            return False
        if any(token in text for token in ("audio-preview", "transcribe", "transcription", "whisper", "speech-to-text", "tts")):
            return False
        return any(
            token in text
            for token in (
                "gpt-image",
                "image-generation",
                "text-to-image",
                "image-to-image",
                "inpainting",
                "image",
                "flux",
                "dall",
                "recraft",
                "imagen",
                "stable-diffusion",
                "midjourney",
                "sdxl",
                "seedream",
                "seededit",
                "ideogram",
                "jimeng",
                "kontext",
                "nano-banana",
            )
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
    def _classifier_text(model_id: str, endpoint_types: list[str], owned_by: str = "") -> str:
        parts = [str(model_id or "").lower(), str(owned_by or "").lower()]
        parts.extend(str(item).lower() for item in endpoint_types)
        return " ".join(part for part in parts if part).strip()

    @staticmethod
    def _supports_speech_runtime(model_id: str, endpoint_types: list[str], owned_by: str) -> bool:
        text = ModelCatalogService._classifier_text(model_id, endpoint_types, owned_by)
        if "tts" in text or "text-to-speech" in text:
            return False
        return any(token in text for token in ("audio-preview", "transcribe", "transcription", "whisper", "asr"))

    @staticmethod
    def _supports_video_runtime(model_id: str, endpoint_types: list[str], owned_by: str) -> bool:
        return ModelCatalogService._video_runtime_family(model_id, endpoint_types, owned_by) in {
            "openai",
            "relay",
            "runway",
            "volc",
            "minimax",
            "replicate",
        }

    @staticmethod
    def _supports_video_image_input(model_id: str, endpoint_types: list[str], owned_by: str) -> bool:
        family = ModelCatalogService._video_runtime_family(model_id, endpoint_types, owned_by)
        if family == "unsupported":
            return False

        lower = model_id.lower()
        text = ModelCatalogService._classifier_text(model_id, endpoint_types, owned_by)
        if lower == "sora_image":
            return True
        if family in {"runway", "replicate"}:
            return True
        if any(token in text for token in ("components", "i2v", "image-to-video", "reference", "input_reference")):
            return True
        if family == "minimax":
            return any(token in text for token in ("hailuo-2.3", "video-01-live", "first_frame", "image"))
        if family == "volc":
            return any(token in text for token in ("i2v", "image", "reference"))
        return lower.startswith(("veo_", "veo3", "veo-"))

    @staticmethod
    def _video_runtime_family(model_id: str, endpoint_types: list[str], owned_by: str) -> str:
        lower = model_id.lower()
        text = ModelCatalogService._classifier_text(model_id, endpoint_types, owned_by)

        if lower.startswith(("veo3", "veo-", "veo3.", "veo3_")) or lower.startswith(("sora-2", "sora2-")):
            return "relay"

        if lower == "sora_image" or lower.startswith(("sora_", "sora2", "veo_")):
            return "openai"

        if "seedance" in text:
            return "volc"

        if lower.startswith("minimax/video-01"):
            return "replicate"

        if "hailuo" in text or (lower.startswith("minimax-") and "video-01" not in lower):
            return "minimax"

        if lower.startswith(("gen4", "gen-4")) or "runway" in text:
            return "runway"

        return "unsupported"

    @staticmethod
    def _looks_like_video_runtime_model(model_id: str, endpoint_types: list[str], owned_by: str) -> bool:
        return ModelCatalogService._supports_video_runtime(model_id, endpoint_types, owned_by)

    @staticmethod
    def _is_hub_base_url(base_url: str) -> bool:
        lower_base_url = str(base_url or "").strip().lower()
        return any(host in lower_base_url for host in ("api.99hub.top", "api3.wlai.vip", "api.apiplus.org", "zhongzhuan.chat"))

    @staticmethod
    def _estimate_levels(*, service_type: str, model_id: str) -> tuple[int, int, int]:
        lower = model_id.lower()
        price_level = 3
        speed_level = 3
        quality_level = 3
        if "lite" in lower:
            price_level = 2
            speed_level = max(speed_level, 4)
            quality_level = max(quality_level, 3)
        if "mini" in lower or "fast" in lower:
            price_level = 2
            speed_level = 5
        if "nano" in lower:
            price_level = 1
            speed_level = 5
            quality_level = 2
        if any(token in lower for token in ("flash", "turbo", "schnell", "instant")):
            price_level = min(price_level, 2)
            speed_level = max(speed_level, 5)
        if "4k" in lower or "max" in lower or "pro" in lower:
            price_level = 4
            quality_level = 5
        if any(token in lower for token in ("ultra", "opus")):
            price_level = 5
            quality_level = 5
        if "vip" in lower:
            price_level = max(price_level, 4)
            quality_level = max(quality_level, 4)
        if "preview" in lower:
            speed_level = max(speed_level, 4)
        if "haiku" in lower:
            price_level = min(price_level, 2)
            speed_level = max(speed_level, 5)
            quality_level = max(quality_level, 4)
        if "sonnet" in lower:
            price_level = max(price_level, 3)
            speed_level = max(speed_level, 4)
            quality_level = max(quality_level, 4)
        if service_type == "video" and "components" in lower:
            quality_level = 5
            speed_level = max(speed_level, 4)
        if service_type == "video" and lower == "veo3.1-fast":
            price_level = 2
            speed_level = 5
            quality_level = max(quality_level, 4)
        if service_type == "video" and lower == "veo3-fast-frames":
            price_level = 2
            speed_level = 5
            quality_level = max(quality_level, 4)
        if service_type == "video" and lower == "veo3.1-components":
            price_level = 3
            speed_level = max(speed_level, 4)
            quality_level = 5
        if service_type == "video" and lower == "veo_3_1-fast-components-4k":
            price_level = 2
            speed_level = 5
            quality_level = 5
        if service_type == "video" and lower == "veo_3_1":
            price_level = 3
            speed_level = max(speed_level, 4)
            quality_level = 5
        if service_type == "video" and "seedance" in lower and "lite" in lower:
            price_level = 3
            speed_level = 5
            quality_level = max(quality_level, 4)
        if service_type == "video" and lower.startswith(("gen4_turbo", "gen-4-turbo")):
            price_level = 4
            speed_level = 3
            quality_level = max(quality_level, 4)
        if service_type == "video" and "hailuo-02" in lower:
            price_level = 5
            speed_level = max(speed_level, 4)
            quality_level = max(quality_level, 4)
        if service_type == "video" and "hailuo-2.3" in lower:
            price_level = 5
            speed_level = max(speed_level, 4)
            quality_level = 5
        if service_type == "video" and "video-01-live" in lower:
            price_level = 4
            speed_level = max(speed_level, 4)
            quality_level = max(quality_level, 3)
        if service_type == "llm" and any(token in lower for token in ("reasoning", "reasoner", "thinking", "r1", "o1", "o3", "o4")):
            price_level = max(price_level, 4)
            speed_level = min(speed_level, 2)
            quality_level = 5
        if service_type == "speech" and any(token in lower for token in ("whisper", "transcribe", "audio-preview")):
            speed_level = max(speed_level, 4)
            quality_level = max(quality_level, 4)
        if service_type == "speech" and "mini" in lower:
            price_level = min(price_level, 2)
        if service_type == "image" and any(token in lower for token in ("image", "flux", "recraft", "seedream", "ideogram", "jimeng")):
            quality_level = max(quality_level, 4)
        if service_type == "image" and any(token in lower for token in ("ultra", "max", "pro", "hd")):
            price_level = max(price_level, 4)
            quality_level = 5
        if service_type == "image" and any(token in lower for token in ("flash", "schnell", "turbo", "fast", "dev")):
            price_level = min(price_level, 2)
            speed_level = max(speed_level, 5)
        return price_level, speed_level, quality_level

    @staticmethod
    def _score_model(
        *,
        service_type: str,
        prioritize: str,
        price_level: int,
        price_component: float | None,
        speed_level: int,
        quality_level: int,
        supports_video: bool,
        supports_image_input: bool,
    ) -> float:
        resolved_price_component = price_component if price_component is not None else 6 - price_level
        if prioritize == "cheap":
            base = resolved_price_component * 0.45 + speed_level * 0.3 + quality_level * 0.25
        elif prioritize == "fast":
            base = speed_level * 0.45 + resolved_price_component * 0.25 + quality_level * 0.3
        elif prioritize == "quality":
            base = quality_level * 0.5 + speed_level * 0.2 + resolved_price_component * 0.3
        else:
            base = quality_level * 0.38 + speed_level * 0.34 + resolved_price_component * 0.28
        if service_type == "video" and prioritize == "cheap" and price_component is None:
            base -= 0.4
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
