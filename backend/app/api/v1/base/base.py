from datetime import datetime, timedelta, timezone

from fastapi import APIRouter

from app.controllers.points import points_controller
from app.controllers.user import user_controller
from app.core.ctx import CTX_USER_ID
from app.core.dependency import DependAuth
from app.log import logger
from app.models.admin import Api, Dept, Menu, Role, User
from app.schemas.base import Success
from app.schemas.login import CredentialsSchema, JWTPayload, JWTOut
from app.schemas.users import ForgotPasswordRequest, RegisterRequest, UpdateCurrentUserProfile, UpdatePassword
from app.services.config_store import get_client_feature_flags, get_client_feature_payload
from app.settings import settings
from app.utils.jwt_utils import create_access_token

router = APIRouter()
_MENU_PATH_BLACKLIST = {"/system", "/top-menu"}


async def _serialize_current_user(user_obj: User) -> dict:
    data = await user_obj.to_dict(m2m=True, exclude_fields=["password"])
    data["avatar"] = "https://avatars.githubusercontent.com/u/54677442?v=4"
    data["roles"] = data.get("roles") or []
    feature_flags = await get_client_feature_flags()
    feature_payload = await get_client_feature_payload()
    points_summary = points_controller.build_user_summary(user_obj, feature_flags=feature_payload)
    data["feature_flags"] = feature_flags
    data["points_enabled"] = feature_payload["points_enabled"]
    data["recharge_enabled"] = feature_payload["recharge_enabled"]
    data["wechat_pay_enabled"] = feature_payload["wechat_pay_enabled"]
    data["alipay_pay_enabled"] = feature_payload["alipay_pay_enabled"]
    data["payment_enabled"] = feature_payload["payment_enabled"]
    data["payment_methods"] = feature_payload["payment_methods"]
    data["points_summary"] = points_summary
    data["video_generation_cost"] = points_summary["video_generation_cost"]
    data["new_user_recharge_available"] = points_summary["new_user_recharge_available"]

    dept = await Dept.filter(id=user_obj.dept_id).first() if user_obj.dept_id else None
    data["dept"] = await dept.to_dict() if dept else {}
    return data


@router.post("/access_token", summary="获取访问令牌")
async def login_access_token(credentials: CredentialsSchema):
    user: User = await user_controller.authenticate(credentials)
    try:
        await user_controller.update_last_login(user.id)
    except Exception as exc:
        logger.warning(f"skip last_login update for user_id={user.id}: {exc}")
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


@router.get("/userinfo", summary="获取当前用户信息", dependencies=[DependAuth])
async def get_userinfo():
    user_id = CTX_USER_ID.get()
    user_obj = await user_controller.get(id=user_id)
    return Success(data=await _serialize_current_user(user_obj))


@router.get("/usermenu", summary="获取当前用户菜单", dependencies=[DependAuth])
async def get_user_menu():
    user_id = CTX_USER_ID.get()
    user_obj = await User.filter(id=user_id).first()
    menus: list[Menu] = []
    if user_obj.is_superuser:
        menus = await Menu.filter(is_hidden=False).all()
    else:
        role_objs: list[Role] = await user_obj.roles
        for role_obj in role_objs:
            menus.extend(await role_obj.menus)
        menus = [menu for menu in list(set(menus)) if not menu.is_hidden]
    menus = [menu for menu in menus if menu.path not in _MENU_PATH_BLACKLIST]

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


@router.get("/userapi", summary="获取当前用户接口权限", dependencies=[DependAuth])
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


@router.post("/update_password", summary="修改密码", dependencies=[DependAuth])
async def update_user_password(req_in: UpdatePassword):
    user_id = CTX_USER_ID.get()
    await user_controller.change_password(
        user_id=user_id,
        old_password=req_in.old_password,
        new_password=req_in.new_password,
    )
    return Success(msg="密码修改成功")


@router.post("/change_password", summary="修改密码", dependencies=[DependAuth])
async def change_user_password(req_in: UpdatePassword):
    return await update_user_password(req_in)


@router.post("/forgot_password", summary="忘记密码")
async def forgot_password(req_in: ForgotPasswordRequest):
    await user_controller.forgot_password(req_in)
    return Success(msg="密码重置成功")


@router.post("/register", summary="注册账号")
async def register(req_in: RegisterRequest):
    user_obj, reward_summary = await user_controller.register_user(req_in)
    return Success(
        msg="注册成功",
        data={
            "id": user_obj.id,
            "username": user_obj.username,
            "email": user_obj.email,
            "reward_summary": reward_summary,
            "personal_invite_code": reward_summary.get("personal_invite_code"),
        },
    )


@router.post("/update_profile", summary="更新当前用户资料", dependencies=[DependAuth])
async def update_current_user_profile(req_in: UpdateCurrentUserProfile):
    user_id = CTX_USER_ID.get()
    user_obj = await user_controller.update_current_profile(
        user_id=user_id,
        email=req_in.email,
        alias=req_in.alias,
        phone=req_in.phone,
    )
    return Success(data=await _serialize_current_user(user_obj))
