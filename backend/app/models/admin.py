from tortoise import fields

from app.schemas.menus import MenuType

from .base import BaseModel, TimestampMixin
from .enums import MethodType


class User(BaseModel, TimestampMixin):
    username = fields.CharField(max_length=20, unique=True, description="Username", index=True)
    alias = fields.CharField(max_length=30, null=True, description="Alias", index=True)
    email = fields.CharField(max_length=255, unique=True, description="Email", index=True)
    phone = fields.CharField(max_length=20, null=True, description="Phone", index=True)
    password = fields.CharField(max_length=128, null=True, description="Password")
    is_active = fields.BooleanField(default=True, description="Is active", index=True)
    is_superuser = fields.BooleanField(default=False, description="Is superuser", index=True)
    allow_private_ai_override = fields.BooleanField(
        default=False,
        description="Whether private AI override is allowed",
        index=True,
    )
    last_login = fields.DatetimeField(null=True, description="Last login time", index=True)
    registration_source = fields.CharField(max_length=20, default="admin", description="Registration source", index=True)
    invite_code_id = fields.BigIntField(null=True, description="Invite code ID", index=True)
    points_balance = fields.IntField(default=0, description="Current points balance")
    total_points_spent = fields.IntField(default=0, description="Total spent points")
    total_points_recharged = fields.IntField(default=0, description="Total recharged points")
    completed_recharge_count = fields.IntField(default=0, description="Completed recharge count")
    roles = fields.ManyToManyField("models.Role", related_name="user_roles", db_constraint=False)
    dept_id = fields.IntField(null=True, description="Department ID", index=True)

    class Meta:
        table = "user"


class Role(BaseModel, TimestampMixin):
    name = fields.CharField(max_length=20, unique=True, description="Role name", index=True)
    desc = fields.CharField(max_length=500, null=True, description="Role description")
    menus = fields.ManyToManyField("models.Menu", related_name="role_menus", db_constraint=False)
    apis = fields.ManyToManyField("models.Api", related_name="role_apis", db_constraint=False)

    class Meta:
        table = "role"


class Api(BaseModel, TimestampMixin):
    path = fields.CharField(max_length=100, description="API path", index=True)
    method = fields.CharEnumField(MethodType, description="Request method", index=True)
    summary = fields.CharField(max_length=500, description="Request summary", index=True)
    tags = fields.CharField(max_length=100, description="API tags", index=True)

    class Meta:
        table = "api"


class Menu(BaseModel, TimestampMixin):
    name = fields.CharField(max_length=20, description="Menu name", index=True)
    remark = fields.JSONField(null=True, description="Reserved field")
    menu_type = fields.CharEnumField(MenuType, null=True, description="Menu type")
    icon = fields.CharField(max_length=100, null=True, description="Menu icon")
    path = fields.CharField(max_length=100, description="Menu path", index=True)
    order = fields.IntField(default=0, description="Display order", index=True)
    parent_id = fields.IntField(default=0, description="Parent menu ID", index=True)
    is_hidden = fields.BooleanField(default=False, description="Is hidden")
    component = fields.CharField(max_length=100, description="Component path")
    keepalive = fields.BooleanField(default=True, description="Keep alive")
    redirect = fields.CharField(max_length=100, null=True, description="Redirect path")

    class Meta:
        table = "menu"


class Dept(BaseModel, TimestampMixin):
    name = fields.CharField(max_length=20, unique=True, description="Department name", index=True)
    desc = fields.CharField(max_length=500, null=True, description="Department description")
    is_deleted = fields.BooleanField(default=False, description="Soft deleted", index=True)
    order = fields.IntField(default=0, description="Display order", index=True)
    parent_id = fields.IntField(default=0, max_length=10, description="Parent department ID", index=True)

    class Meta:
        table = "dept"


class DeptClosure(BaseModel, TimestampMixin):
    ancestor = fields.IntField(description="Ancestor department", index=True)
    descendant = fields.IntField(description="Descendant department", index=True)
    level = fields.IntField(default=0, description="Tree depth", index=True)


class AuditLog(BaseModel, TimestampMixin):
    user_id = fields.IntField(description="User ID", index=True)
    username = fields.CharField(max_length=64, default="", description="Username", index=True)
    module = fields.CharField(max_length=64, default="", description="Module", index=True)
    summary = fields.CharField(max_length=128, default="", description="Request summary", index=True)
    method = fields.CharField(max_length=10, default="", description="Request method", index=True)
    path = fields.CharField(max_length=255, default="", description="Request path", index=True)
    status = fields.IntField(default=-1, description="HTTP status", index=True)
    response_time = fields.IntField(default=0, description="Response time (ms)", index=True)
    request_args = fields.JSONField(null=True, description="Request arguments")
    response_body = fields.JSONField(null=True, description="Response body")


class InviteCode(BaseModel, TimestampMixin):
    code = fields.CharField(max_length=64, unique=True, description="Invite code", index=True)
    remark = fields.CharField(max_length=255, null=True, description="Remark")
    max_uses = fields.IntField(default=1, description="Maximum uses", index=True)
    used_count = fields.IntField(default=0, description="Used count", index=True)
    is_active = fields.BooleanField(default=True, description="Is active", index=True)
    expires_at = fields.DatetimeField(null=True, description="Expiration time", index=True)
    created_by_user_id = fields.BigIntField(null=True, description="Creator user ID", index=True)
    owner_user_id = fields.BigIntField(null=True, description="Invite owner user ID", index=True)

    class Meta:
        table = "invite_code"
