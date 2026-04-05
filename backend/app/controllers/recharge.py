from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from uuid import uuid4

from fastapi.exceptions import HTTPException
from tortoise.transactions import in_transaction

from app.models.admin import User
from app.models.points import PointLedger, RechargeOrder
from app.services.config_store import get_client_feature_payload


@dataclass(frozen=True)
class RechargePackage:
    code: str
    name: str
    amount_fen: int
    points: int
    is_new_user_only: bool = False


class RechargeController:
    packages = (
        RechargePackage(
            code="new_user_special",
            name="新用户尝鲜包",
            amount_fen=10,
            points=30,
            is_new_user_only=True,
        ),
        RechargePackage(
            code="standard_100",
            name="积分加油包",
            amount_fen=990,
            points=100,
        ),
        RechargePackage(
            code="premium_1100",
            name="积分超值包",
            amount_fen=9900,
            points=1100,
        ),
    )

    def list_packages_for_user(
        self,
        user: User,
        *,
        feature_flags: dict | None = None,
    ) -> list[dict]:
        flags = feature_flags or {
            "points_enabled": True,
            "recharge_enabled": True,
        }
        if not flags["recharge_enabled"]:
            return []

        new_user_offer_available = int(user.completed_recharge_count or 0) <= 0
        items = []
        for item in self.packages:
            available = (not item.is_new_user_only) or new_user_offer_available
            items.append(
                {
                    "code": item.code,
                    "name": item.name,
                    "amount_fen": item.amount_fen,
                    "amount_label": self._amount_label(item.amount_fen),
                    "points": item.points,
                    "is_new_user_only": item.is_new_user_only,
                    "available": available,
                    "disabled_reason": "" if available else "仅限新用户首次充值购买",
                }
            )
        return items

    async def create_order(
        self,
        *,
        user_id: int,
        package_code: str,
        pay_method: str,
        source: str,
    ) -> RechargeOrder:
        feature_flags = await get_client_feature_payload()
        if not feature_flags["points_enabled"]:
            raise HTTPException(status_code=403, detail="积分系统暂未开启")
        if not feature_flags["recharge_enabled"]:
            raise HTTPException(status_code=403, detail="积分充值暂未开启")

        if source != "app":
            raise HTTPException(status_code=403, detail="当前仅支持在 App 内发起充值")

        normalized_method = str(pay_method or "").strip().lower()
        supported_methods = self._supported_pay_methods(feature_flags)
        if normalized_method not in supported_methods:
            raise HTTPException(status_code=400, detail="当前未开启该支付方式")

        package = self._get_package(package_code)
        user = await User.get(id=user_id)
        if package.is_new_user_only and int(user.completed_recharge_count or 0) > 0:
            raise HTTPException(status_code=400, detail="新用户专享套餐仅限首次充值使用")

        order = await RechargeOrder.create(
            order_no=self._build_order_no(),
            user_id=user_id,
            package_code=package.code,
            package_name=package.name,
            amount_fen=package.amount_fen,
            points_amount=package.points,
            pay_method=normalized_method,
            status="pending",
            source=source,
            is_new_user_offer=package.is_new_user_only,
            meta={
                "client_action": "pending_payment",
                "payment_hint": self._payment_hint(normalized_method),
            },
        )
        return order

    async def list_orders(
        self,
        *,
        page: int,
        page_size: int,
        user_id: int | None = None,
        status: str | None = None,
    ) -> tuple[int, list[RechargeOrder]]:
        query = RechargeOrder.all()
        if user_id is not None:
            query = query.filter(user_id=user_id)
        if status:
            query = query.filter(status=status)
        total = await query.count()
        items = await query.offset((page - 1) * page_size).limit(page_size).order_by("-created_at", "-id")
        return total, items

    async def serialize_order(self, order: RechargeOrder) -> dict:
        data = await order.to_dict()
        user = await User.filter(id=order.user_id).first()
        meta = order.meta if isinstance(order.meta, dict) else {}
        data["amount_label"] = self._amount_label(order.amount_fen)
        data["pay_method_label"] = self._pay_method_label(order.pay_method)
        data["status_label"] = self._status_label(order.status)
        data["payment_hint"] = str(meta.get("payment_hint") or "")
        data["user"] = (
            {
                "id": user.id,
                "username": user.username,
                "alias": user.alias,
            }
            if user
            else None
        )
        return data

    async def update_order_status(
        self,
        *,
        order_no: str,
        status: str,
        operator_user_id: int | None,
        remark: str | None = None,
    ) -> RechargeOrder:
        normalized_status = str(status or "").strip().lower()
        if normalized_status not in {"paid", "cancelled", "failed"}:
            raise HTTPException(status_code=400, detail="不支持的充值订单状态")

        async with in_transaction() as connection:
            order = await RechargeOrder.filter(order_no=order_no).using_db(connection).select_for_update().first()
            if not order:
                raise HTTPException(status_code=404, detail="充值订单不存在")

            if order.status == normalized_status:
                return order

            if order.status == "paid" and normalized_status != "paid":
                raise HTTPException(status_code=400, detail="已到账订单不支持回退状态")

            if normalized_status == "paid":
                existing = await PointLedger.filter(unique_key=f"recharge_paid:{order.order_no}").using_db(connection).first()
                if existing:
                    order.status = "paid"
                    if order.paid_at is None:
                        order.paid_at = datetime.now()
                    order.operator_user_id = operator_user_id
                    order.remark = remark or order.remark
                    await order.save(
                        using_db=connection,
                        update_fields=["status", "paid_at", "operator_user_id", "remark", "updated_at"],
                    )
                    return order

                user = await User.filter(id=order.user_id).using_db(connection).select_for_update().first()
                if not user:
                    raise HTTPException(status_code=404, detail="用户不存在")

                user.points_balance = int(user.points_balance or 0) + int(order.points_amount or 0)
                user.total_points_recharged = int(user.total_points_recharged or 0) + int(order.points_amount or 0)
                user.completed_recharge_count = int(user.completed_recharge_count or 0) + 1
                await user.save(
                    using_db=connection,
                    update_fields=[
                        "points_balance",
                        "total_points_recharged",
                        "completed_recharge_count",
                    ],
                )

                await PointLedger.create(
                    user_id=user.id,
                    change_amount=int(order.points_amount or 0),
                    balance_after=user.points_balance,
                    direction="credit",
                    transaction_type="recharge",
                    title="积分充值到账",
                    remark=remark or f"{order.package_name} 充值到账",
                    recharge_order_id=order.id,
                    operator_user_id=operator_user_id,
                    unique_key=f"recharge_paid:{order.order_no}",
                    meta={"pay_method": order.pay_method, "order_no": order.order_no},
                    using_db=connection,
                )

                order.status = "paid"
                order.paid_at = datetime.now()
                order.operator_user_id = operator_user_id
                order.remark = remark or order.remark
                await order.save(
                    using_db=connection,
                    update_fields=["status", "paid_at", "operator_user_id", "remark", "updated_at"],
                )
                return order

            order.status = normalized_status
            order.operator_user_id = operator_user_id
            order.remark = remark or order.remark
            await order.save(using_db=connection, update_fields=["status", "operator_user_id", "remark", "updated_at"])
            return order

    def _get_package(self, package_code: str) -> RechargePackage:
        normalized_code = str(package_code or "").strip()
        for item in self.packages:
            if item.code == normalized_code:
                return item
        raise HTTPException(status_code=400, detail="充值套餐不存在")

    def _build_order_no(self) -> str:
        return f"RC{datetime.now().strftime('%Y%m%d%H%M%S')}{uuid4().hex[:8].upper()}"

    @staticmethod
    def _supported_pay_methods(feature_flags: dict) -> set[str]:
        methods: set[str] = set()
        if feature_flags.get("wechat_pay_enabled"):
            methods.add("wechat")
        if feature_flags.get("alipay_pay_enabled"):
            methods.add("alipay")
        return methods

    @staticmethod
    def _payment_hint(pay_method: str) -> str:
        if pay_method == "alipay":
            return "支付宝充值订单已创建，请完成支付后等待系统处理结果"
        return "微信充值订单已创建，请完成支付后等待系统处理结果"

    @staticmethod
    def _amount_label(amount_fen: int) -> str:
        return f"{amount_fen / 100:.2f}元"

    @staticmethod
    def _pay_method_label(pay_method: str) -> str:
        normalized = str(pay_method or "").strip().lower()
        if normalized == "wechat":
            return "微信支付"
        if normalized == "alipay":
            return "支付宝"
        return "未知方式"

    @staticmethod
    def _status_label(status: str) -> str:
        normalized = str(status or "").strip().lower()
        if normalized == "pending":
            return "待支付"
        if normalized == "paid":
            return "已到账"
        if normalized == "cancelled":
            return "已取消"
        if normalized == "failed":
            return "支付失败"
        return "未知状态"


recharge_controller = RechargeController()
