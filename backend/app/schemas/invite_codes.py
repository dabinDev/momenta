from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class InviteCodeCreate(BaseModel):
    remark: Optional[str] = Field(default=None, description="备注")
    max_uses: int = Field(default=1, ge=1, description="最大使用次数")
    expires_at: Optional[datetime] = Field(default=None, description="过期时间")


class InviteCodeUpdate(BaseModel):
    id: int
    remark: Optional[str] = Field(default=None, description="备注")
    max_uses: int = Field(default=1, ge=1, description="最大使用次数")
    expires_at: Optional[datetime] = Field(default=None, description="过期时间")
    is_active: bool = Field(default=True, description="是否可用")
