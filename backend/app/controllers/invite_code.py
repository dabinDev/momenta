import secrets
from datetime import datetime

from fastapi.exceptions import HTTPException
from tortoise.transactions import in_transaction

from app.core.crud import CRUDBase
from app.models.admin import InviteCode
from app.schemas.invite_codes import InviteCodeCreate, InviteCodeUpdate


class InviteCodeController(CRUDBase[InviteCode, InviteCodeCreate, InviteCodeUpdate]):
    def __init__(self):
        super().__init__(model=InviteCode)

    async def generate_unique_code(self) -> str:
        for _ in range(10):
            code = secrets.token_urlsafe(6).replace("-", "").replace("_", "").upper()[:10]
            exists = await self.model.filter(code=code).exists()
            if not exists:
                return code
        raise HTTPException(status_code=500, detail="Failed to generate invite code")

    async def create_invite_code(self, req_in: InviteCodeCreate, created_by_user_id: int | None) -> InviteCode:
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
            }
        )

    async def consume_available_code(self, code: str) -> InviteCode:
        normalized = code.strip().upper()
        if not normalized:
            raise HTTPException(status_code=400, detail="Invalid invite code")

        async with in_transaction():
            invite_code = await self.model.filter(code=normalized).select_for_update().first()
            if not invite_code:
                raise HTTPException(status_code=400, detail="Invalid invite code")
            if not invite_code.is_active:
                raise HTTPException(status_code=400, detail="Invite code is disabled")
            if invite_code.expires_at and invite_code.expires_at < datetime.now():
                raise HTTPException(status_code=400, detail="Invite code has expired")
            if invite_code.used_count >= invite_code.max_uses:
                raise HTTPException(status_code=400, detail="Invite code has been used up")

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


invite_code_controller = InviteCodeController()
