from datetime import datetime, timedelta
import secrets

from fastapi.exceptions import HTTPException
from tortoise.transactions import in_transaction

from app.core.crud import CRUDBase
from app.models.admin import InviteCode, User
from app.schemas.invite_codes import InviteCodeCreate, InviteCodeUpdate


class InviteCodeController(CRUDBase[InviteCode, InviteCodeCreate, InviteCodeUpdate]):
    default_owner_max_uses = 999999
    default_public_max_uses = 100
    default_public_expire_days = 30

    def __init__(self):
        super().__init__(model=InviteCode)

    async def generate_unique_code(self) -> str:
        for _ in range(10):
            code = secrets.token_urlsafe(6).replace("-", "").replace("_", "").upper()[:10]
            exists = await self.model.filter(code=code).exists()
            if not exists:
                return code
        raise HTTPException(status_code=500, detail="邀请码生成失败，请稍后重试")

    async def ensure_owner_user_exists(self, owner_user_id: int | None) -> None:
        if owner_user_id is None:
            return
        owner_exists = await User.filter(id=owner_user_id).exists()
        if not owner_exists:
            raise HTTPException(status_code=404, detail="邀请码归属用户不存在")

    async def create_invite_code(self, req_in: InviteCodeCreate, created_by_user_id: int | None) -> InviteCode:
        await self.ensure_owner_user_exists(req_in.owner_user_id)
        invite_code = await self.create(
            {
                "code": await self.generate_unique_code(),
                "remark": req_in.remark,
                "max_uses": int(req_in.max_uses or self.default_public_max_uses),
                "expires_at": req_in.expires_at or self._default_public_expires_at(),
                "is_active": True,
                "used_count": 0,
                "created_by_user_id": created_by_user_id,
                "owner_user_id": req_in.owner_user_id,
            }
        )
        return await self.sync_invite_code_state(invite_code)

    async def ensure_owner_default_code(self, owner_user_id: int) -> InviteCode:
        await self.ensure_owner_user_exists(owner_user_id)
        existing_codes = (
            await self.model.filter(owner_user_id=owner_user_id)
            .order_by("-is_active", "-created_at", "-id")
            .all()
        )
        for invite_code in existing_codes:
            await self.sync_invite_code_state(invite_code)
            if self._is_code_usable(invite_code):
                return invite_code

        return await self.model.create(
            code=await self.generate_unique_code(),
            remark="系统自动分配邀请码",
            max_uses=self.default_owner_max_uses,
            expires_at=None,
            is_active=True,
            used_count=0,
            created_by_user_id=owner_user_id,
            owner_user_id=owner_user_id,
        )

    async def consume_available_code(self, code: str) -> InviteCode:
        normalized = code.strip().upper()
        if not normalized:
            raise HTTPException(status_code=400, detail="邀请码不能为空")

        async with in_transaction():
            invite_code = await self.model.filter(code=normalized).select_for_update().first()
            if not invite_code:
                raise HTTPException(status_code=400, detail="邀请码不存在")

            unavailable_reason = self.get_unavailable_reason(invite_code)
            if unavailable_reason == "expired":
                invite_code.is_active = False
                await invite_code.save()
                raise HTTPException(status_code=400, detail="邀请码已失效")
            if unavailable_reason == "used_up":
                invite_code.is_active = False
                await invite_code.save()
                raise HTTPException(status_code=400, detail="邀请码次数已用完")
            if unavailable_reason == "inactive":
                raise HTTPException(status_code=400, detail="邀请码已停用")

            invite_code.used_count += 1
            if invite_code.used_count >= invite_code.max_uses:
                invite_code.is_active = False
            await invite_code.save()
            return invite_code

    async def rollback_consume(self, invite_code_id: int) -> None:
        async with in_transaction():
            invite_code = await self.model.filter(id=invite_code_id).select_for_update().first()
            if not invite_code:
                return
            if invite_code.used_count > 0:
                invite_code.used_count -= 1
            invite_code.is_active = (
                not self._has_expired(invite_code.expires_at)
                and int(invite_code.used_count or 0) < int(invite_code.max_uses or 0)
            )
            await invite_code.save()

    async def deactivate_expired_codes(self) -> None:
        await self.model.filter(
            is_active=True,
            expires_at__lt=datetime.now(),
        ).update(is_active=False)

    async def sync_invite_code_state(self, invite_code: InviteCode) -> InviteCode:
        unavailable_reason = self.get_unavailable_reason(invite_code)
        if unavailable_reason in {"expired", "used_up"} and invite_code.is_active:
            invite_code.is_active = False
            await invite_code.save(update_fields=["is_active"])
        return invite_code

    async def ensure_can_enable(self, invite_code: InviteCode) -> None:
        unavailable_reason = self.get_unavailable_reason(invite_code)
        if unavailable_reason == "expired":
            invite_code.is_active = False
            await invite_code.save(update_fields=["is_active"])
            raise HTTPException(status_code=400, detail="邀请码已失效，请修改有效期后再启用")
        if unavailable_reason == "used_up":
            invite_code.is_active = False
            await invite_code.save(update_fields=["is_active"])
            raise HTTPException(status_code=400, detail="邀请码次数已用完，请增加可用次数后再启用")

    async def serialize_invite_code(self, invite_code: InviteCode) -> dict:
        await self.sync_invite_code_state(invite_code)
        status = self.get_status(invite_code)
        data = await invite_code.to_dict()
        data.update(
            {
                "status": status,
                "status_text": self.get_status_text(status),
                "is_available": status == "active",
                "is_expired": status == "expired",
                "is_used_up": status == "used_up",
            }
        )
        return data

    async def get_owner_invite_overview(self, owner_user_id: int) -> dict:
        await self.deactivate_expired_codes()
        primary_code = await self.ensure_owner_default_code(owner_user_id)
        invite_codes = await self.model.filter(owner_user_id=owner_user_id).order_by("-created_at", "-id")
        serialized_codes = [await self.serialize_invite_code(item) for item in invite_codes]
        invite_code_map = {item["id"]: item for item in serialized_codes}
        invite_code_ids = list(invite_code_map.keys())

        invited_users: list[dict] = []
        if invite_code_ids:
            users = await User.filter(invite_code_id__in=invite_code_ids).order_by("-created_at", "-id")
            invited_users = [
                {
                    "id": user.id,
                    "username": user.username,
                    "alias": user.alias,
                    "email": user.email,
                    "phone": user.phone,
                    "registration_source": user.registration_source,
                    "invite_code_id": user.invite_code_id,
                    "invite_code": invite_code_map.get(user.invite_code_id, {}).get("code", ""),
                    "created_at": user.created_at.isoformat() if user.created_at else "",
                }
                for user in users
            ]

        primary_data = invite_code_map.get(primary_code.id) or await self.serialize_invite_code(primary_code)

        return {
            "owner_user_id": owner_user_id,
            "primary_invite_code": {
                "id": primary_data["id"],
                "code": primary_data["code"],
                "remark": primary_data.get("remark"),
                "used_count": int(primary_data.get("used_count") or 0),
                "max_uses": int(primary_data.get("max_uses") or 0),
                "is_active": bool(primary_data.get("is_active")),
                "status": primary_data.get("status"),
                "status_text": primary_data.get("status_text"),
                "is_available": bool(primary_data.get("is_available")),
            },
            "invite_codes": serialized_codes,
            "invited_users": invited_users,
            "summary": {
                "total_invited_users": len(invited_users),
                "active_invite_codes": len([item for item in serialized_codes if item.get("is_available")]),
            },
        }

    def get_unavailable_reason(self, invite_code: InviteCode) -> str | None:
        if self._has_expired(invite_code.expires_at):
            return "expired"
        if int(invite_code.used_count or 0) >= int(invite_code.max_uses or 0):
            return "used_up"
        if not invite_code.is_active:
            return "inactive"
        return None

    def get_status(self, invite_code: InviteCode) -> str:
        return self.get_unavailable_reason(invite_code) or "active"

    @staticmethod
    def get_status_text(status: str) -> str:
        mapping = {
            "active": "可用",
            "inactive": "已停用",
            "expired": "已失效",
            "used_up": "已用尽",
        }
        return mapping.get(status, "未知状态")

    @staticmethod
    def _is_code_usable(invite_code: InviteCode) -> bool:
        if not invite_code.is_active:
            return False
        if InviteCodeController._has_expired(invite_code.expires_at):
            return False
        return int(invite_code.used_count or 0) < int(invite_code.max_uses or 0)

    @classmethod
    def _default_public_expires_at(cls) -> datetime:
        return datetime.now().astimezone() + timedelta(days=cls.default_public_expire_days)

    @staticmethod
    def _has_expired(expires_at: datetime | None) -> bool:
        if expires_at is None:
            return False
        if expires_at.tzinfo and expires_at.utcoffset() is not None:
            return expires_at < datetime.now(tz=expires_at.tzinfo)
        return expires_at < datetime.now()


invite_code_controller = InviteCodeController()
