import logging

from fastapi import APIRouter, Body, Query
from tortoise.expressions import Q

from app.controllers.dept import dept_controller
from app.controllers.user import user_controller
from app.schemas.base import Fail, Success, SuccessExtra
from app.schemas.users import UserCreate, UserUpdate

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/list", summary="List users")
async def list_user(
    page: int = Query(1, description="Page"),
    page_size: int = Query(10, description="Page size"),
    username: str = Query("", description="Username search"),
    email: str = Query("", description="Email search"),
    dept_id: int | None = Query(None, description="Department ID"),
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
    for item in data:
        current_dept_id = item.pop("dept_id", None)
        item["dept"] = await (await dept_controller.get(id=current_dept_id)).to_dict() if current_dept_id else {}
    return SuccessExtra(data=data, total=total, page=page, page_size=page_size)


@router.get("/get", summary="Get user")
async def get_user(user_id: int = Query(..., description="User ID")):
    user_obj = await user_controller.get(id=user_id)
    user_dict = await user_obj.to_dict(exclude_fields=["password"])
    return Success(data=user_dict)


@router.post("/create", summary="Create user")
async def create_user(user_in: UserCreate):
    email_user, username_user = await user_controller.get_by_email_or_username(
        email=user_in.email,
        username=user_in.username,
    )
    if email_user:
        return Fail(code=400, msg="Email already exists")
    if username_user:
        return Fail(code=400, msg="Username already exists")
    new_user = await user_controller.create_user(obj_in=user_in)
    await user_controller.update_roles(new_user, user_in.role_ids or [])
    return Success(msg="Created successfully")


@router.post("/update", summary="Update user")
async def update_user(user_in: UserUpdate):
    email_user = await user_controller.get_by_email(user_in.email)
    if email_user and email_user.id != user_in.id:
        return Fail(code=400, msg="Email already exists")

    username_user = await user_controller.get_by_username(user_in.username)
    if username_user and username_user.id != user_in.id:
        return Fail(code=400, msg="Username already exists")

    user = await user_controller.update(id=user_in.id, obj_in=user_in)
    await user_controller.update_roles(user, user_in.role_ids or [])
    return Success(msg="Updated successfully")


@router.delete("/delete", summary="Delete user")
async def delete_user(user_id: int = Query(..., description="User ID")):
    await user_controller.remove(id=user_id)
    return Success(msg="Deleted successfully")


@router.post("/reset_password", summary="Reset password")
async def reset_password(user_id: int = Body(..., description="User ID", embed=True)):
    await user_controller.reset_password(user_id)
    return Success(msg="Password reset to 123456")
