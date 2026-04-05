from tortoise import fields

from .base import BaseModel, TimestampMixin


class PointLedger(BaseModel, TimestampMixin):
    user_id = fields.BigIntField(description="User ID", index=True)
    change_amount = fields.IntField(description="Points delta")
    balance_after = fields.IntField(description="Balance after change")
    direction = fields.CharField(max_length=16, description="credit or debit", index=True)
    transaction_type = fields.CharField(max_length=40, description="Transaction type", index=True)
    title = fields.CharField(max_length=80, description="Transaction title")
    remark = fields.CharField(max_length=255, null=True, description="Remark")
    related_user_id = fields.BigIntField(null=True, description="Related user ID", index=True)
    invite_code_id = fields.BigIntField(null=True, description="Invite code ID", index=True)
    recharge_order_id = fields.BigIntField(null=True, description="Recharge order ID", index=True)
    task_id = fields.BigIntField(null=True, description="Task ID", index=True)
    operator_user_id = fields.BigIntField(null=True, description="Operator user ID", index=True)
    unique_key = fields.CharField(max_length=120, null=True, unique=True, description="Idempotent unique key")
    meta = fields.JSONField(null=True, description="Extra metadata")

    class Meta:
        table = "point_ledger"


class RechargeOrder(BaseModel, TimestampMixin):
    order_no = fields.CharField(max_length=40, unique=True, description="Order number", index=True)
    user_id = fields.BigIntField(description="User ID", index=True)
    package_code = fields.CharField(max_length=40, description="Recharge package code", index=True)
    package_name = fields.CharField(max_length=80, description="Recharge package name")
    amount_fen = fields.IntField(description="Amount in fen")
    points_amount = fields.IntField(description="Points amount")
    pay_method = fields.CharField(max_length=20, description="Pay method", index=True)
    status = fields.CharField(max_length=20, default="pending", description="Order status", index=True)
    source = fields.CharField(max_length=20, default="app", description="Order source", index=True)
    is_new_user_offer = fields.BooleanField(default=False, description="Whether it is a new user offer", index=True)
    paid_at = fields.DatetimeField(null=True, description="Paid time", index=True)
    operator_user_id = fields.BigIntField(null=True, description="Operator user ID", index=True)
    remark = fields.CharField(max_length=255, null=True, description="Remark")
    meta = fields.JSONField(null=True, description="Extra metadata")

    class Meta:
        table = "recharge_order"
