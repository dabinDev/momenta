from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from app.controllers.task import task_controller
from app.core.ctx import CTX_USER_ID
from app.core.dependency import DependAuth
from app.log.log import logger
from app.schemas.base import Success
from app.services import speech_service
from app.services.speech import (
    SpeechConfigError,
    SpeechProviderError,
    SpeechRecognitionError,
)
from app.settings import settings

_SERVICE_NOT_READY = (
    "\u8bed\u97f3\u8bc6\u522b\u670d\u52a1\u6682\u65f6\u4e0d\u53ef\u7528\uff0c"
    "\u8bf7\u7a0d\u540e\u91cd\u8bd5"
)
_SERVICE_NOT_CONFIGURED = (
    "\u8bed\u97f3\u8bc6\u522b\u670d\u52a1\u5c1a\u672a\u914d\u7f6e\uff0c"
    "\u8bf7\u8054\u7cfb\u7ba1\u7406\u5458"
)

router = APIRouter(prefix="/voice", tags=["Speech"])


@router.post("/transcribe", summary="Transcribe a voice message within 60 seconds", dependencies=[DependAuth])
async def transcribe_voice(audio: UploadFile = File(...), task_id: int | None = Form(default=None)):
    user_id = CTX_USER_ID.get()
    filename = audio.filename or "voice.pcm"
    try:
        content = await audio.read()
        result = await speech_service.transcribe_upload(filename=filename, content=content)
        await task_controller.create_voice_log(
            user_id=user_id,
            task_id=task_id,
            provider="xfyun",
            file_name=filename,
            audio_format=result.audio_format,
            audio_duration=result.duration_seconds,
            language=settings.XFYUN_ASR_LANGUAGE,
            accent=settings.XFYUN_ASR_ACCENT,
            recognized_text=result.text,
            status="success",
        )
    except SpeechConfigError as exc:
        logger.warning(
            "speech service not configured user_id={} task_id={} filename={}",
            user_id,
            task_id,
            filename,
        )
        await _create_failed_voice_log(
            user_id=user_id,
            task_id=task_id,
            filename=filename,
            error_message=_SERVICE_NOT_CONFIGURED,
        )
        raise HTTPException(status_code=503, detail=_SERVICE_NOT_CONFIGURED) from exc
    except SpeechProviderError as exc:
        logger.exception(
            "speech provider failure user_id={} task_id={} filename={}",
            user_id,
            task_id,
            filename,
        )
        await _create_failed_voice_log(
            user_id=user_id,
            task_id=task_id,
            filename=filename,
            error_message=_SERVICE_NOT_READY,
        )
        raise HTTPException(status_code=503, detail=_SERVICE_NOT_READY) from exc
    except SpeechRecognitionError as exc:
        await _create_failed_voice_log(
            user_id=user_id,
            task_id=task_id,
            filename=filename,
            error_message=str(exc),
        )
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception(
            "unexpected speech api failure user_id={} task_id={} filename={}",
            user_id,
            task_id,
            filename,
        )
        await _create_failed_voice_log(
            user_id=user_id,
            task_id=task_id,
            filename=filename,
            error_message=_SERVICE_NOT_READY,
        )
        raise HTTPException(status_code=500, detail=_SERVICE_NOT_READY) from exc
    finally:
        await audio.close()

    return Success(
        data={
            "text": result.text,
            "provider": "xfyun",
            "duration": result.duration_seconds,
        }
    )


async def _create_failed_voice_log(*, user_id: int, task_id: int | None, filename: str, error_message: str) -> None:
    try:
        await task_controller.create_voice_log(
            user_id=user_id,
            task_id=task_id,
            provider="xfyun",
            file_name=filename,
            audio_format=_infer_audio_format(filename),
            audio_duration=0,
            language=settings.XFYUN_ASR_LANGUAGE,
            accent=settings.XFYUN_ASR_ACCENT,
            recognized_text=None,
            status="failed",
            error_message=error_message,
        )
    except Exception:
        logger.warning(
            "failed to persist speech failure log user_id={} task_id={} filename={}",
            user_id,
            task_id,
            filename,
        )


def _infer_audio_format(filename: str) -> str:
    lower_name = filename.lower()
    if lower_name.endswith(".wav"):
        return "wav"
    return "pcm"


voice_router = router
