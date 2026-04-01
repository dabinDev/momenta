from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from app.controllers.task import task_controller
from app.controllers.user import user_controller
from app.log.log import logger
from app.schemas.ai_debug import AIDebugTaskCreateRequest, AIDebugTextRequest
from app.schemas.base import Success
from app.services import speech_service
from app.services.business_gateway import business_gateway_service
from app.services.legacy_gateway import LegacyGatewayError
from app.services.llm_gateway import LLMGatewayError
from app.services.local_media import LocalMediaError
from app.services.speech import (
    SpeechConfigError,
    SpeechProviderError,
    SpeechRecognitionError,
)
from app.services.video_gateway import VideoGatewayError
from app.settings import settings

_SERVICE_NOT_READY = (
    "\u8bed\u97f3\u8bc6\u522b\u670d\u52a1\u6682\u65f6\u4e0d\u53ef\u7528\uff0c"
    "\u8bf7\u7a0d\u540e\u91cd\u8bd5"
)
_SERVICE_NOT_CONFIGURED = (
    "\u8bed\u97f3\u8bc6\u522b\u670d\u52a1\u5c1a\u672a\u914d\u7f6e\uff0c"
    "\u8bf7\u8054\u7cfb\u7ba1\u7406\u5458"
)

router = APIRouter()


@router.post("/upload_images", summary="Upload debug reference images")
async def upload_debug_images(
    user_id: int = Form(..., description="Target user ID"),
    images: list[UploadFile] = File(...),
):
    await user_controller.get(id=user_id)
    files: list[tuple[str, bytes, str]] = []
    try:
        for image in images:
            files.append(
                (
                    image.filename or "image.jpg",
                    await image.read(),
                    image.content_type or "application/octet-stream",
                )
            )
        payload = await business_gateway_service.upload_images(user_id=user_id, files=files)
    except (LegacyGatewayError, LocalMediaError) as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    finally:
        for image in images:
            await image.close()

    return Success(data=payload if isinstance(payload, dict) else {"result": payload})


@router.post("/polish_text", summary="Polish text with target user config")
async def polish_debug_text(req_in: AIDebugTextRequest):
    await user_controller.get(id=req_in.user_id)
    try:
        payload = await business_gateway_service.polish_text(user_id=req_in.user_id, text=req_in.text)
    except (LegacyGatewayError, LLMGatewayError) as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    return Success(data=payload if isinstance(payload, dict) else {"result": payload})


@router.post("/generate_prompt", summary="Generate prompt with target user config")
async def generate_debug_prompt(req_in: AIDebugTextRequest):
    await user_controller.get(id=req_in.user_id)
    try:
        payload = await business_gateway_service.generate_prompt(user_id=req_in.user_id, text=req_in.text)
    except (LegacyGatewayError, LLMGatewayError) as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    return Success(data=payload if isinstance(payload, dict) else {"result": payload})


@router.post("/create_task", summary="Create debug video task for target user")
async def create_debug_task(req_in: AIDebugTaskCreateRequest):
    await user_controller.get(id=req_in.user_id)
    try:
        provider, payload = await business_gateway_service.generate_video(
            user_id=req_in.user_id,
            prompt=req_in.prompt,
            images=req_in.images,
            duration=req_in.duration,
        )
    except (LegacyGatewayError, VideoGatewayError, LocalMediaError) as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    if not isinstance(payload, dict):
        payload = {"result": payload}

    task = await task_controller.create_task(
        user_id=req_in.user_id,
        task_source="admin",
        task_type="image_to_video" if req_in.images else "text_to_video",
        provider=provider,
        input_text=req_in.input_text,
        polished_text=req_in.polished_text,
        prompt=req_in.prompt,
        duration=req_in.duration,
        images=req_in.images,
        provider_payload=payload,
    )
    return Success(
        data={
            "provider": provider,
            "provider_payload": payload,
            "task": await task_controller.serialize_task(task, include_user=True),
        }
    )


@router.post("/transcribe", summary="Transcribe voice for target user")
async def transcribe_debug_voice(
    user_id: int = Form(..., description="Target user ID"),
    audio: UploadFile = File(...),
    task_id: int | None = Form(default=None),
):
    await user_controller.get(id=user_id)
    filename = audio.filename or "voice.pcm"
    try:
        content = await audio.read()
        result = await speech_service.transcribe_upload(filename=filename, content=content)
        voice_log = await task_controller.create_voice_log(
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
            "debug speech service not configured user_id={} task_id={} filename={}",
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
            "debug speech provider failure user_id={} task_id={} filename={}",
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
            "unexpected debug speech api failure user_id={} task_id={} filename={}",
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
            "voice_log": await task_controller.serialize_voice_log(voice_log),
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
            "failed to persist debug speech failure log user_id={} task_id={} filename={}",
            user_id,
            task_id,
            filename,
        )


def _infer_audio_format(filename: str) -> str:
    lower_name = filename.lower()
    if lower_name.endswith(".wav"):
        return "wav"
    return "pcm"
