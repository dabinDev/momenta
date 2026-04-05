import secrets
from datetime import datetime

from fastapi.exceptions import HTTPException
from tortoise.transactions import in_transaction

from app.core.crud import CRUDBase
from app.models.admin import InviteCode, User
from app.schemas.invite_codes import InviteCodeCreate, InviteCodeUpdate


class InviteCodeController(CRUDBase[InviteCode, InviteCodeCreate, InviteCodeUpdate]):
    default_owner_max_uses = 999999

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
        code = await self.generate_unique_code()
        return await self.create(
            {
                "code": code,
                "remark": req_in.remark,
                "max_uses": req_in.max_uses,
                "expires_at": req_in.expires_at,
                "is_active": True,
                "used_count": 0,
                "created_by_user_id": created_by_user_id,
                "owner_user_id": req_in.owner_user_id,
            }
        )

    async def ensure_owner_default_code(self, owner_user_id: int) -> InviteCode:
        await self.ensure_owner_user_exists(owner_user_id)
        existing = (
            await self.model.filter(owner_user_id=owner_user_id)
            .order_by("-is_active", "-created_at", "-id")
            .first()
        )
        if existing and self._is_code_usable(existing):
            return existing

        code = await self.generate_unique_code()
        return await self.model.create(
            code=code,
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
            if not invite_code.is_active:
                raise HTTPException(status_code=400, detail="邀请码已停用")
            if invite_code.expires_at and invite_code.expires_at < datetime.now():
                raise HTTPException(status_code=400, detail="邀请码已过期")
            if invite_code.used_count >= invite_code.max_uses:
                raise HTTPException(status_code=400, detail="邀请码次数已用完")

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
            if invite_code.used_count < invite_code.max_uses:
                invite_code.is_active = True
            await invite_code.save()

    async def get_owner_invite_overview(self, owner_user_id: int) -> dict:
        primary_code = await self.ensure_owner_default_code(owner_user_id)
        invite_codes = await self.model.filter(owner_user_id=owner_user_id).order_by("-created_at", "-id")
        invite_code_ids = [item.id for item in invite_codes]

        invited_users: list[dict] = []
        if invite_code_ids:
            users = await User.filter(invite_code_id__in=invite_code_ids).order_by("-created_at", "-id")
            invite_code_map = {item.id: item for item in invite_codes}
            invited_users = [
                {
                    "id": user.id,
                    "username": user.username,
                    "alias": user.alias,
                    "email": user.email,
                    "phone": user.phone,
                    "registration_source": user.registration_source,
                    "invite_code_id": user.invite_code_id,
                    "invite_code": invite_code_map.get(user.invite_code_id).code
                    if invite_code_map.get(user.invite_code_id)
                    else "",
                    "created_at": user.created_at.isoformat() if user.created_at else "",
                }
                for user in users
            ]

        return {
            "owner_user_id": owner_user_id,
            "primary_invite_code": {
                "id": primary_code.id,
                "code": primary_code.code,
                "remark": primary_code.remark,
                "used_count": int(primary_code.used_count or 0),
                "max_uses": int(primary_code.max_uses or 0),
                "is_active": bool(primary_code.is_active),
            },
            "invite_codes": [
                {
                    "id": item.id,
                    "code": item.code,
                    "remark": item.remark,
                    "used_count": int(item.used_count or 0),
                    "max_uses": int(item.max_uses or 0),
                    "is_active": bool(item.is_active),
                    "expires_at": item.expires_at.isoformat() if item.expires_at else None,
                    "created_at": item.created_at.isoformat() if item.created_at else "",
                }
                for item in invite_codes
            ],
            "invited_users": invited_users,
            "summary": {
                "total_invited_users": len(invited_users),
                "active_invite_codes": len([item for item in invite_codes if item.is_active]),
            },
        }

    @staticmethod
    def _is_code_usable(invite_code: InviteCode) -> bool:
        if not invite_code.is_active:
            return False
        if invite_code.expires_at and invite_code.expires_at < datetime.now():
            return False
        return int(invite_code.used_count or 0) < int(invite_code.max_uses or 0)


invite_code_controller = InviteCodeController()
