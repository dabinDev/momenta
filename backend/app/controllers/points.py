from __future__ import annotations

from uuid import uuid4

from fastapi.exceptions import HTTPException
from tortoise.transactions import in_transaction

from app.models.admin import InviteCode, User
from app.models.points import PointLedger
from app.services.config_store import get_client_feature_payload


class PointsController:
    invite_reward_points = 30

    async def get_feature_flags(self) -> dict:
        return await get_client_feature_payload()

    async def get_user_summary(self, *, user_id: int) -> dict:
        user = await User.get(id=user_id)
        return self.build_user_summary(user, feature_flags=await self.get_feature_flags())

    def build_user_summary(
        self,
        user: User,
        *,
        feature_flags: dict | None = None,
    ) -> dict:
        flags = feature_flags or {
            "points_enabled": True,
            "recharge_enabled": True,
            "wechat_pay_enabled": True,
            "alipay_pay_enabled": False,
            "video_generation_cost": 10,
            "payment_methods": ["wechat"],
            "payment_enabled": True,
        }
        points_enabled = bool(flags["points_enabled"])
        recharge_enabled = bool(flags["recharge_enabled"])
        wechat_pay_enabled = bool(flags.get("wechat_pay_enabled", False))
        alipay_pay_enabled = bool(flags.get("alipay_pay_enabled", False))
        payment_methods = list(flags.get("payment_methods") or [])
        payment_enabled = bool(flags.get("payment_enabled", False))
        video_generation_cost = int(flags.get("video_generation_cost", 10) or 0)

        return {
            "points_balance": int(user.points_balance or 0),
            "total_points_spent": int(user.total_points_spent or 0),
            "total_points_recharged": int(user.total_points_recharged or 0),
            "completed_recharge_count": int(user.completed_recharge_count or 0),
            "points_enabled": points_enabled,
            "recharge_enabled": recharge_enabled,
            "wechat_pay_enabled": wechat_pay_enabled,
            "alipay_pay_enabled": alipay_pay_enabled,
            "payment_methods": payment_methods,
            "payment_enabled": payment_enabled,
            "video_generation_cost": video_generation_cost if points_enabled else 0,
            "new_user_recharge_available": recharge_enabled
            and payment_enabled
            and int(user.completed_recharge_count or 0) <= 0,
        }

    async def list_ledgers(
        self,
        *,
        page: int,
        page_size: int,
        user_id: int | None = None,
        transaction_type: str | None = None,
    ) -> tuple[int, list[PointLedger]]:
        query = PointLedger.all()
        if user_id is not None:
            query = query.filter(user_id=user_id)
        if transaction_type:
            query = query.filter(transaction_type=transaction_type)
        total = await query.count()
        items = await query.offset((page - 1) * page_size).limit(page_size).order_by("-created_at", "-id")
        return total, items

    async def serialize_ledger(self, ledger: PointLedger) -> dict:
        data = await ledger.to_dict()
        user = await User.filter(id=ledger.user_id).first()
        related_user = await User.filter(id=ledger.related_user_id).first() if ledger.related_user_id else None
        data["user"] = (
            {
                "id": user.id,
                "username": user.username,
                "alias": user.alias,
            }
            if user
            else None
        )
        data["related_user"] = (
            {
                "id": related_user.id,
                "username": related_user.username,
                "alias": related_user.alias,
            }
            if related_user
            else None
        )
        return data

    async def grant_invite_rewards(self, *, new_user: User, invite_code: InviteCode) -> dict:
        feature_flags = await self.get_feature_flags()
        if not feature_flags["points_enabled"]:
            return {
                "points_enabled": False,
                "invitee": None,
                "inviter": None,
            }

        invitee_ledger, invitee_user = await self.apply_points_change(
            user_id=new_user.id,
            change_amount=self.invite_reward_points,
            transaction_type="invite_signup",
            title="受邀注册奖励",
            remark="使用邀请码注册成功",
            invite_code_id=invite_code.id,
            related_user_id=invite_code.owner_user_id,
            unique_key=f"invite_signup:{new_user.id}",
            meta={"invite_code": invite_code.code},
        )

        inviter_summary = None
        if invite_code.owner_user_id and invite_code.owner_user_id != new_user.id:
            _, inviter_user = await self.apply_points_change(
                user_id=invite_code.owner_user_id,
                change_amount=self.invite_reward_points,
                transaction_type="invite_reward",
                title="邀请好友奖励",
                remark=f"{new_user.username} 使用邀请码完成注册",
                invite_code_id=invite_code.id,
                related_user_id=new_user.id,
                unique_key=f"invite_reward:{invite_code.id}:{new_user.id}",
                meta={"invite_code": invite_code.code, "invitee_user_id": new_user.id},
            )
            inviter_summary = {
                "user_id": inviter_user.id,
                "username": inviter_user.username,
                "points_balance": inviter_user.points_balance,
                "reward_points": self.invite_reward_points,
            }

        return {
            "invitee": {
                "user_id": new_user.id,
                "username": new_user.username,
                "points_balance": invitee_user.points_balance,
                "reward_points": self.invite_reward_points,
                "ledger_id": invitee_ledger.id,
            },
            "inviter": inviter_summary,
        }

    async def grant_points(
        self,
        *,
        user_id: int,
        points: int,
        operator_user_id: int | None,
        remark: str | None = None,
    ) -> tuple[PointLedger, User]:
        return await self.apply_points_change(
            user_id=user_id,
            change_amount=points,
            transaction_type="admin_gift",
            title="管理员赠送积分",
            remark=remark or "后台手动赠送积分",
            operator_user_id=operator_user_id,
            meta={"operator_user_id": operator_user_id},
        )

    async def reserve_video_generation_points(
        self,
        *,
        user_id: int,
        task_source: str,
        task_type: str,
    ) -> dict:
        feature_flags = await self.get_feature_flags()
        video_generation_cost = int(feature_flags.get("video_generation_cost", 0) or 0)
        user = await User.get(id=user_id)
        if not feature_flags["points_enabled"] or video_generation_cost <= 0:
            return {
                "charge_token": "",
                "points_cost": 0,
                "points_balance": int(user.points_balance or 0),
                "ledger_id": None,
                "charged": False,
            }

        charge_token = uuid4().hex
        insufficient_balance_message = (
            "积分不足，请先前往 App 内充值后再生成视频"
            if feature_flags["payment_enabled"]
            else "积分不足，当前充值功能未开启，请联系管理员"
        )
        ledger, user = await self.apply_points_change(
            user_id=user_id,
            change_amount=-video_generation_cost,
            transaction_type="video_consume",
            title="视频生成扣费",
            remark="提交视频生成任务",
            unique_key=f"video_consume:{charge_token}",
            insufficient_balance_message=insufficient_balance_message,
            meta={
                "task_source": task_source,
                "task_type": task_type,
                "points_cost": video_generation_cost,
            },
        )
        return {
            "charge_token": charge_token,
            "points_cost": video_generation_cost,
            "points_balance": user.points_balance,
            "ledger_id": ledger.id,
            "charged": True,
        }

    async def refund_video_generation_points(
        self,
        *,
        user_id: int,
        charge_token: str,
        task_id: int | None = None,
        reason: str = "视频制作失败，积分已退回",
    ) -> tuple[PointLedger | None, User | None]:
        normalized_token = str(charge_token or "").strip()
        if not normalized_token:
            return None, None

        async with in_transaction() as connection:
            refunded = await PointLedger.filter(unique_key=f"video_refund:{normalized_token}").using_db(connection).first()
            if refunded:
                user = await User.filter(id=user_id).using_db(connection).first()
                return refunded, user

            original = await (
                PointLedger.filter(
                    user_id=user_id,
                    unique_key=f"video_consume:{normalized_token}",
                    transaction_type="video_consume",
                )
                .using_db(connection)
                .first()
            )
            if not original:
                return None, None

            refund_amount = abs(int(original.change_amount or 0))
            if refund_amount <= 0:
                return None, None

            user = await self._get_locked_user(user_id=user_id, connection=connection)
            user.points_balance = int(user.points_balance or 0) + refund_amount
            user.total_points_spent = max(int(user.total_points_spent or 0) - refund_amount, 0)
            await user.save(using_db=connection, update_fields=["points_balance", "total_points_spent"])

            ledger = await PointLedger.create(
                user_id=user.id,
                change_amount=refund_amount,
                balance_after=user.points_balance,
                direction="credit",
                transaction_type="video_refund",
                title="视频失败退回积分",
                remark=reason,
                task_id=task_id,
                unique_key=f"video_refund:{normalized_token}",
                meta={"charge_token": normalized_token},
                using_db=connection,
            )
            return ledger, user

    async def apply_points_change(
        self,
        *,
        user_id: int,
        change_amount: int,
        transaction_type: str,
        title: str,
        remark: str | None = None,
        related_user_id: int | None = None,
        invite_code_id: int | None = None,
        recharge_order_id: int | None = None,
        task_id: int | None = None,
        operator_user_id: int | None = None,
        unique_key: str | None = None,
        meta: dict | None = None,
        insufficient_balance_message: str | None = None,
    ) -> tuple[PointLedger, User]:
        if change_amount == 0:
            raise HTTPException(status_code=400, detail="积分变更值不能为 0")

        async with in_transaction() as connection:
            existing = None
            if unique_key:
                existing = await PointLedger.filter(unique_key=unique_key).using_db(connection).first()
            if existing:
                user = await User.get(id=user_id)
                return existing, user

            user = await self._get_locked_user(user_id=user_id, connection=connection)
            next_balance = int(user.points_balance or 0) + int(change_amount)
            if next_balance < 0:
                raise HTTPException(
                    status_code=400,
                    detail=insufficient_balance_message or "积分不足，请稍后重试",
                )

            user.points_balance = next_balance
            update_fields = ["points_balance"]
            if change_amount < 0:
                user.total_points_spent = int(user.total_points_spent or 0) + abs(int(change_amount))
                update_fields.append("total_points_spent")
            await user.save(using_db=connection, update_fields=update_fields)

            ledger = await PointLedger.create(
                user_id=user.id,
                change_amount=int(change_amount),
                balance_after=user.points_balance,
                direction="credit" if change_amount > 0 else "debit",
                transaction_type=transaction_type,
                title=title,
                remark=remark,
                related_user_id=related_user_id,
                invite_code_id=invite_code_id,
                recharge_order_id=recharge_order_id,
                task_id=task_id,
                operator_user_id=operator_user_id,
                unique_key=unique_key,
                meta=meta,
                using_db=connection,
            )
            return ledger, user

    async def _get_locked_user(self, *, user_id: int, connection) -> User:
        user = await User.filter(id=user_id).using_db(connection).select_for_update().first()
        if not user:
            raise HTTPException(status_code=404, detail="用户不存在")
        return user


points_controller = PointsController()
