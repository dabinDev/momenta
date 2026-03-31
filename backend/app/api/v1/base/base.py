from datetime import datetime, timedelta, timezone

from fastapi import APIRouter

from app.controllers.user import user_controller
from app.core.ctx import CTX_USER_ID
from app.core.dependency import DependAuth
from app.models.admin import Api, Menu, Role, User
from app.schemas.base import Success
from app.schemas.login import CredentialsSchema, JWTPayload, JWTOut
from app.schemas.users import ForgotPasswordRequest, UpdateCurrentUserProfile, UpdatePassword
from app.settings import settings
from app.utils.jwt_utils import create_access_token

router = APIRouter()


@router.post("/access_token", summary="Get access token")
async def login_access_token(credentials: CredentialsSchema):
    user: User = await user_controller.authenticate(credentials)
    await user_controller.update_last_login(user.id)
    access_token_expires = timedelta(minutes=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES)
    expire = datetime.now(timezone.utc) + access_token_expires

    data = JWTOut(
        access_token=create_access_token(
            data=JWTPayload(
                user_id=user.id,
                username=user.username,
                is_superuser=user.is_superuser,
                exp=expire,
            )
        ),
        username=user.username,
    )
    return Success(data=data.model_dump())


@router.get("/userinfo", summary="Get current user info", dependencies=[DependAuth])
async def get_userinfo():
    user_id = CTX_USER_ID.get()
    user_obj = await user_controller.get(id=user_id)
    data = await user_obj.to_dict(exclude_fields=["password"])
    data["avatar"] = "https://avatars.githubusercontent.com/u/54677442?v=4"
    return Success(data=data)


@router.get("/usermenu", summary="Get current user menu", dependencies=[DependAuth])
async def get_user_menu():
    user_id = CTX_USER_ID.get()
    user_obj = await User.filter(id=user_id).first()
    menus: list[Menu] = []
    if user_obj.is_superuser:
        menus = await Menu.all()
    else:
        role_objs: list[Role] = await user_obj.roles
        for role_obj in role_objs:
            menus.extend(await role_obj.menus)
        menus = list(set(menus))

    parent_menus: list[Menu] = []
    for menu in menus:
        if menu.parent_id == 0:
            parent_menus.append(menu)

    res = []
    for parent_menu in parent_menus:
        parent_menu_dict = await parent_menu.to_dict()
        parent_menu_dict["children"] = []
        for menu in menus:
            if menu.parent_id == parent_menu.id:
                parent_menu_dict["children"].append(await menu.to_dict())
        res.append(parent_menu_dict)
    return Success(data=res)


@router.get("/userapi", summary="Get current user API permissions", dependencies=[DependAuth])
async def get_user_api():
    user_id = CTX_USER_ID.get()
    user_obj = await User.filter(id=user_id).first()
    if user_obj.is_superuser:
        api_objs: list[Api] = await Api.all()
        return Success(data=[api.method.lower() + api.path for api in api_objs])

    role_objs: list[Role] = await user_obj.roles
    apis = []
    for role_obj in role_objs:
        api_objs: list[Api] = await role_obj.apis
        apis.extend([api.method.lower() + api.path for api in api_objs])
    return Success(data=list(set(apis)))


@router.post("/update_password", summary="Update password", dependencies=[DependAuth])
async def update_user_password(req_in: UpdatePassword):
    user_id = CTX_USER_ID.get()
    await user_controller.change_password(
        user_id=user_id,
        old_password=req_in.old_password,
        new_password=req_in.new_password,
    )
    return Success(msg="Password updated successfully")


@router.post("/change_password", summary="Change password", dependencies=[DependAuth])
async def change_user_password(req_in: UpdatePassword):
    return await update_user_password(req_in)


@router.post("/forgot_password", summary="Forgot password")
async def forgot_password(req_in: ForgotPasswordRequest):
    await user_controller.forgot_password(req_in)
    return Success(msg="Password reset successfully")


@router.post("/update_profile", summary="Update current user profile", dependencies=[DependAuth])
async def update_current_user_profile(req_in: UpdateCurrentUserProfile):
    user_id = CTX_USER_ID.get()
    user_obj = await user_controller.update_current_profile(
        user_id=user_id,
        email=req_in.email,
        alias=req_in.alias,
        phone=req_in.phone,
    )
    data = await user_obj.to_dict(exclude_fields=["password"])
    data["avatar"] = "https://avatars.githubusercontent.com/u/54677442?v=4"
    return Success(data=data)
