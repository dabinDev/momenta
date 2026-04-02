from __future__ import annotations

from typing import Any

import httpx

from app.models.app_config import UserAppConfig


class LLMGatewayError(Exception):
    pass


class OpenAICompatibleLLMService:
    @staticmethod
    def is_configured(config: UserAppConfig) -> bool:
        return bool(
            (config.llm_base_url or "").strip()
            and (config.llm_api_key or "").strip()
            and (config.llm_model or "").strip()
        )

    async def correct_text(self, *, config: UserAppConfig, text: str) -> dict[str, str]:
        result = await self._chat(
            config=config,
            system_prompt=(
                "你是中文输入纠错助手。"
                "请修正用户文本中的错别字、同音字、缺字漏字、标点问题和明显的语义识别错误。"
                "保持原意，不要扩写，不要解释，只输出修正后的正文。"
            ),
            user_prompt=text,
            temperature=0.2,
        )
        return {"text": result}

    async def polish_text(self, *, config: UserAppConfig, text: str) -> dict[str, str]:
        result = await self._chat(
            config=config,
            system_prompt=(
                "你是资深中文短视频文案编辑。"
                "请在不改变核心意思的前提下，将用户输入润色成更自然、更适合中老年用户表达的中文文案。"
                "只输出润色后的正文，不要添加解释、标题或引号。"
            ),
            user_prompt=text,
            temperature=0.4,
        )
        return {"text": result}

    async def generate_prompt(
        self,
        *,
        config: UserAppConfig,
        text: str,
        prompt_template_instruction: str,
    ) -> dict[str, str]:
        result = await self._chat(
            config=config,
            system_prompt=prompt_template_instruction,
            user_prompt=text,
            temperature=0.5,
        )
        return {"prompt": result}

    async def _chat(
        self,
        *,
        config: UserAppConfig,
        system_prompt: str,
        user_prompt: str,
        temperature: float,
    ) -> str:
        base_url = (config.llm_base_url or "").rstrip("/")
        timeout = httpx.Timeout(connect=20.0, read=120.0, write=120.0, pool=20.0)

        payload = {
            "model": config.llm_model,
            "temperature": temperature,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
        }

        async with httpx.AsyncClient(base_url=base_url, timeout=timeout, follow_redirects=True) as client:
            try:
                response = await client.post(
                    "/chat/completions",
                    headers={
                        "Authorization": f"Bearer {config.llm_api_key}",
                        "Content-Type": "application/json",
                    },
                    json=payload,
                )
                response.raise_for_status()
            except httpx.HTTPStatusError as exc:
                raise LLMGatewayError(self._read_error_detail(exc.response)) from exc
            except httpx.HTTPError as exc:
                raise LLMGatewayError("Failed to reach configured LLM service") from exc

        try:
            data = response.json()
        except ValueError as exc:
            raise LLMGatewayError("Configured LLM service returned invalid JSON") from exc

        text = self._extract_text(data)
        if not text:
            raise LLMGatewayError("Configured LLM service returned empty content")
        return text

    @staticmethod
    def _extract_text(payload: dict[str, Any]) -> str:
        choices = payload.get("choices") or []
        if not isinstance(choices, list) or not choices:
            return ""

        message = choices[0].get("message") if isinstance(choices[0], dict) else None
        if not isinstance(message, dict):
            return ""

        content = message.get("content")
        if isinstance(content, str):
            return content.strip()
        if isinstance(content, list):
            fragments = []
            for item in content:
                if isinstance(item, dict) and item.get("type") == "text" and item.get("text"):
                    fragments.append(str(item["text"]))
            return "".join(fragments).strip()
        return ""

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
        return f"Configured LLM service request failed with status {response.status_code}"


llm_gateway_service = OpenAICompatibleLLMService()
