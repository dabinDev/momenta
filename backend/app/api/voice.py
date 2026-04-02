from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from app.controllers.task import task_controller
from app.core.ctx import CTX_USER_ID
from app.core.dependency import DependAuth
from app.log.log import logger
from app.schemas.base import Success
from app.services import get_or_create_user_app_config, speech_service
from app.services.speech import (
    SpeechConfigError,
    SpeechProviderError,
    SpeechRecognitionError,
)

_SERVICE_NOT_READY = "语音识别服务暂时不可用，请稍后重试"
_SERVICE_NOT_CONFIGURED = "语音识别服务尚未配置，请联系管理员"

router = APIRouter(prefix="/voice", tags=["Speech"])


@router.post("/transcribe", summary="Transcribe a voice message within 60 seconds", dependencies=[DependAuth])
async def transcribe_voice(audio: UploadFile = File(...), task_id: int | None = Form(default=None)):
    user_id = CTX_USER_ID.get()
    filename = audio.filename or "voice.pcm"
    config = await get_or_create_user_app_config(user_id)
    provider = speech_service.provider_name(config)
    try:
        content = await audio.read()
        result = await speech_service.transcribe_upload(
            config=config,
            filename=filename,
            content=content,
        )
        await task_controller.create_voice_log(
            user_id=user_id,
            task_id=task_id,
            provider=result.provider,
            file_name=filename,
            audio_format=result.audio_format,
            audio_duration=result.duration_seconds,
            language=result.language,
            accent=result.accent,
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
            provider=provider,
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
            provider=provider,
            error_message=_SERVICE_NOT_READY,
        )
        raise HTTPException(status_code=503, detail=_SERVICE_NOT_READY) from exc
    except SpeechRecognitionError as exc:
        await _create_failed_voice_log(
            user_id=user_id,
            task_id=task_id,
            filename=filename,
            provider=provider,
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
            provider=provider,
            error_message=_SERVICE_NOT_READY,
        )
        raise HTTPException(status_code=500, detail=_SERVICE_NOT_READY) from exc
    finally:
        await audio.close()

    return Success(
        data={
            "text": result.text,
            "provider": result.provider,
            "duration": result.duration_seconds,
        }
    )


async def _create_failed_voice_log(
    *,
    user_id: int,
    task_id: int | None,
    filename: str,
    provider: str,
    error_message: str,
) -> None:
    try:
        await task_controller.create_voice_log(
            user_id=user_id,
            task_id=task_id,
            provider=provider,
            file_name=filename,
            audio_format=_infer_audio_format(filename),
            audio_duration=0,
            language=speech_service.default_language,
            accent=speech_service.default_accent,
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
