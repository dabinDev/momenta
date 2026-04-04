from __future__ import annotations

from fastapi.exceptions import HTTPException, RequestValidationError, ResponseValidationError
from fastapi.requests import Request
from fastapi.responses import JSONResponse
from tortoise.exceptions import DoesNotExist, IntegrityError

from app.schemas.base import build_error_payload


class SettingNotFound(Exception):
    pass


DETAIL_MAP: dict[str, str] = {
    "Missing token": "未检测到登录信息，请重新登录",
    "Authentication failed": "登录状态校验失败，请重新登录",
    "Invalid token": "登录凭证无效，请重新登录",
    "Login expired": "登录已过期，请重新登录",
    "Authentication error": "登录校验失败，请稍后重试",
    "The user is not bound to a role": "当前账号未分配角色，请联系管理员",
    "Invalid username": "用户名不存在",
    "Incorrect password": "密码错误",
    "User is disabled": "账号已被禁用",
    "Superuser password cannot be reset here": "超级管理员密码不支持在这里重置",
    "Old password is incorrect": "原密码不正确",
    "User not found": "未找到该用户",
    "Email already exists": "邮箱已存在",
    "Username already exists": "用户名已存在",
    "Invalid invite code": "邀请码无效",
    "Invite code is disabled": "邀请码已停用",
    "Invite code has expired": "邀请码已过期",
    "Invite code has been used up": "邀请码次数已用完",
    "Failed to generate invite code": "邀请码生成失败，请稍后重试",
    "Active release must provide download URL": "启用中的版本必须填写下载地址",
    "Task video is not ready": "视频尚未生成完成，请稍后再试",
    "Failed to download task video": "视频下载失败，请稍后重试",
}


def normalize_error_message(detail: object, *, fallback: str = "请求处理失败，请稍后重试") -> str:
    if detail is None:
        return fallback

    message = str(detail).strip()
    if not message:
        return fallback

    if message in DETAIL_MAP:
        return DETAIL_MAP[message]
    if message.startswith("Permission denied method:"):
        return "当前账号没有访问该功能的权限"
    if message.startswith("Object has not found"):
        return "请求的数据不存在或已被删除"
    if message.startswith("RequestValidationError"):
        return "提交参数校验失败，请检查后重试"
    if message.startswith("ResponseValidationError"):
        return "服务返回异常，请稍后重试"
    if message.startswith("IntegrityError"):
        return "数据写入失败，可能存在重复或关联冲突"
    if message.startswith("{") or message.startswith("["):
        return fallback
    return message


async def DoesNotExistHandle(req: Request, exc: DoesNotExist) -> JSONResponse:
    content = build_error_payload(
        code=404,
        msg=normalize_error_message(
            f"Object has not found, exc: {exc}, query_params: {req.query_params}",
            fallback="请求的数据不存在或已被删除",
        ),
    )
    return JSONResponse(content=content, status_code=404)


async def IntegrityHandle(_: Request, exc: IntegrityError) -> JSONResponse:
    content = build_error_payload(code=500, msg=normalize_error_message(f"IntegrityError: {exc}"))
    return JSONResponse(content=content, status_code=500)


async def HttpExcHandle(_: Request, exc: HTTPException) -> JSONResponse:
    content = build_error_payload(code=exc.status_code, msg=normalize_error_message(exc.detail), data=None)
    return JSONResponse(content=content, status_code=exc.status_code)


async def RequestValidationHandle(_: Request, exc: RequestValidationError) -> JSONResponse:
    content = build_error_payload(code=422, msg=normalize_error_message(f"RequestValidationError, {exc}"))
    return JSONResponse(content=content, status_code=422)


async def ResponseValidationHandle(_: Request, exc: ResponseValidationError) -> JSONResponse:
    content = build_error_payload(code=500, msg=normalize_error_message(f"ResponseValidationError, {exc}"))
    return JSONResponse(content=content, status_code=500)
