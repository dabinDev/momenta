from pathlib import Path
from urllib.parse import urlparse

import httpx
from fastapi import APIRouter, File, HTTPException, Query, UploadFile
from starlette.background import BackgroundTask
from starlette.responses import StreamingResponse

from app.controllers.points import points_controller
from app.controllers.task import VideoGenerationRateLimitError, task_controller
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
from app.settings.config import settings

router = APIRouter(tags=["创作任务"])


def _resolve_video_url(raw_url: str) -> str:
    normalized = str(raw_url or "").strip()
    if not normalized:
        return ""
    if normalized.startswith("http://") or normalized.startswith("https://"):
        return normalized
    base_url = settings.PUBLIC_BASE_URL.rstrip("/")
    if not normalized.startswith("/"):
        normalized = f"/{normalized}"
    return f"{base_url}{normalized}"


def _download_filename(task_id: int, target_url: str) -> str:
    suffix = Path(urlparse(target_url).path).suffix or ".mp4"
    return f"task_{task_id}{suffix}"


async def _close_download_stream(
    response: httpx.Response,
    client: httpx.AsyncClient,
) -> None:
    await response.aclose()
    await client.aclose()


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
    points_cost: int = 0,
    points_charge_token: str | None = None,
):
    if not isinstance(payload, dict):
        payload = {"data": payload}

    resolved_prompt = _resolve_requested_prompt(payload, fallback=prompt)

    try:
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
            points_cost=points_cost,
            points_charge_token=points_charge_token,
        )
    except Exception:
        if points_charge_token:
            await points_controller.refund_video_generation_points(
                user_id=user_id,
                charge_token=points_charge_token,
                reason="任务创建失败，积分已退回",
            )
        raise
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
    slot_claimed = False
    charge_info = None

    try:
        await task_controller.claim_generation_slot(user_id=user_id)
        slot_claimed = True
        charge_info = await points_controller.reserve_video_generation_points(
            user_id=user_id,
            task_source="app",
            task_type="simple",
        )
        provider, payload = await business_gateway_service.generate_video(
            user_id=user_id,
            prompt=req_in.prompt,
            images=req_in.images,
            duration=req_in.duration,
            prompt_template_key=req_in.prompt_template_key,
            video_template_key=req_in.video_template_key,
        )
        return await _build_task_response(
            user_id=user_id,
            provider=provider,
            payload=payload,
            input_text=req_in.input_text,
            polished_text=req_in.polished_text,
            prompt=req_in.prompt,
            duration=req_in.duration,
            images=req_in.images,
            points_cost=int(charge_info["points_cost"]),
            points_charge_token=str(charge_info["charge_token"]),
        )
    except VideoGenerationRateLimitError as exc:
        raise HTTPException(status_code=429, detail=str(exc)) from exc
    except (LegacyGatewayError, VideoGatewayError, LocalMediaError) as exc:
        if charge_info:
            await points_controller.refund_video_generation_points(
                user_id=user_id,
                charge_token=str(charge_info["charge_token"]),
            )
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except Exception:
        if charge_info:
            await points_controller.refund_video_generation_points(
                user_id=user_id,
                charge_token=str(charge_info["charge_token"]),
                reason="任务创建失败，积分已退回",
            )
        raise
    finally:
        if slot_claimed:
            await task_controller.release_generation_slot(user_id=user_id)


@router.post("/starter-tasks", summary="Create a starter video task", dependencies=[DependAuth])
async def create_starter_task(req_in: StarterVideoTaskCreateIn):
    user_id = CTX_USER_ID.get()
    slot_claimed = False
    charge_info = None

    try:
        await task_controller.claim_generation_slot(user_id=user_id)
        slot_claimed = True
        charge_info = await points_controller.reserve_video_generation_points(
            user_id=user_id,
            task_source="app",
            task_type="starter",
        )
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
        return await _build_task_response(
            user_id=user_id,
            provider=provider,
            payload=payload,
            input_text=req_in.input_text,
            polished_text=None,
            prompt=req_in.prompt,
            duration=req_in.duration,
            images=req_in.images,
            points_cost=int(charge_info["points_cost"]),
            points_charge_token=str(charge_info["charge_token"]),
        )
    except VideoGenerationRateLimitError as exc:
        raise HTTPException(status_code=429, detail=str(exc)) from exc
    except (LegacyGatewayError, VideoGatewayError, LocalMediaError) as exc:
        if charge_info:
            await points_controller.refund_video_generation_points(
                user_id=user_id,
                charge_token=str(charge_info["charge_token"]),
            )
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except Exception:
        if charge_info:
            await points_controller.refund_video_generation_points(
                user_id=user_id,
                charge_token=str(charge_info["charge_token"]),
                reason="任务创建失败，积分已退回",
            )
        raise
    finally:
        if slot_claimed:
            await task_controller.release_generation_slot(user_id=user_id)


@router.post("/custom-tasks", summary="Create a custom video task", dependencies=[DependAuth])
async def create_custom_task(req_in: CustomVideoTaskCreateIn):
    user_id = CTX_USER_ID.get()
    slot_claimed = False
    charge_info = None

    try:
        await task_controller.claim_generation_slot(user_id=user_id)
        slot_claimed = True
        charge_info = await points_controller.reserve_video_generation_points(
            user_id=user_id,
            task_source="app",
            task_type="custom",
        )
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
        return await _build_task_response(
            user_id=user_id,
            provider=provider,
            payload=payload,
            input_text=req_in.input_text,
            polished_text=None,
            prompt=req_in.prompt,
            duration=req_in.duration,
            images=req_in.images,
            points_cost=int(charge_info["points_cost"]),
            points_charge_token=str(charge_info["charge_token"]),
        )
    except VideoGenerationRateLimitError as exc:
        raise HTTPException(status_code=429, detail=str(exc)) from exc
    except (LegacyGatewayError, VideoGatewayError, LocalMediaError) as exc:
        if charge_info:
            await points_controller.refund_video_generation_points(
                user_id=user_id,
                charge_token=str(charge_info["charge_token"]),
            )
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except Exception:
        if charge_info:
            await points_controller.refund_video_generation_points(
                user_id=user_id,
                charge_token=str(charge_info["charge_token"]),
                reason="任务创建失败，积分已退回",
            )
        raise
    finally:
        if slot_claimed:
            await task_controller.release_generation_slot(user_id=user_id)


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


@router.post("/tasks/{task_id}/retry", summary="Retry a failed task", dependencies=[DependAuth])
async def retry_task(task_id: int):
    user_id = CTX_USER_ID.get()
    charge_info = None
    try:
        charge_info = await points_controller.reserve_video_generation_points(
            user_id=user_id,
            task_source="app",
            task_type="retry",
        )
        task = await task_controller.retry_user_task(
            task_id=task_id,
            user_id=user_id,
            points_cost=int(charge_info["points_cost"]),
            points_charge_token=str(charge_info["charge_token"]),
        )
    except VideoGenerationRateLimitError as exc:
        raise HTTPException(status_code=429, detail=str(exc)) from exc
    except ValueError as exc:
        if charge_info:
            await points_controller.refund_video_generation_points(
                user_id=user_id,
                charge_token=str(charge_info["charge_token"]),
                reason="任务重试失败，积分已退回",
            )
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except (LegacyGatewayError, VideoGatewayError, LocalMediaError) as exc:
        if charge_info:
            await points_controller.refund_video_generation_points(
                user_id=user_id,
                charge_token=str(charge_info["charge_token"]),
                reason="任务重试失败，积分已退回",
            )
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except Exception:
        if charge_info:
            await points_controller.refund_video_generation_points(
                user_id=user_id,
                charge_token=str(charge_info["charge_token"]),
                reason="任务重试失败，积分已退回",
            )
        raise
    return Success(data=await task_controller.serialize_task(task))


@router.get("/tasks/{task_id}/download", summary="Download current user task video", dependencies=[DependAuth])
async def download_task_video(task_id: int):
    user_id = CTX_USER_ID.get()
    task = await task_controller.get_user_task(task_id=task_id, user_id=user_id)
    target_url = _resolve_video_url(await task_controller.resolve_public_video_url(task))
    if not target_url:
        raise HTTPException(status_code=404, detail="当前任务视频尚未生成完成")

    client = httpx.AsyncClient(
        timeout=httpx.Timeout(connect=20.0, read=240.0, write=240.0, pool=20.0),
        follow_redirects=True,
    )
    try:
        response = await client.send(
            client.build_request("GET", target_url),
            stream=True,
        )
        response.raise_for_status()
    except httpx.HTTPStatusError as exc:
        await client.aclose()
        raise HTTPException(status_code=exc.response.status_code, detail="下载任务视频失败") from exc
    except httpx.HTTPError as exc:
        await client.aclose()
        raise HTTPException(status_code=502, detail="下载任务视频失败") from exc

    headers = {
        "Content-Disposition": f'attachment; filename="{_download_filename(task.id, target_url)}"',
    }
    content_length = response.headers.get("content-length")
    if content_length:
        headers["Content-Length"] = content_length

    return StreamingResponse(
        response.aiter_bytes(),
        media_type=response.headers.get("content-type") or "application/octet-stream",
        headers=headers,
        background=BackgroundTask(_close_download_stream, response, client),
    )


@router.delete("/tasks/{task_id}", summary="Delete a task from current user history", dependencies=[DependAuth])
async def delete_task(task_id: int):
    user_id = CTX_USER_ID.get()
    await task_controller.mark_deleted(task_id=task_id, user_id=user_id)
    return Success(msg="任务已从当前账号历史记录中删除")


@router.delete("/tasks", summary="Clear current user history", dependencies=[DependAuth])
async def clear_tasks():
    user_id = CTX_USER_ID.get()
    await task_controller.mark_all_deleted(user_id=user_id)
    return Success(msg="当前账号历史记录已清空")


tasks_router = router
