from pydantic import BaseModel, Field


class RechargeOrderCreateIn(BaseModel):
    package_code: str = Field(description="充值套餐编码", min_length=1, max_length=40)
    pay_method: str = Field(description="支付方式", min_length=1, max_length=20)


class RechargeOrderStatusIn(BaseModel):
    order_no: str = Field(description="充值订单号", min_length=1, max_length=40)
    status: str = Field(description="充值订单状态", min_length=1, max_length=20)
    remark: str | None = Field(default=None, description="备注", max_length=255)
