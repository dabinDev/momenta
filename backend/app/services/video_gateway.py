from __future__ import annotations

from typing import Any
from urllib.parse import urlparse

import httpx

from app.models.app_config import UserAppConfig
from app.services.local_media import local_media_service


class VideoGatewayError(Exception):
    pass


class HybridVideoService:
    relay_provider = "relay_video"
    openai_provider = "openai_compatible"
    runway_provider = "runway_video"
    volc_provider = "volc_video"
    minimax_provider = "minimax_video"
    replicate_provider = "replicate_video"

    @staticmethod
    def _request_timeout() -> httpx.Timeout:
        return httpx.Timeout(connect=20.0, read=240.0, write=240.0, pool=20.0)

    @staticmethod
    def _status_timeout() -> httpx.Timeout:
        return httpx.Timeout(connect=5.0, read=12.0, write=12.0, pool=5.0)

    @staticmethod
    def is_configured(config: UserAppConfig) -> bool:
        return bool(
            (config.video_base_url or "").strip()
            and (config.video_api_key or "").strip()
            and (config.video_model or "").strip()
        )

    def provider_name(self, config: UserAppConfig) -> str:
        return self._provider_kind(config)

    @classmethod
    def supported_provider_kinds(cls) -> set[str]:
        return {
            cls.relay_provider,
            cls.openai_provider,
            cls.runway_provider,
            cls.volc_provider,
            cls.minimax_provider,
            cls.replicate_provider,
        }

    @classmethod
    def remote_url_provider_kinds(cls) -> set[str]:
        return {
            cls.relay_provider,
            cls.runway_provider,
            cls.volc_provider,
            cls.minimax_provider,
            cls.replicate_provider,
        }

    async def create_video(
        self,
        *,
        config: UserAppConfig,
        prompt: str,
        images: list[str],
        duration: int,
        size: str = "720x1280",
    ) -> dict[str, Any]:
        provider_kind = self._provider_kind(config)
        if provider_kind == self.relay_provider:
            return await self._create_relay_video(
                config=config,
                prompt=prompt,
                images=images,
                size=size,
            )
        if provider_kind == self.runway_provider:
            return await self._create_runway_video(
                config=config,
                prompt=prompt,
                images=images,
                duration=duration,
                size=size,
            )
        if provider_kind == self.volc_provider:
            return await self._create_volc_video(
                config=config,
                prompt=prompt,
                images=images,
                duration=duration,
                size=size,
            )
        if provider_kind == self.minimax_provider:
            return await self._create_minimax_video_generation(
                config=config,
                prompt=prompt,
                images=images,
                duration=duration,
                size=size,
            )
        if provider_kind == self.replicate_provider:
            return await self._create_replicate_video(
                config=config,
                prompt=prompt,
                images=images,
            )
        return await self._create_openai_compatible_video(
            config=config,
            prompt=prompt,
            images=images,
            duration=duration,
            size=size,
        )

    async def get_video_status(
        self,
        *,
        config: UserAppConfig,
        provider_kind: str,
        provider_task_id: str,
        task_id: int,
    ) -> dict[str, Any]:
        if provider_kind == self.relay_provider:
            return await self._get_relay_video_status(
                config=config,
                provider_task_id=provider_task_id,
                task_id=task_id,
            )
        if provider_kind == self.runway_provider:
            return await self._get_runway_video_status(
                config=config,
                provider_task_id=provider_task_id,
            )
        if provider_kind == self.volc_provider:
            return await self._get_volc_video_status(
                config=config,
                provider_task_id=provider_task_id,
            )
        if provider_kind == self.minimax_provider:
            return await self._get_minimax_video_generation_status(
                config=config,
                provider_task_id=provider_task_id,
            )
        if provider_kind == self.replicate_provider:
            return await self._get_replicate_video_status(
                config=config,
                provider_task_id=provider_task_id,
            )
        return await self._get_openai_compatible_video_status(
            config=config,
            provider_task_id=provider_task_id,
            task_id=task_id,
        )

    async def ensure_task_video_storage(
        self,
        *,
        config: UserAppConfig,
        provider_kind: str,
        provider_task_id: str,
        task_id: int,
        file_name: str | None = None,
        source_video_url: str = "",
    ) -> dict[str, str]:
        if provider_kind in self.remote_url_provider_kinds():
            return await self._ensure_remote_provider_video_storage(
                config=config,
                provider_kind=provider_kind,
                provider_task_id=provider_task_id,
                task_id=task_id,
                file_name=file_name,
                source_video_url=source_video_url,
            )

        locations = await local_media_service.ensure_video_storage(
            task_id=task_id,
            provider_task_id=provider_task_id,
            file_name=file_name,
            content_fetcher=lambda video_id: self._download_openai_compatible_video_content(
                config=config,
                provider_task_id=video_id,
            ),
        )
        locations["source_video_url"] = str(source_video_url or "").strip()
        return locations

    async def _ensure_remote_provider_video_storage(
        self,
        *,
        config: UserAppConfig,
        provider_kind: str,
        provider_task_id: str,
        task_id: int,
        file_name: str | None,
        source_video_url: str,
    ) -> dict[str, str]:
        remote_video_url = str(source_video_url or "").strip()
        if not remote_video_url:
            payload = await self.get_video_status(
                config=config,
                provider_kind=provider_kind,
                provider_task_id=provider_task_id,
                task_id=task_id,
            )
            remote_video_url = self._extract_remote_video_url(
                provider_kind=provider_kind,
                payload=payload,
            )
        if not remote_video_url:
            raise VideoGatewayError("Upstream video result is not available yet")

        locations = await local_media_service.ensure_video_storage(
            task_id=task_id,
            provider_task_id=provider_task_id,
            file_name=file_name,
            content_fetcher=lambda _: self._download_remote_video(remote_video_url),
        )
        locations["source_video_url"] = remote_video_url
        return locations

    async def _create_relay_video(
        self,
        *,
        config: UserAppConfig,
        prompt: str,
        images: list[str],
        size: str,
    ) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "model": config.video_model,
            "prompt": prompt,
            "enhance_prompt": False,
            "enable_upsample": True,
            "aspect_ratio": self._size_to_aspect_ratio(size),
        }
        if images:
            payload["images"] = [
                await local_media_service.ensure_public_image_url(image)
                for image in images
                if image
            ]

        data = await self._post_json(
            config=config,
            path="/v1/video/create",
            payload=payload,
        )
        data.setdefault("status", "pending")
        data.setdefault("progress", 0)
        return data

    async def _create_runway_video(
        self,
        *,
        config: UserAppConfig,
        prompt: str,
        images: list[str],
        duration: int,
        size: str,
    ) -> dict[str, Any]:
        if not images:
            raise VideoGatewayError("Current video model requires at least one reference image")

        payload = {
            "promptImage": await local_media_service.ensure_public_image_url(images[0]),
            "model": config.video_model,
            "promptText": prompt,
            "watermark": False,
            "duration": max(5, int(duration or 5)),
            "ratio": self._size_to_runway_ratio(size),
        }
        return await self._post_json(
            config=config,
            path="/runwayml/v1/image_to_video",
            payload=payload,
        )

    async def _create_volc_video(
        self,
        *,
        config: UserAppConfig,
        prompt: str,
        images: list[str],
        duration: int,
        size: str,
    ) -> dict[str, Any]:
        if not images:
            raise VideoGatewayError("Current video model requires at least one reference image")

        payload = {
            "model": config.video_model,
            "content": [
                {
                    "type": "text",
                    "text": self._compose_volc_prompt(
                        prompt=prompt,
                        duration=duration,
                        size=size,
                    ),
                },
                {
                    "type": "image_url",
                    "image_url": {
                        "url": await local_media_service.ensure_public_image_url(images[0]),
                    },
                },
            ],
        }
        return await self._post_json(
            config=config,
            path="/volc/v1/contents/generations/tasks",
            payload=payload,
        )

    async def _create_minimax_video_generation(
        self,
        *,
        config: UserAppConfig,
        prompt: str,
        images: list[str],
        duration: int,
        size: str,
    ) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "model": config.video_model,
            "prompt": prompt,
            "duration": max(10, int(duration or 10)),
        }
        if images:
            payload["first_frame_image"] = await local_media_service.ensure_public_image_url(images[0])
            payload["resolution"] = self._size_to_minimax_resolution(size)
            payload["prompt_optimizer"] = False

        return await self._post_json(
            config=config,
            path="/minimax/v1/video_generation",
            payload=payload,
        )

    async def _create_replicate_video(
        self,
        *,
        config: UserAppConfig,
        prompt: str,
        images: list[str],
    ) -> dict[str, Any]:
        input_payload: dict[str, Any] = {
            "prompt": prompt,
            "prompt_optimizer": False,
        }
        if images:
            input_payload["first_frame_image"] = await local_media_service.ensure_public_image_url(images[0])

        return await self._post_json(
            config=config,
            path=f"/replicate/v1/models/{config.video_model}/predictions",
            payload={"input": input_payload},
        )

    async def _get_relay_video_status(
        self,
        *,
        config: UserAppConfig,
        provider_task_id: str,
        task_id: int,
    ) -> dict[str, Any]:
        payload = await self._query_relay_video_status(
            config=config,
            provider_task_id=provider_task_id,
        )
        data = self._payload_data(payload)
        status = str(data.get("status") or "").lower()
        remote_video_url = str(data.get("video_url") or data.get("videoUrl") or "").strip()

        if status in {"completed", "succeeded", "success"} and remote_video_url:
            data["provider_video_url"] = remote_video_url
            data["video_url"] = remote_video_url
            data["progress"] = 1
        elif status in {"processing", "running", "in_progress"}:
            data.setdefault("progress", 0.5)
        else:
            data.setdefault("progress", 0)

        return payload

    async def _get_runway_video_status(
        self,
        *,
        config: UserAppConfig,
        provider_task_id: str,
    ) -> dict[str, Any]:
        payload = await self._get_json(
            config=config,
            path=f"/runwayml/v1/tasks/{provider_task_id}",
        )
        data = self._payload_data(payload)
        status = str(data.get("status") or "").lower()
        output = data.get("output")
        video_url = ""
        if isinstance(output, list) and output:
            video_url = str(output[0] or "").strip()
        elif isinstance(output, str):
            video_url = output.strip()

        if status in {"succeeded", "success", "completed"} and video_url:
            data["video_url"] = video_url
            data["provider_video_url"] = video_url
            data["progress"] = 1
        elif status in {"starting", "pending", "queued", "submitted"}:
            data["progress"] = 0
        elif status in {"running", "processing"}:
            data["progress"] = 0.5
        else:
            data.setdefault("progress", 0)
        return payload

    async def _get_volc_video_status(
        self,
        *,
        config: UserAppConfig,
        provider_task_id: str,
    ) -> dict[str, Any]:
        payload = await self._get_json(
            config=config,
            path=f"/volc/v1/contents/generations/tasks/{provider_task_id}",
        )
        data = self._payload_data(payload)
        status = str(data.get("status") or "").lower()
        content = data.get("content")
        video_url = ""
        if isinstance(content, dict):
            video_url = str(content.get("video_url") or "").strip()

        if status in {"succeeded", "success", "completed"} and video_url:
            data["video_url"] = video_url
            data["provider_video_url"] = video_url
            data["progress"] = 1
        elif status in {"submitted", "pending", "queued"}:
            data["progress"] = 0
        elif status in {"running", "processing"}:
            data["progress"] = 0.5
        else:
            data.setdefault("progress", 0)

        error = data.get("error")
        if isinstance(error, dict) and error.get("message"):
            data["error_message"] = str(error["message"])
        return payload

    async def _get_minimax_video_generation_status(
        self,
        *,
        config: UserAppConfig,
        provider_task_id: str,
    ) -> dict[str, Any]:
        payload = await self._get_json(
            config=config,
            path="/minimax/v1/query/video_generation",
            params={"task_id": provider_task_id},
        )
        top_level = payload if isinstance(payload, dict) else {}
        data = self._payload_data(top_level)
        status = str(top_level.get("status") or data.get("status") or "").lower()

        file_info = data.get("file")
        video_url = ""
        if isinstance(file_info, dict):
            video_url = str(file_info.get("download_url") or file_info.get("backup_download_url") or "").strip()

        if status in {"success", "succeeded", "completed"} and video_url:
            data["video_url"] = video_url
            data["provider_video_url"] = video_url
            data["progress"] = 1
        elif status in {"preparing", "queueing", "queued", "pending", "submitted"}:
            data["progress"] = self._coerce_progress(top_level.get("progress"), default=0)
        elif status in {"processing", "running"}:
            data["progress"] = self._coerce_progress(top_level.get("progress"), default=0.5)
        else:
            data["progress"] = self._coerce_progress(top_level.get("progress"), default=0)

        if top_level.get("error"):
            data["error_message"] = str(top_level["error"])
        return payload

    async def _get_replicate_video_status(
        self,
        *,
        config: UserAppConfig,
        provider_task_id: str,
    ) -> dict[str, Any]:
        payload = await self._get_json(
            config=config,
            path=f"/replicate/v1/predictions/{provider_task_id}",
        )
        data = self._payload_data(payload)
        status = str(data.get("status") or "").lower()
        output = data.get("output")
        video_url = ""
        if isinstance(output, list) and output:
            video_url = str(output[0] or "").strip()
        elif isinstance(output, str):
            video_url = output.strip()

        if status in {"succeeded", "success", "completed"} and video_url:
            data["video_url"] = video_url
            data["provider_video_url"] = video_url
            data["progress"] = 1
        elif status in {"starting", "pending", "queued"}:
            data["progress"] = 0
        elif status in {"processing", "running"}:
            data["progress"] = 0.5
        else:
            data.setdefault("progress", 0)

        if data.get("error"):
            data["error_message"] = str(data["error"])
        return payload

    async def _download_remote_video(self, url: str) -> bytes:
        timeout = self._request_timeout()
        async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
            try:
                response = await client.get(url)
                response.raise_for_status()
            except httpx.HTTPStatusError as exc:
                raise VideoGatewayError(self._read_error_detail(exc.response)) from exc
            except httpx.HTTPError as exc:
                raise VideoGatewayError("Failed to download configured video content") from exc
        return response.content

    async def _create_openai_compatible_video(
        self,
        *,
        config: UserAppConfig,
        prompt: str,
        images: list[str],
        duration: int,
        size: str,
    ) -> dict[str, Any]:
        base_url = (config.video_base_url or "").strip().rstrip("/")
        timeout = self._request_timeout()

        async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
            try:
                if images:
                    response = await self._create_with_reference_image(
                        client=client,
                        config=config,
                        prompt=prompt,
                        duration=duration,
                        size=size,
                        image_location=images[0],
                    )
                else:
                    response = await client.post(
                        self._build_url(base_url, "/v1/videos"),
                        headers=self._headers(config),
                        files=[
                            ("model", (None, config.video_model)),
                            ("prompt", (None, prompt)),
                            ("seconds", (None, str(duration))),
                            ("size", (None, size)),
                            ("watermark", (None, "false")),
                        ],
                    )
                response.raise_for_status()
            except httpx.HTTPStatusError as exc:
                raise VideoGatewayError(self._read_error_detail(exc.response)) from exc
            except httpx.HTTPError as exc:
                raise VideoGatewayError("Failed to reach configured video service") from exc

        try:
            return response.json()
        except ValueError as exc:
            raise VideoGatewayError("Configured video service returned invalid JSON") from exc

    async def _get_openai_compatible_video_status(
        self,
        *,
        config: UserAppConfig,
        provider_task_id: str,
        task_id: int,
    ) -> dict[str, Any]:
        payload = await self._get_json(
            config=config,
            path=f"/v1/videos/{provider_task_id}",
        )
        data = self._payload_data(payload)
        status = str(data.get("status") or "").lower()
        if status in {"completed", "succeeded", "success"}:
            data["progress"] = 1
        elif status in {"processing", "running", "in_progress"}:
            data.setdefault("progress", 0.5)
        else:
            data.setdefault("progress", 0)
        return payload

    async def _query_relay_video_status(
        self,
        *,
        config: UserAppConfig,
        provider_task_id: str,
    ) -> dict[str, Any]:
        return await self._get_json(
            config=config,
            path="/v1/video/query",
            params={"id": provider_task_id},
        )

    async def _get_json(
        self,
        *,
        config: UserAppConfig,
        path: str,
        params: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        base_url = (config.video_base_url or "").strip().rstrip("/")
        timeout = self._status_timeout()

        async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
            try:
                response = await client.get(
                    self._build_url(base_url, path),
                    headers=self._headers(config),
                    params=params,
                )
                response.raise_for_status()
            except httpx.HTTPStatusError as exc:
                raise VideoGatewayError(self._read_error_detail(exc.response)) from exc
            except httpx.HTTPError as exc:
                raise VideoGatewayError("Failed to reach configured video service") from exc

        try:
            payload = response.json()
        except ValueError as exc:
            raise VideoGatewayError("Configured video service returned invalid JSON") from exc
        return payload if isinstance(payload, dict) else {"data": payload}

    async def _post_json(
        self,
        *,
        config: UserAppConfig,
        path: str,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        base_url = (config.video_base_url or "").strip().rstrip("/")
        timeout = self._request_timeout()

        async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
            try:
                response = await client.post(
                    self._build_url(base_url, path),
                    headers=self._headers(config),
                    json=payload,
                )
                response.raise_for_status()
            except httpx.HTTPStatusError as exc:
                raise VideoGatewayError(self._read_error_detail(exc.response)) from exc
            except httpx.HTTPError as exc:
                raise VideoGatewayError("Failed to reach configured video service") from exc

        try:
            data = response.json()
        except ValueError as exc:
            raise VideoGatewayError("Configured video service returned invalid JSON") from exc
        return data if isinstance(data, dict) else {"data": data}

    async def _download_openai_compatible_video_content(
        self,
        *,
        config: UserAppConfig,
        provider_task_id: str,
    ) -> bytes:
        base_url = (config.video_base_url or "").strip().rstrip("/")
        timeout = self._request_timeout()

        async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
            try:
                response = await client.get(
                    self._build_url(base_url, f"/v1/videos/{provider_task_id}/content"),
                    headers=self._headers(config),
                )
                response.raise_for_status()
            except httpx.HTTPStatusError as exc:
                raise VideoGatewayError(self._read_error_detail(exc.response)) from exc
            except httpx.HTTPError as exc:
                raise VideoGatewayError("Failed to download configured video content") from exc

        return response.content

    async def _create_with_reference_image(
        self,
        *,
        client: httpx.AsyncClient,
        config: UserAppConfig,
        prompt: str,
        duration: int,
        size: str,
        image_location: str,
    ) -> httpx.Response:
        base_url = (config.video_base_url or "").strip().rstrip("/")
        image_name, image_bytes, content_type = await local_media_service.read_remote_bytes(image_location)
        files = [
            ("model", (None, config.video_model)),
            ("prompt", (None, prompt)),
            ("seconds", (None, str(duration))),
            ("size", (None, size)),
            ("watermark", (None, "false")),
            ("input_reference", (image_name, image_bytes, content_type)),
        ]
        return await client.post(
            self._build_url(base_url, "/v1/videos"),
            headers=self._headers(config),
            files=files,
        )

    @classmethod
    def _provider_kind(cls, config: UserAppConfig) -> str:
        base_url = (config.video_base_url or "").strip()
        model = (config.video_model or "").strip()
        lower_model = model.lower()
        lower_base_url = base_url.lower()

        if lower_model.startswith(("veo3", "veo-", "veo3.", "veo3_")) or lower_model.startswith(("sora-2", "sora2-")):
            return cls.relay_provider
        if "seedance" in lower_model:
            return cls.volc_provider
        if lower_model.startswith("minimax/video-01"):
            return cls.replicate_provider
        if "hailuo" in lower_model or lower_model.startswith("minimax-"):
            return cls.minimax_provider
        if lower_model.startswith(("gen4", "gen-4")) or "runway" in lower_model:
            return cls.runway_provider
        if lower_model == "sora_image" or lower_model.startswith(("sora_", "sora2", "veo_")):
            return cls.openai_provider
        if cls._is_hub_video_host(lower_base_url):
            raise VideoGatewayError(
                "Current 99hub video model is not wired into the runtime gateway yet. Supported families: veo_/sora, veo3, Doubao Seedance, Hailuo, Runway, minimax/video-01-live."
            )
        return cls.openai_provider

    @staticmethod
    def _extract_remote_video_url(*, provider_kind: str, payload: dict[str, Any]) -> str:
        data = HybridVideoService._payload_data(payload)
        if provider_kind == HybridVideoService.volc_provider:
            content = data.get("content")
            if isinstance(content, dict):
                return str(content.get("video_url") or "").strip()
        if provider_kind == HybridVideoService.minimax_provider:
            file_info = data.get("file")
            if isinstance(file_info, dict):
                return str(file_info.get("download_url") or file_info.get("backup_download_url") or "").strip()
        if provider_kind in {HybridVideoService.runway_provider, HybridVideoService.replicate_provider}:
            output = data.get("output")
            if isinstance(output, list) and output:
                return str(output[0] or "").strip()
            if isinstance(output, str):
                return output.strip()
        return str(data.get("video_url") or data.get("videoUrl") or "").strip()

    @staticmethod
    def _is_hub_video_host(base_url: str) -> bool:
        return any(host in base_url for host in ("api.99hub.top", "api3.wlai.vip", "api.apiplus.org", "zhongzhuan.chat"))

    @staticmethod
    def _build_url(base_url: str, versioned_path: str) -> str:
        normalized_base_url = base_url.rstrip("/")
        parsed = urlparse(normalized_base_url)
        if parsed.path.rstrip("/").endswith("/v1") and versioned_path.startswith("/v1/"):
            return f"{normalized_base_url}{versioned_path.removeprefix('/v1')}"
        return f"{normalized_base_url}{versioned_path}"

    @staticmethod
    def _payload_data(payload: dict[str, Any]) -> dict[str, Any]:
        data = payload.get("data")
        if isinstance(data, dict):
            return data
        return payload

    @staticmethod
    def _headers(config: UserAppConfig) -> dict[str, str]:
        return {
            "Accept": "application/json",
            "Authorization": f"Bearer {config.video_api_key}",
        }

    @staticmethod
    def _compose_volc_prompt(*, prompt: str, duration: int, size: str) -> str:
        aspect_ratio = HybridVideoService._size_to_aspect_ratio(size)
        resolution = HybridVideoService._size_to_volc_resolution(size)
        controls = (
            f"--rs {resolution} --rt {aspect_ratio} --ratio {aspect_ratio} "
            f"--dur {max(5, int(duration or 5))} --fps 24 --wm false --cf false"
        )
        return f"{(prompt or '').strip()} {controls}".strip()

    @staticmethod
    def _size_to_runway_ratio(size: str) -> str:
        normalized = (size or "").lower().replace(" ", "")
        if "x" not in normalized:
            return "720:1280"
        return normalized.replace("x", ":")

    @staticmethod
    def _size_to_volc_resolution(size: str) -> str:
        normalized = (size or "").lower().replace(" ", "")
        if "x" not in normalized:
            return "720p"

        width_text, height_text = normalized.split("x", 1)
        try:
            width = int(width_text)
            height = int(height_text)
        except ValueError:
            return "720p"

        if min(width, height) >= 1080:
            return "1080p"
        return "720p"

    @staticmethod
    def _size_to_minimax_resolution(size: str) -> str:
        normalized = (size or "").lower().replace(" ", "")
        if "x" not in normalized:
            return "768P"

        width_text, height_text = normalized.split("x", 1)
        try:
            width = int(width_text)
            height = int(height_text)
        except ValueError:
            return "768P"

        short_side = min(width, height)
        if short_side >= 1080:
            return "1080P"
        if short_side >= 768:
            return "768P"
        return "720P"

    @staticmethod
    def _size_to_aspect_ratio(size: str) -> str:
        normalized = (size or "").lower().replace(" ", "")
        if "x" not in normalized:
            return "9:16"

        width_text, height_text = normalized.split("x", 1)
        try:
            width = int(width_text)
            height = int(height_text)
        except ValueError:
            return "9:16"

        if width == height:
            return "1:1"
        if width > height:
            return "16:9"
        return "9:16"

    @staticmethod
    def _coerce_progress(value: Any, *, default: float = 0) -> float:
        if value in (None, ""):
            return max(0, min(default, 1))
        text = str(value).strip()
        if text.endswith("%"):
            text = text[:-1]
        try:
            progress = float(text)
        except (TypeError, ValueError):
            return max(0, min(default, 1))
        if progress > 1:
            progress = progress / 100
        return max(0, min(progress, 1))

    @staticmethod
    def _read_error_detail(response: httpx.Response) -> str:
        try:
            payload = response.json()
        except ValueError:
            payload = response.text

        if isinstance(payload, dict):
            error = payload.get("error")
            if isinstance(error, dict):
                for key in ("message", "detail", "code"):
                    if error.get(key):
                        return str(error[key])
            for key in ("message", "detail", "error"):
                if payload.get(key):
                    return str(payload[key])
        if isinstance(payload, str) and payload.strip():
            return payload.strip()
        return f"Configured video service request failed with status {response.status_code}"


video_gateway_service = HybridVideoService()
