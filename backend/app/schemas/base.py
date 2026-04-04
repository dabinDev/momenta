from __future__ import annotations

from typing import Any

from fastapi.responses import JSONResponse


SUCCESS_MESSAGE_MAP: dict[str, str] = {
    "OK": "操作成功",
    "Created successfully": "创建成功",
    "Created Successfully": "创建成功",
    "Created Success": "创建成功",
    "Update Successfully": "更新成功",
    "Updated successfully": "更新成功",
    "Updated Successfully": "更新成功",
    "Updated Success": "更新成功",
    "Deleted successfully": "删除成功",
    "Deleted Successfully": "删除成功",
    "Deleted Success": "删除成功",
    "Password updated successfully": "密码修改成功",
    "Password reset successfully": "密码重置成功",
    "Password reset to 123456": "密码已重置为 123456",
    "Reset successfully": "已恢复默认配置",
    "Task marked deleted in local history": "任务已从本地历史记录中删除",
    "History items marked deleted in local history": "历史记录已从本地列表中删除",
    "Model catalog synced": "模型目录已同步",
    "Model applied": "模型已应用",
}

ERROR_MESSAGE_MAP: dict[int, str] = {
    400: "请求参数有误",
    401: "登录已过期，请重新登录",
    403: "当前账号没有权限执行该操作",
    404: "请求的数据不存在或已被删除",
    409: "数据冲突，请检查后重试",
    422: "提交参数校验失败，请检查后重试",
    500: "服务异常，请稍后重试",
    502: "上游服务暂时不可用，请稍后重试",
    503: "服务暂时不可用，请稍后重试",
}


def normalize_success_message(message: str | None) -> str:
    text = str(message or "").strip()
    if not text:
        return "操作成功"
    return SUCCESS_MESSAGE_MAP.get(text, text)


def normalize_error_message(code: int, message: str | None) -> str:
    text = str(message or "").strip()
    if text:
        return text
    return ERROR_MESSAGE_MAP.get(code, "请求处理失败，请稍后重试")


def build_success_payload(
    *,
    code: int = 200,
    msg: str | None = "操作成功",
    data: Any = None,
    **kwargs: Any,
) -> dict[str, Any]:
    payload = {
        "success": True,
        "code": code,
        "msg": normalize_success_message(msg),
        "data": data,
        "error": None,
    }
    payload.update(kwargs)
    return payload


def build_error_payload(
    *,
    code: int = 400,
    msg: str | None = None,
    data: Any = None,
    **kwargs: Any,
) -> dict[str, Any]:
    message = normalize_error_message(code, msg)
    payload = {
        "success": False,
        "code": code,
        "msg": message,
        "data": data,
        "error": {
            "code": code,
            "message": message,
        },
    }
    payload.update(kwargs)
    return payload


class Success(JSONResponse):
    def __init__(
        self,
        code: int = 200,
        msg: str | None = "操作成功",
        data: Any = None,
        **kwargs: Any,
    ) -> None:
        super().__init__(content=build_success_payload(code=code, msg=msg, data=data, **kwargs), status_code=code)


class Fail(JSONResponse):
    def __init__(
        self,
        code: int = 400,
        msg: str | None = None,
        data: Any = None,
        **kwargs: Any,
    ) -> None:
        super().__init__(content=build_error_payload(code=code, msg=msg, data=data, **kwargs), status_code=code)


class SuccessExtra(JSONResponse):
    def __init__(
        self,
        code: int = 200,
        msg: str | None = "操作成功",
        data: Any = None,
        total: int = 0,
        page: int = 1,
        page_size: int = 20,
        **kwargs: Any,
    ) -> None:
        super().__init__(
            content=build_success_payload(
                code=code,
                msg=msg,
                data=data,
                total=total,
                page=page,
                page_size=page_size,
                **kwargs,
            ),
            status_code=code,
        )
