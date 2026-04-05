import logging

from fastapi import APIRouter, Body, Query
from fastapi.encoders import jsonable_encoder
from tortoise.functions import Count, Sum
from tortoise.expressions import Q

from app.controllers.dept import dept_controller
from app.controllers.invite_code import invite_code_controller
from app.controllers.points import points_controller
from app.controllers.user import user_controller
from app.core.ctx import CTX_USER_ID
from app.models.video_task import VideoTask, VoiceTranscriptionLog
from app.schemas.base import Fail, Success, SuccessExtra
from app.schemas.points import PointGiftIn
from app.schemas.users import UserCreate, UserUpdate

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/list", summary="获取用户列表")
async def list_user(
    page: int = Query(1, description="页码"),
    page_size: int = Query(10, description="每页数量"),
    username: str = Query("", description="用户名搜索"),
    email: str = Query("", description="邮箱搜索"),
    dept_id: int | None = Query(None, description="部门 ID"),
):
    q = Q()
    if username:
        q &= Q(username__contains=username)
    if email:
        q &= Q(email__contains=email)
    if dept_id is not None:
        q &= Q(dept_id=dept_id)

    total, user_objs = await user_controller.list(page=page, page_size=page_size, search=q)
    data = [await obj.to_dict(m2m=True, exclude_fields=["password"]) for obj in user_objs]
    invite_code_ids = [item.get("invite_code_id") for item in data if item.get("invite_code_id")]
    invite_map = {}
    if invite_code_ids:
        invite_objs = await invite_code_controller.model.filter(id__in=invite_code_ids)
        invite_map = {invite.id: await invite.to_dict() for invite in invite_objs}
    for item in data:
        current_dept_id = item.pop("dept_id", None)
        item["dept"] = await (await dept_controller.get(id=current_dept_id)).to_dict() if current_dept_id else {}
        invite_code_id = item.get("invite_code_id")
        item["invite_code"] = invite_map.get(invite_code_id, {}) if invite_code_id else {}
    return SuccessExtra(data=data, total=total, page=page, page_size=page_size)


@router.get("/get", summary="获取用户详情")
async def get_user(user_id: int = Query(..., description="用户 ID")):
    user_obj = await user_controller.get(id=user_id)
    user_dict = await user_obj.to_dict(exclude_fields=["password"])
    return Success(data=user_dict)


@router.get("/metrics", summary="获取用户统计")
async def user_metrics(
    username: str = Query("", description="用户名搜索"),
    dept_id: int | None = Query(None, description="部门 ID"),
):
    user_query = user_controller.model.all()
    if username:
        user_query = user_query.filter(Q(username__contains=username) | Q(alias__contains=username))
    if dept_id is not None:
        user_query = user_query.filter(dept_id=dept_id)

    users = await user_query.order_by("-last_login", "-id").limit(100).values(
        "id",
        "username",
        "alias",
        "is_active",
        "last_login",
    )
    user_ids = [item["id"] for item in users]
    if not user_ids:
        return Success(
            data={
                "summary": {
                    "users": 0,
                    "video_count": 0,
                    "completed_count": 0,
                    "failed_count": 0,
                    "voice_count": 0,
                    "total_duration": 0,
                },
                "ranking": [],
            }
        )

    task_rows = await (
        VideoTask.filter(user_id__in=user_ids, is_deleted=False)
        .group_by("user_id")
        .annotate(video_count=Count("id"), total_duration=Sum("duration"))
        .values("user_id", "video_count", "total_duration")
    )
    completed_rows = await (
        VideoTask.filter(user_id__in=user_ids, is_deleted=False, status="completed")
        .group_by("user_id")
        .annotate(completed_count=Count("id"))
        .values("user_id", "completed_count")
    )
    failed_rows = await (
        VideoTask.filter(user_id__in=user_ids, is_deleted=False, status="failed")
        .group_by("user_id")
        .annotate(failed_count=Count("id"))
        .values("user_id", "failed_count")
    )
    voice_rows = await (
        VoiceTranscriptionLog.filter(user_id__in=user_ids)
        .group_by("user_id")
        .annotate(voice_count=Count("id"))
        .values("user_id", "voice_count")
    )

    task_map = {item["user_id"]: item for item in task_rows}
    completed_map = {item["user_id"]: item for item in completed_rows}
    failed_map = {item["user_id"]: item for item in failed_rows}
    voice_map = {item["user_id"]: item for item in voice_rows}

    ranking = []
    summary = {
        "users": len(users),
        "video_count": 0,
        "completed_count": 0,
        "failed_count": 0,
        "voice_count": 0,
        "total_duration": 0,
    }
    for user in users:
        task_item = task_map.get(user["id"], {})
        voice_item = voice_map.get(user["id"], {})
        record = {
            "user_id": user["id"],
            "username": user["username"],
            "alias": user.get("alias"),
            "display_name": user.get("alias") or user["username"],
            "is_active": bool(user.get("is_active", True)),
            "last_login": user.get("last_login").isoformat() if user.get("last_login") else None,
            "video_count": int(task_item.get("video_count") or 0),
            "completed_count": int(completed_map.get(user["id"], {}).get("completed_count") or 0),
            "failed_count": int(failed_map.get(user["id"], {}).get("failed_count") or 0),
            "voice_count": int(voice_item.get("voice_count") or 0),
            "total_duration": int(task_item.get("total_duration") or 0),
        }
        ranking.append(record)
        summary["video_count"] += record["video_count"]
        summary["completed_count"] += record["completed_count"]
        summary["failed_count"] += record["failed_count"]
        summary["voice_count"] += record["voice_count"]
        summary["total_duration"] += record["total_duration"]

    ranking.sort(key=lambda item: (-item["video_count"], -item["completed_count"], item["username"]))
    return Success(data=jsonable_encoder({"summary": summary, "ranking": ranking}))


@router.post("/create", summary="创建用户")
async def create_user(user_in: UserCreate):
    email_user, username_user = await user_controller.get_by_email_or_username(
        email=user_in.email,
        username=user_in.username,
    )
    if email_user:
        return Fail(code=400, msg="邮箱已存在")
    if username_user:
        return Fail(code=400, msg="用户名已存在")
    new_user = await user_controller.create_user(obj_in=user_in)
    await user_controller.update_roles(new_user, user_in.role_ids or [])
    return Success(msg="创建成功")


@router.post("/update", summary="更新用户")
async def update_user(user_in: UserUpdate):
    email_user = await user_controller.get_by_email(user_in.email)
    if email_user and email_user.id != user_in.id:
        return Fail(code=400, msg="邮箱已存在")

    username_user = await user_controller.get_by_username(user_in.username)
    if username_user and username_user.id != user_in.id:
        return Fail(code=400, msg="用户名已存在")

    user = await user_controller.update(id=user_in.id, obj_in=user_in)
    await user_controller.update_roles(user, user_in.role_ids or [])
    return Success(msg="更新成功")


@router.delete("/delete", summary="删除用户")
async def delete_user(user_id: int = Query(..., description="用户 ID")):
    await user_controller.remove(id=user_id)
    return Success(msg="删除成功")


@router.post("/reset_password", summary="重置密码")
async def reset_password(user_id: int = Body(..., description="用户 ID", embed=True)):
    await user_controller.reset_password(user_id)
    return Success(msg="密码已重置为 123456")


@router.post("/gift_points", summary="赠送积分")
async def gift_points(req_in: PointGiftIn):
    ledger, user = await points_controller.grant_points(
        user_id=req_in.user_id,
        points=req_in.points,
        operator_user_id=CTX_USER_ID.get(None),
        remark=req_in.remark,
    )
    return Success(
        msg="积分赠送成功",
        data={
            "ledger": await points_controller.serialize_ledger(ledger),
            "user": {
                "id": user.id,
                "username": user.username,
                "points_balance": user.points_balance,
            },
        },
    )
