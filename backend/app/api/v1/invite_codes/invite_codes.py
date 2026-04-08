from fastapi import APIRouter, Body, Query

from app.controllers.invite_code import invite_code_controller
from app.core.ctx import CTX_USER_ID
from app.models.admin import User
from app.schemas.base import Success, SuccessExtra
from app.schemas.invite_codes import InviteCodeCreate, InviteCodeUpdate

router = APIRouter()


@router.get("/list", summary="获取邀请码列表")
async def list_invite_codes(
    page: int = Query(1, description="页码"),
    page_size: int = Query(10, description="每页数量"),
    code: str = Query("", description="邀请码搜索"),
):
    search = {}
    if code:
        search["code__contains"] = code.strip().upper()

    await invite_code_controller.deactivate_expired_codes()
    query = invite_code_controller.model.filter(**search)
    total = await query.count()
    invite_codes = await query.offset((page - 1) * page_size).limit(page_size).order_by("-created_at", "-id")
    data = [await invite_code_controller.serialize_invite_code(item) for item in invite_codes]

    owner_ids = [item.get("owner_user_id") for item in data if item.get("owner_user_id")]
    owner_map = {}
    if owner_ids:
        owners = await User.filter(id__in=owner_ids)
        owner_map = {
            owner.id: {
                "id": owner.id,
                "username": owner.username,
                "alias": owner.alias,
            }
            for owner in owners
        }

    for item in data:
        owner_user_id = item.get("owner_user_id")
        item["owner_user"] = owner_map.get(owner_user_id) if owner_user_id else None

    return SuccessExtra(data=data, total=total, page=page, page_size=page_size)


@router.post("/create", summary="创建邀请码")
async def create_invite_code(req_in: InviteCodeCreate):
    user_id = CTX_USER_ID.get(None)
    invite_code = await invite_code_controller.create_invite_code(req_in, created_by_user_id=user_id)
    return Success(msg="创建成功", data=await invite_code_controller.serialize_invite_code(invite_code))


@router.post("/update", summary="更新邀请码")
async def update_invite_code(req_in: InviteCodeUpdate):
    await invite_code_controller.ensure_owner_user_exists(req_in.owner_user_id)
    invite_code = await invite_code_controller.update(id=req_in.id, obj_in=req_in)
    invite_code = await invite_code_controller.sync_invite_code_state(invite_code)
    return Success(msg="更新成功", data=await invite_code_controller.serialize_invite_code(invite_code))


@router.post("/toggle", summary="切换邀请码启用状态")
async def toggle_invite_code(
    invite_code_id: int = Body(..., embed=True, description="邀请码 ID"),
    is_active: bool = Body(..., embed=True, description="是否启用"),
):
    invite_code = await invite_code_controller.get(id=invite_code_id)
    if is_active:
        await invite_code_controller.ensure_can_enable(invite_code)
    invite_code.is_active = is_active
    await invite_code.save(update_fields=["is_active"])
    invite_code = await invite_code_controller.sync_invite_code_state(invite_code)
    return Success(msg="更新成功", data=await invite_code_controller.serialize_invite_code(invite_code))


@router.delete("/delete", summary="删除邀请码")
async def delete_invite_code(invite_code_id: int = Query(..., description="邀请码 ID")):
    await invite_code_controller.remove(invite_code_id)
    return Success(msg="删除成功")
