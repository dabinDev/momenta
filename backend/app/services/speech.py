from __future__ import annotations

import base64
import hashlib
import hmac
import io
import json
import wave
from dataclasses import dataclass
from email.utils import format_datetime
from math import ceil
from urllib.parse import urlencode

import websockets
from datetime import datetime, timezone

from app.settings import settings


class SpeechRecognitionError(Exception):
    pass


class SpeechConfigError(SpeechRecognitionError):
    pass


@dataclass(frozen=True)
class NormalizedAudio:
    payload: bytes
    sample_rate: int
    channels: int
    bit_depth: int
    encoding: str
    audio_format: str
    duration_seconds: float


@dataclass(frozen=True)
class SpeechTranscriptionResult:
    text: str
    duration_seconds: float
    audio_format: str


class SpeechRecognitionService:
    _host = "iat.xf-yun.com"
    _path = "/v1"
    _base_ws_url = "wss://iat.xf-yun.com/v1"

    async def transcribe_upload(self, *, filename: str, content: bytes) -> SpeechTranscriptionResult:
        if not content:
            raise SpeechRecognitionError("上传的音频文件为空")

        audio = self._normalize_audio(filename=filename, content=content)
        text = await self._transcribe_with_xfyun(audio)
        return SpeechTranscriptionResult(
            text=text,
            duration_seconds=audio.duration_seconds,
            audio_format=audio.audio_format,
        )

    def _normalize_audio(self, *, filename: str, content: bytes) -> NormalizedAudio:
        lower_name = filename.lower()
        if lower_name.endswith(".wav") or content.startswith(b"RIFF"):
            return self._read_wav(content)
        if lower_name.endswith(".pcm"):
            return self._read_pcm(content)
        raise SpeechRecognitionError("仅支持 .pcm 或 .wav 音频文件")

    def _read_pcm(self, content: bytes) -> NormalizedAudio:
        if len(content) % 2 != 0:
            raise SpeechRecognitionError("PCM 音频数据格式不正确")

        sample_rate = settings.XFYUN_ASR_SAMPLE_RATE
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
            raise SpeechRecognitionError("WAV 音频解析失败") from exc

        if channels != 1:
            raise SpeechRecognitionError("仅支持单声道音频")
        if bit_depth != 16:
            raise SpeechRecognitionError("仅支持 16 位深度音频")
        if sample_rate not in {8000, 16000}:
            raise SpeechRecognitionError("仅支持 8k 或 16k 采样率音频")

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

    def _validate_duration(self, duration_seconds: float) -> None:
        if duration_seconds <= 0:
            raise SpeechRecognitionError("音频时长无效")
        if duration_seconds > settings.XFYUN_ASR_MAX_SECONDS:
            raise SpeechRecognitionError(
                f"当前仅支持 {settings.XFYUN_ASR_MAX_SECONDS} 秒以内的语音消息"
            )

    async def _transcribe_with_xfyun(self, audio: NormalizedAudio) -> str:
        self._ensure_credentials()
        request_url = self._build_request_url()
        fragments: dict[int, str] = {}
        frame_size = 1280
        total_frames = max(1, ceil(len(audio.payload) / frame_size))

        try:
            async with websockets.connect(request_url, max_size=None) as websocket:
                for index in range(total_frames):
                    start = index * frame_size
                    end = min(start + frame_size, len(audio.payload))
                    status = 0 if index == 0 else 1
                    if index == total_frames - 1:
                        status = 2

                    await websocket.send(
                        json.dumps(
                            self._build_request_frame(
                                audio=audio,
                                chunk=audio.payload[start:end],
                                status=status,
                                seq=index + 1,
                                include_parameter=index == 0,
                            )
                        )
                    )

                while True:
                    message = await websocket.recv()
                    response = json.loads(message)
                    header = response.get("header", {})
                    code = int(header.get("code", 0))
                    if code != 0:
                        raise SpeechRecognitionError(
                            header.get("message") or "讯飞语音识别调用失败"
                        )

                    payload = response.get("payload", {})
                    result = payload.get("result")
                    if result:
                        self._merge_result(fragments, result)

                    if int(header.get("status", 2)) == 2:
                        break
        except websockets.WebSocketException as exc:
            raise SpeechRecognitionError("讯飞语音识别连接失败") from exc
        except OSError as exc:
            raise SpeechRecognitionError("讯飞语音识别网络异常") from exc

        text = "".join(fragments[index] for index in sorted(fragments)).strip()
        if not text:
            raise SpeechRecognitionError("未识别到清晰语音，请重试")
        return text

    def _build_request_frame(
        self,
        *,
        audio: NormalizedAudio,
        chunk: bytes,
        status: int,
        seq: int,
        include_parameter: bool,
    ) -> dict[str, object]:
        frame: dict[str, object] = {
            "header": {
                "app_id": settings.XFYUN_ASR_APP_ID,
                "status": status,
            },
            "payload": {
                "audio": {
                    "encoding": audio.encoding,
                    "sample_rate": audio.sample_rate,
                    "channels": audio.channels,
                    "bit_depth": audio.bit_depth,
                    "seq": seq,
                    "status": status,
                    "audio": base64.b64encode(chunk).decode("utf-8"),
                }
            },
        }

        if settings.XFYUN_ASR_RES_ID:
            frame["header"]["res_id"] = settings.XFYUN_ASR_RES_ID

        if include_parameter:
            iat_parameter: dict[str, object] = {
                "domain": settings.XFYUN_ASR_DOMAIN,
                "language": settings.XFYUN_ASR_LANGUAGE,
                "accent": settings.XFYUN_ASR_ACCENT,
                "eos": settings.XFYUN_ASR_EOS,
                "ltc": settings.XFYUN_ASR_LTC,
                "vinfo": settings.XFYUN_ASR_VINFO,
                "result": {
                    "encoding": "utf8",
                    "compress": "raw",
                    "format": "json",
                },
            }
            if settings.XFYUN_ASR_DWA:
                iat_parameter["dwa"] = settings.XFYUN_ASR_DWA
            if settings.XFYUN_ASR_DHW:
                iat_parameter["dhw"] = settings.XFYUN_ASR_DHW
            frame["parameter"] = {"iat": iat_parameter}

        return frame

    def _merge_result(self, fragments: dict[int, str], result: dict[str, object]) -> None:
        encoded_text = str(result.get("text", "")).strip()
        if not encoded_text:
            return

        decoded = base64.b64decode(encoded_text)
        payload = json.loads(decoded.decode("utf-8"))
        if int(payload.get("ret", 0)) not in {0}:
            raise SpeechRecognitionError(payload.get("message") or "讯飞语音识别返回异常")

        serial = int(payload.get("sn", len(fragments) + 1))
        words = payload.get("ws", [])
        text = "".join(
            candidate.get("w", "")
            for item in words
            if isinstance(item, dict)
            for candidate in item.get("cw", [])[:1]
            if isinstance(candidate, dict)
        )

        if payload.get("pgs") == "rpl":
            rg = payload.get("rg") or []
            if isinstance(rg, list) and len(rg) == 2:
                start, end = int(rg[0]), int(rg[1])
                for index in range(start, end + 1):
                    fragments.pop(index, None)

        fragments[serial] = text

    def _ensure_credentials(self) -> None:
        if (
            not settings.XFYUN_ASR_APP_ID
            or not settings.XFYUN_ASR_API_KEY
            or not settings.XFYUN_ASR_API_SECRET
        ):
            raise SpeechConfigError("未配置讯飞语音识别密钥")

    def _build_request_url(self) -> str:
        date = format_datetime(datetime.now(timezone.utc), usegmt=True)
        signature_origin = f"host: {self._host}\ndate: {date}\nGET {self._path} HTTP/1.1"
        digest = hmac.new(
            settings.XFYUN_ASR_API_SECRET.encode("utf-8"),
            signature_origin.encode("utf-8"),
            digestmod=hashlib.sha256,
        ).digest()
        signature = base64.b64encode(digest).decode("utf-8")
        authorization_origin = (
            f'api_key="{settings.XFYUN_ASR_API_KEY}", '
            f'algorithm="hmac-sha256", '
            f'headers="host date request-line", '
            f'signature="{signature}"'
        )
        authorization = base64.b64encode(
            authorization_origin.encode("utf-8")
        ).decode("utf-8")
        query = urlencode(
            {
                "host": self._host,
                "date": date,
                "authorization": authorization,
            }
        )
        return f"{self._base_ws_url}?{query}"


speech_service = SpeechRecognitionService()
