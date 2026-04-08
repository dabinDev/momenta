from datetime import datetime

from pydantic import BaseModel, Field


class InviteCodeCreate(BaseModel):
    remark: str | None = Field(default=None, description="备注")
    max_uses: int | None = Field(default=None, ge=1, description="最大使用次数，默认 100")
    expires_at: datetime | None = Field(default=None, description="过期时间，默认 30 天后")
    owner_user_id: int | None = Field(default=None, description="邀请码归属用户 ID")


class InviteCodeUpdate(BaseModel):
    id: int
    remark: str | None = Field(default=None, description="备注")
    max_uses: int | None = Field(default=None, ge=1, description="最大使用次数")
    expires_at: datetime | None = Field(default=None, description="过期时间")
    is_active: bool | None = Field(default=None, description="是否启用")
    owner_user_id: int | None = Field(default=None, description="邀请码归属用户 ID")
