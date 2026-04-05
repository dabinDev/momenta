from pydantic import BaseModel, Field


class PointGiftIn(BaseModel):
    user_id: int = Field(description="用户 ID")
    points: int = Field(description="赠送积分", ge=1)
    remark: str | None = Field(default=None, description="赠送备注", max_length=255)


class PointLedgerListQuery(BaseModel):
    page: int = Field(default=1, ge=1, description="页码")
    page_size: int = Field(default=20, ge=1, le=100, description="每页数量")
    user_id: int | None = Field(default=None, description="用户 ID")
    transaction_type: str | None = Field(default=None, description="流水类型")
