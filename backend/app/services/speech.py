from __future__ import annotations

import asyncio
import base64
import hashlib
import hmac
import io
import json
import wave
from contextlib import suppress
from dataclasses import dataclass
from datetime import datetime, timezone
from email.utils import format_datetime
from urllib.parse import urlencode

import websockets
from websockets.exceptions import WebSocketException

from app.log.log import logger
from app.settings import settings


class SpeechRecognitionError(Exception):
    """Base exception for user-facing speech recognition errors."""


class SpeechInputError(SpeechRecognitionError):
    """Raised for invalid or unsupported input audio."""


class SpeechConfigError(SpeechRecognitionError):
    """Raised when the XFYun speech service is not configured."""


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


@dataclass(frozen=True)
class SpeechTranscriptionResult:
    text: str
    duration_seconds: float
    audio_format: str


class SpeechRecognitionService:
    _host = "iat.xf-yun.com"
    _path = "/v1"
    _base_ws_url = "wss://iat.xf-yun.com/v1"
    _frame_size = 1280
    _frame_interval_seconds = 0.04

    async def transcribe_upload(
        self,
        *,
        filename: str,
        content: bytes,
    ) -> SpeechTranscriptionResult:
        if not content:
            raise SpeechInputError("\u4e0a\u4f20\u7684\u8bed\u97f3\u6587\u4ef6\u4e3a\u7a7a")

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
        raise SpeechInputError("\u4ec5\u652f\u6301 .pcm \u6216 .wav \u8bed\u97f3\u6587\u4ef6")

    def _read_pcm(self, content: bytes) -> NormalizedAudio:
        if len(content) % 2 != 0:
            raise SpeechInputError("PCM \u97f3\u9891\u6570\u636e\u683c\u5f0f\u4e0d\u6b63\u786e")

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
            raise SpeechInputError("WAV \u97f3\u9891\u89e3\u6790\u5931\u8d25") from exc

        if channels != 1:
            raise SpeechInputError("\u4ec5\u652f\u6301\u5355\u58f0\u9053\u8bed\u97f3")
        if bit_depth != 16:
            raise SpeechInputError("\u4ec5\u652f\u6301 16 \u4f4d\u6df1\u5ea6\u97f3\u9891")
        if sample_rate not in {8000, 16000}:
            raise SpeechInputError("\u4ec5\u652f\u6301 8k \u6216 16k \u91c7\u6837\u7387\u97f3\u9891")

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
            raise SpeechInputError("\u8bed\u97f3\u65f6\u957f\u65e0\u6548")
        if duration_seconds > settings.XFYUN_ASR_MAX_SECONDS:
            raise SpeechInputError(
                f"\u5f53\u524d\u4ec5\u652f\u6301 {settings.XFYUN_ASR_MAX_SECONDS} "
                "\u79d2\u4ee5\u5185\u7684\u8bed\u97f3\u6d88\u606f"
            )

    async def _transcribe_with_xfyun(self, audio: NormalizedAudio) -> str:
        self._ensure_credentials()
        request_url = self._build_request_url()
        fragments: dict[int, str] = {}

        try:
            async with websockets.connect(
                request_url,
                max_size=None,
                ping_interval=20,
                ping_timeout=20,
                close_timeout=5,
            ) as websocket:
                receiver = asyncio.create_task(
                    self._receive_transcription(websocket=websocket, fragments=fragments)
                )
                try:
                    await self._send_audio_frames(websocket=websocket, audio=audio)
                    await receiver
                finally:
                    if not receiver.done():
                        receiver.cancel()
                        with suppress(asyncio.CancelledError):
                            await receiver
        except SpeechRecognitionError:
            raise
        except (WebSocketException, OSError, asyncio.TimeoutError) as exc:
            logger.exception("xfyun speech websocket failure")
            raise SpeechProviderError(
                "\u8bed\u97f3\u8bc6\u522b\u670d\u52a1\u6682\u65f6\u4e0d\u53ef\u7528\uff0c"
                "\u8bf7\u7a0d\u540e\u91cd\u8bd5"
            ) from exc
        except Exception as exc:
            logger.exception("unexpected xfyun speech failure")
            raise SpeechProviderError(
                "\u8bed\u97f3\u8bc6\u522b\u670d\u52a1\u6682\u65f6\u4e0d\u53ef\u7528\uff0c"
                "\u8bf7\u7a0d\u540e\u91cd\u8bd5"
            ) from exc

        text = "".join(fragments[index] for index in sorted(fragments)).strip()
        if not text:
            raise SpeechInputError(
                "\u672a\u8bc6\u522b\u5230\u6e05\u6670\u8bed\u97f3\uff0c\u8bf7\u91cd\u8bd5"
            )
        return text

    async def _send_audio_frames(self, *, websocket, audio: NormalizedAudio) -> None:
        chunks = [
            audio.payload[index : index + self._frame_size]
            for index in range(0, len(audio.payload), self._frame_size)
        ]

        if not chunks:
            raise SpeechInputError("\u4e0a\u4f20\u7684\u8bed\u97f3\u6587\u4ef6\u4e3a\u7a7a")

        for index, chunk in enumerate(chunks, start=1):
            await websocket.send(
                json.dumps(
                    self._build_request_frame(
                        audio=audio,
                        chunk=chunk,
                        status=0 if index == 1 else 1,
                        seq=index,
                        include_parameter=index == 1,
                    )
                )
            )
            await asyncio.sleep(self._frame_interval_seconds)

        await websocket.send(
            json.dumps(
                self._build_request_frame(
                    audio=audio,
                    chunk=b"",
                    status=2,
                    seq=len(chunks) + 1,
                    include_parameter=False,
                )
            )
        )

    async def _receive_transcription(self, *, websocket, fragments: dict[int, str]) -> None:
        while True:
            raw_message = await websocket.recv()
            response = json.loads(raw_message)
            header = response.get("header", {})
            code = int(header.get("code", 0))

            if code != 0:
                logger.error(
                    "xfyun speech provider error code={} sid={} message={}",
                    code,
                    header.get("sid"),
                    header.get("message") or response.get("message"),
                )
                raise SpeechProviderError(
                    "\u8bed\u97f3\u8bc6\u522b\u670d\u52a1\u6682\u65f6\u4e0d\u53ef\u7528\uff0c"
                    "\u8bf7\u7a0d\u540e\u91cd\u8bd5"
                )

            payload = response.get("payload", {})
            result = payload.get("result")
            if isinstance(result, dict):
                self._merge_result(fragments, result)

            if int(header.get("status", 2)) == 2:
                break

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

        try:
            decoded = base64.b64decode(encoded_text)
            payload = json.loads(decoded.decode("utf-8"))
        except (ValueError, json.JSONDecodeError) as exc:
            logger.exception("failed to decode xfyun speech result")
            raise SpeechProviderError(
                "\u8bed\u97f3\u8bc6\u522b\u670d\u52a1\u6682\u65f6\u4e0d\u53ef\u7528\uff0c"
                "\u8bf7\u7a0d\u540e\u91cd\u8bd5"
            ) from exc

        if int(payload.get("ret", 0)) != 0:
            logger.error(
                "xfyun speech result error ret={} sn={} message={}",
                payload.get("ret"),
                payload.get("sn"),
                payload.get("message"),
            )
            raise SpeechProviderError(
                "\u8bed\u97f3\u8bc6\u522b\u670d\u52a1\u6682\u65f6\u4e0d\u53ef\u7528\uff0c"
                "\u8bf7\u7a0d\u540e\u91cd\u8bd5"
            )

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
            raise SpeechConfigError(
                "\u8bed\u97f3\u8bc6\u522b\u670d\u52a1\u5c1a\u672a\u914d\u7f6e\uff0c"
                "\u8bf7\u8054\u7cfb\u7ba1\u7406\u5458"
            )

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
        authorization = base64.b64encode(authorization_origin.encode("utf-8")).decode(
            "utf-8"
        )
        query = urlencode(
            {
                "host": self._host,
                "date": date,
                "authorization": authorization,
            }
        )
        return f"{self._base_ws_url}?{query}"


speech_service = SpeechRecognitionService()
