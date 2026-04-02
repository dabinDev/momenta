from __future__ import annotations

import base64
import io
import wave
from dataclasses import dataclass
from typing import Any
from urllib.parse import urlparse

import httpx

from app.models.app_config import UserAppConfig


class SpeechRecognitionError(Exception):
    """Base exception for user-facing speech recognition errors."""


class SpeechInputError(SpeechRecognitionError):
    """Raised for invalid or unsupported input audio."""


class SpeechConfigError(SpeechRecognitionError):
    """Raised when the speech service is not configured."""


class SpeechProviderError(SpeechRecognitionError):
    """Raised when the upstream speech provider is unavailable."""


@dataclass(frozen=True)
class NormalizedAudio:
    payload: bytes
    sample_rate: int
    channels: int
    bit_depth: int
    encoding: str
    audio_format: str
    duration_seconds: float

    def to_wav_bytes(self) -> bytes:
        buffer = io.BytesIO()
        with wave.open(buffer, "wb") as wav_file:
            wav_file.setnchannels(self.channels)
            wav_file.setsampwidth(self.bit_depth // 8)
            wav_file.setframerate(self.sample_rate)
            wav_file.writeframes(self.payload)
        return buffer.getvalue()


@dataclass(frozen=True)
class SpeechTranscriptionResult:
    text: str
    duration_seconds: float
    audio_format: str
    provider: str
    model: str
    language: str
    accent: str


class SpeechRecognitionService:
    default_language = "zh"
    default_accent = "standard"

    @staticmethod
    def is_configured(config: UserAppConfig) -> bool:
        return bool(
            (config.speech_base_url or "").strip()
            and (config.speech_api_key or "").strip()
            and (config.speech_model or "").strip()
        )

    def provider_name(self, config: UserAppConfig | None = None) -> str:
        base_url = (config.speech_base_url or "").lower() if config else ""
        if any(host in base_url for host in ("api.99hub.top", "api3.wlai.vip", "api.apiplus.org", "zhongzhuan.chat")):
            return "hub_relay"
        return "openai_compatible"

    async def transcribe_upload(
        self,
        *,
        config: UserAppConfig,
        filename: str,
        content: bytes,
    ) -> SpeechTranscriptionResult:
        if not self.is_configured(config):
            raise SpeechConfigError("语音识别服务尚未配置，请联系管理员")
        if not content:
            raise SpeechInputError("上传的语音文件为空")

        audio = self._normalize_audio(filename=filename, content=content)
        text, used_model = await self._transcribe(config=config, audio=audio)
        return SpeechTranscriptionResult(
            text=text,
            duration_seconds=audio.duration_seconds,
            audio_format=audio.audio_format,
            provider=self.provider_name(config),
            model=used_model,
            language=self.default_language,
            accent=self.default_accent,
        )

    async def _transcribe(
        self,
        *,
        config: UserAppConfig,
        audio: NormalizedAudio,
    ) -> tuple[str, str]:
        model = (config.speech_model or "").strip()
        if self._prefers_chat_audio(model):
            try:
                text = await self._transcribe_with_chat_audio(
                    config=config,
                    audio=audio,
                    model=model,
                    include_audio_output=False,
                )
                return text, model
            except SpeechProviderError:
                try:
                    text = await self._transcribe_with_chat_audio(
                        config=config,
                        audio=audio,
                        model=model,
                        include_audio_output=True,
                    )
                    return text, model
                except SpeechProviderError:
                    fallback_model = self._fallback_transcription_model(model)
                    if fallback_model:
                        text = await self._transcribe_with_transcriptions(
                            config=config,
                            audio=audio,
                            model=fallback_model,
                        )
                        return text, fallback_model
                    raise

        text = await self._transcribe_with_transcriptions(config=config, audio=audio, model=model)
        return text, model

    def _normalize_audio(self, *, filename: str, content: bytes) -> NormalizedAudio:
        lower_name = filename.lower()
        if lower_name.endswith(".wav") or content.startswith(b"RIFF"):
            return self._read_wav(content)
        if lower_name.endswith(".pcm"):
            return self._read_pcm(content)
        raise SpeechInputError("仅支持 .pcm 或 .wav 语音文件")

    def _read_pcm(self, content: bytes) -> NormalizedAudio:
        if len(content) % 2 != 0:
            raise SpeechInputError("PCM 音频数据格式不正确")

        sample_rate = 16000
        duration_seconds = len(content) / float(sample_rate * 2)
        self._validate_duration(duration_seconds)

        return NormalizedAudio(
            payload=content,
            sample_rate=sample_rate,
            channels=1,
            bit_depth=16,
            encoding="raw",
            audio_format="pcm",
            duration_seconds=duration_seconds,
        )

    def _read_wav(self, content: bytes) -> NormalizedAudio:
        try:
            with wave.open(io.BytesIO(content), "rb") as wav_file:
                channels = wav_file.getnchannels()
                sample_rate = wav_file.getframerate()
                bit_depth = wav_file.getsampwidth() * 8
                frame_count = wav_file.getnframes()
                pcm_payload = wav_file.readframes(frame_count)
        except wave.Error as exc:
            raise SpeechInputError("WAV 音频解析失败") from exc

        if channels != 1:
            raise SpeechInputError("仅支持单声道语音")
        if bit_depth != 16:
            raise SpeechInputError("仅支持 16 位深度音频")
        if sample_rate not in {8000, 16000}:
            raise SpeechInputError("仅支持 8k 或 16k 采样率音频")

        duration_seconds = frame_count / float(sample_rate)
        self._validate_duration(duration_seconds)

        return NormalizedAudio(
            payload=pcm_payload,
            sample_rate=sample_rate,
            channels=channels,
            bit_depth=bit_depth,
            encoding="raw",
            audio_format="wav",
            duration_seconds=duration_seconds,
        )

    @staticmethod
    def _validate_duration(duration_seconds: float) -> None:
        if duration_seconds <= 0:
            raise SpeechInputError("语音时长无效")
        if duration_seconds > 60:
            raise SpeechInputError("当前仅支持 60 秒以内的语音消息")

    async def _transcribe_with_transcriptions(
        self,
        *,
        config: UserAppConfig,
        audio: NormalizedAudio,
        model: str,
    ) -> str:
        base_url = (config.speech_base_url or "").strip().rstrip("/")
        timeout = httpx.Timeout(connect=20.0, read=180.0, write=180.0, pool=20.0)
        wav_bytes = audio.to_wav_bytes()

        files = [
            ("file", ("speech.wav", wav_bytes, "audio/wav")),
            ("model", (None, model)),
            ("language", (None, self.default_language)),
            ("response_format", (None, "json")),
        ]

        async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
            try:
                response = await client.post(
                    self._build_url(base_url, "/v1/audio/transcriptions"),
                    headers={"Authorization": f"Bearer {config.speech_api_key}"},
                    files=files,
                )
                response.raise_for_status()
            except httpx.HTTPStatusError as exc:
                raise SpeechProviderError(self._read_error_detail(exc.response)) from exc
            except httpx.HTTPError as exc:
                raise SpeechProviderError("语音识别服务暂时不可用，请稍后重试") from exc

        try:
            payload = response.json()
        except ValueError as exc:
            raise SpeechProviderError("语音识别服务返回了无效响应") from exc

        data = self._payload_data(payload)
        text = str(data.get("text") or "").strip()
        if not text:
            raise SpeechInputError("未识别到清晰语音，请重试")
        return text

    async def _transcribe_with_chat_audio(
        self,
        *,
        config: UserAppConfig,
        audio: NormalizedAudio,
        model: str,
        include_audio_output: bool,
    ) -> str:
        base_url = (config.speech_base_url or "").strip().rstrip("/")
        timeout = httpx.Timeout(connect=20.0, read=180.0, write=180.0, pool=20.0)
        audio_b64 = base64.b64encode(audio.to_wav_bytes()).decode("utf-8")

        payload = {
            "model": model,
            "modalities": ["text", "audio"] if include_audio_output else ["text"],
            "temperature": 0,
            "messages": [
                {
                    "role": "system",
                    "content": "你是语音转写助手，只输出简体中文转写结果，不要补充说明。",
                },
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": "请将这段语音准确转写为简体中文，只输出转写文本。",
                        },
                        {
                            "type": "input_audio",
                            "input_audio": {
                                "data": audio_b64,
                                "format": "wav",
                            },
                        },
                    ],
                },
            ],
        }
        if include_audio_output:
            payload["audio"] = {
                "voice": "alloy",
                "format": "wav",
            }

        async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
            try:
                response = await client.post(
                    self._build_url(base_url, "/v1/chat/completions"),
                    headers={
                        "Authorization": f"Bearer {config.speech_api_key}",
                        "Content-Type": "application/json",
                    },
                    json=payload,
                )
                response.raise_for_status()
            except httpx.HTTPStatusError as exc:
                raise SpeechProviderError(self._read_error_detail(exc.response)) from exc
            except httpx.HTTPError as exc:
                raise SpeechProviderError("语音识别服务暂时不可用，请稍后重试") from exc

        try:
            data = response.json()
        except ValueError as exc:
            raise SpeechProviderError("语音识别服务返回了无效响应") from exc

        text = self._extract_chat_text(data)
        if not text:
            raise SpeechInputError("未识别到清晰语音，请重试")
        return text

    @staticmethod
    def _prefers_chat_audio(model: str) -> bool:
        return "audio-preview" in model.lower()

    @staticmethod
    def _fallback_transcription_model(model: str) -> str | None:
        normalized = model.lower()
        if normalized == "gpt-4o-mini-audio-preview":
            return "gpt-4o-mini-transcribe"
        if normalized == "gpt-4o-audio-preview":
            return "gpt-4o-transcribe"
        return None

    @staticmethod
    def _extract_chat_text(payload: dict[str, Any]) -> str:
        data = SpeechRecognitionService._payload_data(payload)
        choices = data.get("choices") or []
        if not isinstance(choices, list) or not choices:
            return ""

        message = choices[0].get("message") if isinstance(choices[0], dict) else None
        if not isinstance(message, dict):
            return ""

        audio_payload = message.get("audio")
        if isinstance(audio_payload, dict):
            for key in ("transcript", "text"):
                value = audio_payload.get(key)
                if value:
                    return str(value).strip()

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
        return f"Configured speech service request failed with status {response.status_code}"


speech_service = SpeechRecognitionService()
