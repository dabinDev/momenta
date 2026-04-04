from __future__ import annotations

from typing import Any

from fastapi import FastAPI
from fastapi.openapi.utils import get_openapi

INFO_TITLE = "拾光视频统一服务端接口"
INFO_DESCRIPTION = (
    "为拾光视频 App、H5 与管理后台统一提供认证、创作、任务、模型、版本发布与运营能力。"
    "所有接口统一返回 `success`、`code`、`msg`、`data`、`error` 五个核心字段，"
    "前端页面只展示后端返回的中文提示信息。"
)

TAG_DESCRIPTIONS: dict[str, str] = {
    "基础模块": "登录、注册、当前用户、菜单权限等基础能力接口。",
    "应用配置": "统一维护文案、视频、语音模型与相关默认配置。",
    "版本发布": "维护 App 版本、下载地址、更新说明与强制更新策略。",
    "创作任务": "图片上传、提示词生成、视频生成、任务状态与历史记录接口。",
    "语音识别": "语音转文字能力接口。",
    "邀请码管理": "邀请码的生成、启用停用、删除与查询接口。",
    "用户管理": "后台用户、角色、封禁、调用统计等接口。",
    "角色管理": "角色列表、授权菜单、接口权限相关接口。",
    "菜单管理": "后台菜单树结构维护接口。",
    "接口管理": "后台接口权限元数据维护接口。",
    "部门管理": "部门树与部门成员归属维护接口。",
    "审计日志": "操作日志、审计追踪与接口访问记录接口。",
    "视频任务": "后台任务列表、任务重试、视频下载接口。",
    "语音日志": "语音识别日志列表与统计接口。",
    "模型目录": "模型同步、推荐、应用与查询接口。",
    "AI调试": "面向后台运营与排查的 AI 调试接口。",
}

TAG_NAME_ALIASES: dict[str, str] = {
    "基础模块": "基础模块",
    "应用配置": "应用配置",
    "版本发布": "版本发布",
    "创作任务": "创作任务",
    "语音识别": "语音识别",
    "邀请码管理": "邀请码管理",
    "用户管理": "用户管理",
    "角色管理": "角色管理",
    "菜单管理": "菜单管理",
    "接口管理": "接口管理",
    "部门管理": "部门管理",
    "审计日志": "审计日志",
    "视频任务": "视频任务",
    "语音日志": "语音日志",
    "模型目录": "模型目录",
    "AI调试": "AI调试",
    "用户模块": "用户管理",
    "角色模块": "角色管理",
    "菜单模块": "菜单管理",
    "API模块": "接口管理",
    "部门模块": "部门管理",
    "审计日志模块": "审计日志",
    "Task Admin": "视频任务",
    "Voice Log Admin": "语音日志",
    "AI Debug Admin": "AI调试",
    "App Release Admin": "版本发布",
}

RESOURCE_LABELS: dict[str, str] = {
    "user": "用户",
    "role": "角色",
    "menu": "菜单",
    "api": "接口",
    "dept": "部门",
    "invite_code": "邀请码",
    "app_config": "应用配置",
    "app_release": "版本发布",
    "auditlog": "审计日志",
    "task": "视频任务",
    "voice_log": "语音日志",
    "model_catalog": "模型目录",
}

COMMON_PARAM_DESCRIPTIONS: dict[str, str] = {
    "page": "页码，从 1 开始。",
    "page_size": "每页数量。",
    "limit": "每页数量。",
    "filter": "任务筛选条件。",
    "keyword": "搜索关键词。",
    "path": "接口或菜单路径。",
    "summary": "接口摘要或描述。",
    "tags": "接口所属模块。",
    "username": "用户名。",
    "email": "邮箱。",
    "phone": "手机号。",
    "role_name": "角色名称。",
    "dept_id": "部门 ID。",
    "user_id": "用户 ID。",
    "task_id": "任务 ID。",
    "service_type": "服务类型，可选文案、视频或语音。",
    "scope": "配置作用域，可选全局或用户私有通道。",
    "model_id": "模型标识。",
    "platform": "平台类型，例如 android。",
    "channel": "发布渠道。",
    "current_version": "当前版本号。",
    "currentVersion": "当前版本号。",
    "current_build_number": "当前构建号。",
    "currentBuildNumber": "当前构建号。",
    "code": "邀请码。",
    "status": "状态筛选值。",
    "task_type": "任务类型。",
    "include_deleted": "是否包含已删除记录。",
    "method": "请求方法。",
    "module": "所属模块。",
    "start_time": "开始时间。",
    "end_time": "结束时间。",
    "id": "主键 ID。",
    "menu_id": "菜单 ID。",
    "role_id": "角色 ID。",
    "api_id": "接口 ID。",
    "invite_code_id": "邀请码 ID。",
}

COMMON_PROPERTY_DESCRIPTIONS: dict[str, str] = {
    "success": "请求是否成功。",
    "code": "业务状态码。",
    "msg": "中文提示信息。",
    "data": "业务数据。",
    "error": "错误对象。",
    "message": "错误说明。",
    "page": "当前页码。",
    "page_size": "每页数量。",
    "total": "总数量。",
    "username": "用户名。",
    "email": "邮箱。",
    "alias": "昵称。",
    "phone": "手机号。",
    "password": "密码。",
    "old_password": "旧密码。",
    "new_password": "新密码。",
    "invite_code": "邀请码。",
    "inviteCode": "邀请码。",
    "user_id": "用户 ID。",
    "role_id": "角色 ID。",
    "dept_id": "部门 ID。",
    "menu_ids": "菜单 ID 列表。",
    "api_ids": "接口 ID 列表。",
    "provider_base_url": "全局平台服务地址。",
    "provider_api_key": "全局平台密钥。",
    "llm_base_url": "文案服务地址。",
    "llm_api_key": "文案服务密钥。",
    "llm_model": "文案模型名称。",
    "video_base_url": "视频服务地址。",
    "video_api_key": "视频服务密钥。",
    "video_model": "视频模型名称。",
    "speech_base_url": "语音服务地址。",
    "speech_api_key": "语音服务密钥。",
    "speech_model": "语音模型名称。",
    "image_base_url": "图片生成服务地址。",
    "image_api_key": "图片生成服务密钥。",
    "image_model": "图片生成模型名称。",
    "allow_private_ai_override": "是否允许当前用户使用专属 AI 通道。",
    "override_enabled": "是否启用当前用户的专属 AI 覆盖配置。",
    "using_private_override": "当前是否实际命中用户专属 AI 通道。",
    "config_source": "当前实际生效的配置来源。",
    "text": "文本内容。",
    "input_text": "原始输入内容。",
    "polished_text": "校准后的文本内容。",
    "prompt": "最终用于生成的提示词。",
    "prompt_template_key": "提示词模板标识。",
    "video_template_key": "视频模板标识。",
    "reference_link": "参考视频链接。",
    "reference_video_path": "参考视频文件路径。",
    "supplemental_text": "补充说明。",
    "images": "参考图片地址列表。",
    "duration": "视频时长，单位秒。",
    "status": "状态。",
    "task_type": "任务类型。",
    "task_source": "任务来源。",
    "video_url": "视频地址。",
    "cover_image_url": "封面图地址。",
    "progress": "任务进度。",
    "error_code": "错误码。",
    "error_message": "错误信息。",
    "platform": "平台类型。",
    "channel": "发布渠道。",
    "version_name": "版本号。",
    "build_number": "构建号。",
    "download_url": "下载地址。",
    "force_update": "是否强制更新。",
    "is_active": "是否启用。",
    "published_at": "发布时间。",
    "scope": "配置作用域，可选全局或用户私有通道。",
    "service_type": "服务类型。",
    "model_id": "模型标识。",
    "display_name": "显示名称。",
    "supports_video": "是否支持视频生成。",
    "supports_image_input": "是否支持图片输入。",
    "price_level": "价格等级，数值越小越便宜。",
    "speed_level": "速度等级，数值越大越快。",
    "quality_level": "质量等级，数值越大越好。",
    "capability_score": "综合能力评分。",
}

SUMMARY_OVERRIDES: dict[tuple[str, str], str] = {
    ("GET", "/api/v1/app_config/global"): "获取全局 AI 配置",
    ("POST", "/api/v1/app_config/global"): "更新全局 AI 配置",
    ("POST", "/api/v1/app_config/global/reset"): "重置全局 AI 配置",
    ("GET", "/api/v1/app_config/effective"): "获取用户实际生效的 AI 配置",
    ("GET", "/api/app/releases/latest"): "获取最新版本信息",
    ("POST", "/api/v1/base/access_token"): "获取登录令牌",
    ("GET", "/api/v1/base/userinfo"): "获取当前用户信息",
    ("GET", "/api/v1/base/usermenu"): "获取当前用户菜单",
    ("GET", "/api/v1/base/userapi"): "获取当前用户接口权限",
    ("POST", "/api/v1/base/update_password"): "修改当前用户密码",
    ("POST", "/api/v1/base/change_password"): "修改当前用户密码",
    ("POST", "/api/v1/base/forgot_password"): "重置登录密码",
    ("POST", "/api/v1/base/register"): "用户注册",
    ("POST", "/api/v1/base/update_profile"): "更新当前用户资料",
    ("POST", "/api/upload-images"): "上传参考图片",
    ("POST", "/api/upload-reference-video"): "上传参考视频",
    ("POST", "/api/correct-text"): "校准输入文本",
    ("POST", "/api/generate-prompt"): "生成创作提示词",
    ("GET", "/api/prompt-templates"): "获取提示词模板列表",
    ("GET", "/api/video-templates"): "获取视频模板列表",
    ("GET", "/api/create-workbench"): "获取 AI 创作工作台配置",
    ("POST", "/api/tasks"): "创建简单视频任务",
    ("POST", "/api/starter-tasks"): "创建入门视频任务",
    ("POST", "/api/custom-tasks"): "创建自定义视频任务",
    ("GET", "/api/tasks"): "获取当前用户任务列表",
    ("GET", "/api/tasks/summary"): "获取当前用户任务统计",
    ("GET", "/api/tasks/{task_id}"): "获取任务详情",
    ("POST", "/api/tasks/{task_id}/retry"): "重新生成任务",
    ("GET", "/api/tasks/{task_id}/download"): "下载任务视频",
    ("DELETE", "/api/tasks/{task_id}"): "删除单条历史任务",
    ("DELETE", "/api/tasks"): "清空历史任务",
    ("POST", "/api/voice/transcribe"): "语音转文字",
    ("POST", "/api/v1/ai_debug/upload_images"): "上传调试图片",
    ("POST", "/api/v1/ai_debug/polish_text"): "调试文本校准",
    ("POST", "/api/v1/ai_debug/generate_prompt"): "调试提示词生成",
    ("POST", "/api/v1/ai_debug/create_task"): "调试视频任务创建",
    ("POST", "/api/v1/ai_debug/transcribe"): "调试语音识别",
}


def apply_custom_openapi(app: FastAPI) -> None:
    def custom_openapi() -> dict[str, Any]:
        if app.openapi_schema:
            return app.openapi_schema

        schema = get_openapi(
            title=INFO_TITLE,
            version=app.version,
            description=INFO_DESCRIPTION,
            routes=app.routes,
        )

        schema.setdefault("info", {})
        schema["info"]["title"] = INFO_TITLE
        schema["info"]["description"] = INFO_DESCRIPTION

        tags = schema.setdefault("tags", [])
        existing = {item.get("name"): item for item in tags if isinstance(item, dict)}
        for name, description in TAG_DESCRIPTIONS.items():
            if name in existing:
                existing[name]["description"] = description
            else:
                tags.append({"name": name, "description": description})

        for path, path_item in schema.get("paths", {}).items():
            if not isinstance(path_item, dict):
                continue
            for method, operation in path_item.items():
                if method.upper() not in {"GET", "POST", "PUT", "PATCH", "DELETE"}:
                    continue
                if isinstance(operation, dict):
                    _normalize_operation(path, method.upper(), operation)

        for schema_name, component in schema.get("components", {}).get("schemas", {}).items():
            if isinstance(component, dict):
                _normalize_schema(component, schema_name=schema_name)

        app.openapi_schema = schema
        return app.openapi_schema

    app.openapi = custom_openapi


def _normalize_operation(path: str, method: str, operation: dict[str, Any]) -> None:
    operation["summary"] = normalize_route_summary(path, method, operation.get("summary"))
    operation["description"] = operation.get("description") or (
        f"{operation['summary']}。接口统一返回 success、code、msg、data、error 五个核心字段。"
    )
    if isinstance(operation.get("tags"), list):
        operation["tags"] = [normalize_route_tag(tag) for tag in operation["tags"]]

    for parameter in operation.get("parameters", []):
        if not isinstance(parameter, dict):
            continue
        name = str(parameter.get("name") or "").strip()
        if not name:
            continue
        if _needs_translation(parameter.get("description")):
            parameter["description"] = COMMON_PARAM_DESCRIPTIONS.get(name, f"{name} 参数。")

    for status_code, response in operation.get("responses", {}).items():
        if not isinstance(response, dict):
            continue
        is_success = str(status_code).startswith("2")
        response["description"] = "请求成功" if is_success else "请求失败"
        for content in response.get("content", {}).values():
            if not isinstance(content, dict):
                continue
            content.setdefault(
                "example",
                {
                    "success": is_success,
                    "code": 200 if is_success else 400,
                    "msg": "操作成功" if is_success else "请求失败",
                    "data": {} if is_success else None,
                    "error": None
                    if is_success
                    else {
                        "code": 400,
                        "message": "请求失败",
                    },
                },
            )


def _normalize_schema(schema: dict[str, Any], *, schema_name: str = "") -> None:
    properties = schema.get("properties")
    if isinstance(properties, dict):
        for field_name, property_schema in properties.items():
            if not isinstance(property_schema, dict):
                continue
            if _needs_translation(property_schema.get("description")):
                property_schema["description"] = COMMON_PROPERTY_DESCRIPTIONS.get(
                    field_name,
                    f"{field_name} 字段。",
                )
            if isinstance(property_schema.get("items"), dict):
                _normalize_schema(property_schema["items"], schema_name=f"{schema_name}.{field_name}")
            for key in ("allOf", "anyOf", "oneOf"):
                for item in property_schema.get(key, []):
                    if isinstance(item, dict):
                        _normalize_schema(item, schema_name=f"{schema_name}.{field_name}")

    for key in ("allOf", "anyOf", "oneOf"):
        for item in schema.get(key, []):
            if isinstance(item, dict):
                _normalize_schema(item, schema_name=schema_name)

    if _needs_translation(schema.get("description")) and schema_name in COMMON_PROPERTY_DESCRIPTIONS:
        schema["description"] = COMMON_PROPERTY_DESCRIPTIONS[schema_name]


def _translate_summary(path: str, method: str, original: Any) -> str:
    override = SUMMARY_OVERRIDES.get((method, path))
    if override:
        return override

    if not _needs_translation(original):
        return str(original).strip()

    segments = [segment for segment in path.strip("/").split("/") if segment]
    if len(segments) >= 4 and segments[:2] == ["api", "v1"]:
        resource = RESOURCE_LABELS.get(segments[2], segments[2])
        action = segments[3]
        if action == "list":
            return f"获取{resource}列表"
        if action == "get":
            return f"获取{resource}详情"
        if action == "create":
            return f"创建{resource}"
        if action == "update":
            return f"更新{resource}"
        if action == "delete":
            return f"删除{resource}"
        if action == "authorized":
            return "查看角色权限" if method == "GET" else "更新角色权限"
        if action == "reset_password":
            return "重置用户密码"
        if action == "metrics":
            return "获取用户调用统计"
        if action == "toggle":
            return "切换邀请码状态"
        if action == "sync":
            return f"同步{resource}"
        if action == "recommend":
            return "推荐最优模型"
        if action == "apply":
            return "应用推荐模型"

    return "接口调用"


def normalize_route_summary(path: str, method: str, summary: Any) -> str:
    return _translate_summary(path, method, summary)


def normalize_route_tag(tag: Any) -> str:
    value = str(tag or "").strip()
    if not value:
        return "接口管理"
    return TAG_NAME_ALIASES.get(value, value)


def _needs_translation(value: Any) -> bool:
    text = str(value or "").strip()
    if not text:
        return True
    return text.isascii()
