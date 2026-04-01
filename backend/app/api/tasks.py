from fastapi import APIRouter, File, HTTPException, Query, UploadFile

from app.controllers.task import task_controller
from app.core.ctx import CTX_USER_ID
from app.core.dependency import DependAuth
from app.schemas.base import Success
from app.schemas.video_task import TextTransformIn, VideoTaskCreateIn
from app.services.business_gateway import business_gateway_service
from app.services.legacy_gateway import LegacyGatewayError
from app.services.llm_gateway import LLMGatewayError
from app.services.local_media import LocalMediaError
from app.services.video_gateway import VideoGatewayError

router = APIRouter(tags=["App Tasks"])


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


@router.post("/polish-text", summary="Polish text for video creation", dependencies=[DependAuth])
async def polish_text(req_in: TextTransformIn):
    user_id = CTX_USER_ID.get()
    try:
        payload = await business_gateway_service.polish_text(user_id=user_id, text=req_in.text)
    except (LegacyGatewayError, LLMGatewayError) as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    return Success(data=payload)


@router.post("/generate-prompt", summary="Generate prompt text", dependencies=[DependAuth])
async def generate_prompt(req_in: TextTransformIn):
    user_id = CTX_USER_ID.get()
    try:
        payload = await business_gateway_service.generate_prompt(user_id=user_id, text=req_in.text)
    except (LegacyGatewayError, LLMGatewayError) as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    return Success(data=payload)


@router.post("/tasks", summary="Create a video task", dependencies=[DependAuth])
async def create_task(req_in: VideoTaskCreateIn):
    user_id = CTX_USER_ID.get()

    try:
        provider, payload = await business_gateway_service.generate_video(
            user_id=user_id,
            prompt=req_in.prompt,
            images=req_in.images,
            duration=req_in.duration,
        )
    except (LegacyGatewayError, VideoGatewayError, LocalMediaError) as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    if not isinstance(payload, dict):
        payload = {"data": payload}

    task = await task_controller.create_task(
        user_id=user_id,
        task_source="app",
        task_type="image_to_video" if req_in.images else "text_to_video",
        provider=provider,
        input_text=req_in.input_text,
        polished_text=req_in.polished_text,
        prompt=req_in.prompt,
        duration=req_in.duration,
        images=req_in.images,
        provider_payload=payload,
    )
    return Success(data=await task_controller.serialize_task(task))


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
    items = [await task_controller.serialize_task(task) for task in tasks]
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
