from fastapi import APIRouter, Body, Query

from app.controllers.invite_code import invite_code_controller
from app.core.ctx import CTX_USER_ID
from app.schemas.base import Success, SuccessExtra
from app.schemas.invite_codes import InviteCodeCreate, InviteCodeUpdate

router = APIRouter()


@router.get("/list", summary="List invite codes")
async def list_invite_codes(
    page: int = Query(1, description="Page"),
    page_size: int = Query(10, description="Page size"),
    code: str = Query("", description="Invite code search"),
):
    search = {}
    if code:
        search["code__contains"] = code.strip().upper()
    query = invite_code_controller.model.filter(**search)
    total = await query.count()
    invite_codes = await query.offset((page - 1) * page_size).limit(page_size).order_by("-created_at", "-id")
    data = [await item.to_dict() for item in invite_codes]
    return SuccessExtra(data=data, total=total, page=page, page_size=page_size)


@router.post("/create", summary="Create invite code")
async def create_invite_code(req_in: InviteCodeCreate):
    user_id = CTX_USER_ID.get(None)
    invite_code = await invite_code_controller.create_invite_code(req_in, created_by_user_id=user_id)
    return Success(msg="Created successfully", data=await invite_code.to_dict())


@router.post("/update", summary="Update invite code")
async def update_invite_code(req_in: InviteCodeUpdate):
    invite_code = await invite_code_controller.update(id=req_in.id, obj_in=req_in)
    if invite_code.used_count >= invite_code.max_uses:
        invite_code.is_active = False
        await invite_code.save()
    return Success(msg="Updated successfully", data=await invite_code.to_dict())


@router.post("/toggle", summary="Toggle invite code active status")
async def toggle_invite_code(
    invite_code_id: int = Body(..., embed=True, description="Invite code ID"),
    is_active: bool = Body(..., embed=True, description="Whether active"),
):
    invite_code = await invite_code_controller.get(invite_code_id)
    invite_code.is_active = is_active
    await invite_code.save()
    return Success(msg="Updated successfully")


@router.delete("/delete", summary="Delete invite code")
async def delete_invite_code(invite_code_id: int = Query(..., description="Invite code ID")):
    await invite_code_controller.remove(invite_code_id)
    return Success(msg="Deleted successfully")
