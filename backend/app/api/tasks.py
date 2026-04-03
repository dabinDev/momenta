from fastapi import APIRouter, File, HTTPException, Query, UploadFile

from app.controllers.task import task_controller
from app.core.ctx import CTX_USER_ID
from app.core.dependency import DependAuth
from app.schemas.base import Success
from app.schemas.video_task import (
    CustomVideoTaskCreateIn,
    PromptGenerateIn,
    StarterVideoTaskCreateIn,
    TextTransformIn,
    VideoTaskCreateIn,
)
from app.services.business_gateway import business_gateway_service
from app.services.legacy_gateway import LegacyGatewayError
from app.services.llm_gateway import LLMGatewayError
from app.services.local_media import LocalMediaError
from app.services.video_gateway import VideoGatewayError

router = APIRouter(tags=["App Tasks"])


async def _build_task_response(
    *,
    user_id: int,
    provider: str,
    payload,
    input_text: str | None,
    polished_text: str | None,
    prompt: str | None,
    duration: int,
    images: list[str],
):
    if not isinstance(payload, dict):
        payload = {"data": payload}

    resolved_prompt = _resolve_requested_prompt(payload, fallback=prompt)

    task = await task_controller.create_task(
        user_id=user_id,
        task_source="app",
        task_type="image_to_video" if images else "text_to_video",
        provider=provider,
        input_text=input_text,
        polished_text=polished_text,
        prompt=resolved_prompt,
        duration=duration,
        images=images,
        provider_payload=payload,
    )
    return Success(data=await task_controller.serialize_task(task))


def _resolve_requested_prompt(payload, *, fallback: str | None) -> str:
    normalized_fallback = (fallback or "").strip()
    if normalized_fallback:
        return normalized_fallback

    if isinstance(payload, dict):
        request = payload.get("request")
        if isinstance(request, dict):
            requested_prompt = str(request.get("requested_prompt") or "").strip()
            if requested_prompt:
                return requested_prompt
    return ""


@router.post("/upload-images", summary="Upload reference images", dependencies=[DependAuth])
async def upload_images(images: list[UploadFile] = File(...)):
    user_id = CTX_USER_ID.get()
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

    return Success(data=payload)


@router.post("/upload-reference-video", summary="Upload reference video", dependencies=[DependAuth])
async def upload_reference_video(video: UploadFile = File(...)):
    user_id = CTX_USER_ID.get()
    try:
        payload = await business_gateway_service.upload_reference_video(
            user_id=user_id,
            file=(
                video.filename or "reference.mp4",
                await video.read(),
                video.content_type or "application/octet-stream",
            ),
        )
    except LocalMediaError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    finally:
        await video.close()

    return Success(data=payload)


@router.post("/correct-text", summary="Correct input text", dependencies=[DependAuth])
async def correct_text(req_in: TextTransformIn):
    user_id = CTX_USER_ID.get()
    try:
        payload = await business_gateway_service.correct_text(user_id=user_id, text=req_in.text)
    except (LegacyGatewayError, LLMGatewayError) as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    return Success(data=payload)


@router.post("/generate-prompt", summary="Generate prompt text", dependencies=[DependAuth])
async def generate_prompt(req_in: PromptGenerateIn):
    user_id = CTX_USER_ID.get()
    try:
        payload = await business_gateway_service.generate_prompt(
            user_id=user_id,
            text=req_in.text,
            prompt_template_key=req_in.prompt_template_key,
        )
    except (LegacyGatewayError, LLMGatewayError) as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    return Success(data=payload)


@router.get("/prompt-templates", summary="List prompt templates", dependencies=[DependAuth])
async def list_prompt_templates():
    return Success(data={"items": business_gateway_service.list_prompt_templates()})


@router.get("/video-templates", summary="List video templates", dependencies=[DependAuth])
async def list_video_templates():
    return Success(data={"items": business_gateway_service.list_video_templates()})


@router.get("/create-workbench", summary="Get create workbench manifest", dependencies=[DependAuth])
async def get_create_workbench():
    return Success(data=business_gateway_service.get_workbench_manifest())


@router.post("/tasks", summary="Create a simple video task", dependencies=[DependAuth])
async def create_task(req_in: VideoTaskCreateIn):
    user_id = CTX_USER_ID.get()

    try:
        provider, payload = await business_gateway_service.generate_video(
            user_id=user_id,
            prompt=req_in.prompt,
            images=req_in.images,
            duration=req_in.duration,
            prompt_template_key=req_in.prompt_template_key,
            video_template_key=req_in.video_template_key,
        )
    except (LegacyGatewayError, VideoGatewayError, LocalMediaError) as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    return await _build_task_response(
        user_id=user_id,
        provider=provider,
        payload=payload,
        input_text=req_in.input_text,
        polished_text=req_in.polished_text,
        prompt=req_in.prompt,
        duration=req_in.duration,
        images=req_in.images,
    )


@router.post("/starter-tasks", summary="Create a starter video task", dependencies=[DependAuth])
async def create_starter_task(req_in: StarterVideoTaskCreateIn):
    user_id = CTX_USER_ID.get()

    try:
        provider, payload = await business_gateway_service.generate_starter_video(
            user_id=user_id,
            prompt=req_in.prompt,
            input_text=req_in.input_text,
            images=req_in.images,
            duration=req_in.duration,
            reference_link=req_in.reference_link,
            prompt_template_key=req_in.prompt_template_key,
            video_template_key=req_in.video_template_key,
            supplemental_text=req_in.supplemental_text,
        )
    except (LegacyGatewayError, VideoGatewayError, LocalMediaError) as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    return await _build_task_response(
        user_id=user_id,
        provider=provider,
        payload=payload,
        input_text=req_in.input_text,
        polished_text=None,
        prompt=req_in.prompt,
        duration=req_in.duration,
        images=req_in.images,
    )


@router.post("/custom-tasks", summary="Create a custom video task", dependencies=[DependAuth])
async def create_custom_task(req_in: CustomVideoTaskCreateIn):
    user_id = CTX_USER_ID.get()

    try:
        provider, payload = await business_gateway_service.generate_custom_video(
            user_id=user_id,
            prompt=req_in.prompt,
            input_text=req_in.input_text,
            images=req_in.images,
            duration=req_in.duration,
            prompt_template_key=req_in.prompt_template_key,
            video_template_key=req_in.video_template_key,
            reference_link=req_in.reference_link,
            reference_video_path=req_in.reference_video_path,
            supplemental_text=req_in.supplemental_text,
        )
    except (LegacyGatewayError, VideoGatewayError, LocalMediaError) as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    return await _build_task_response(
        user_id=user_id,
        provider=provider,
        payload=payload,
        input_text=req_in.input_text,
        polished_text=None,
        prompt=req_in.prompt,
        duration=req_in.duration,
        images=req_in.images,
    )


@router.get("/tasks", summary="List current user tasks", dependencies=[DependAuth])
async def list_tasks(
    page: int = Query(1, ge=1, description="Page number"),
    limit: int = Query(10, ge=1, le=100, description="Page size"),
    filter: str = Query("all", description="Task status filter"),
):
    user_id = CTX_USER_ID.get()
    total, tasks = await task_controller.list_user_tasks(
        user_id=user_id,
        page=page,
        page_size=limit,
        status=filter,
    )
    items = []
    for task in tasks:
        if task.status in {"queued", "processing"}:
            try:
                task = await task_controller.sync_task_status(task)
            except (LegacyGatewayError, VideoGatewayError, LocalMediaError):
                pass
        items.append(await task_controller.serialize_task(task))
    return Success(
        data={
            "items": items,
            "page": page,
            "limit": limit,
            "total": total,
        }
    )


@router.get("/tasks/summary", summary="Get current user task summary", dependencies=[DependAuth])
async def task_summary():
    user_id = CTX_USER_ID.get()
    return Success(data=await task_controller.user_summary(user_id=user_id))


@router.get("/tasks/{task_id}", summary="Get task status", dependencies=[DependAuth])
async def get_task(task_id: int):
    user_id = CTX_USER_ID.get()
    task = await task_controller.get_user_task(task_id=task_id, user_id=user_id)
    try:
        task = await task_controller.sync_task_status(task)
    except (LegacyGatewayError, VideoGatewayError, LocalMediaError) as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    return Success(data=await task_controller.serialize_task(task))


@router.delete("/tasks/{task_id}", summary="Delete a task from current user history", dependencies=[DependAuth])
async def delete_task(task_id: int):
    user_id = CTX_USER_ID.get()
    await task_controller.mark_deleted(task_id=task_id, user_id=user_id)
    return Success(msg="Task removed from history")


@router.delete("/tasks", summary="Clear current user history", dependencies=[DependAuth])
async def clear_tasks():
    user_id = CTX_USER_ID.get()
    await task_controller.mark_all_deleted(user_id=user_id)
    return Success(msg="History cleared")


tasks_router = router
