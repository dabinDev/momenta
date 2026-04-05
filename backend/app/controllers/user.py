from datetime import datetime
from typing import List, Optional

from fastapi.exceptions import HTTPException

from app.controllers.invite_code import invite_code_controller
from app.controllers.points import points_controller
from app.core.crud import CRUDBase
from app.models.admin import User
from app.models.points import PointLedger
from app.schemas.login import CredentialsSchema
from app.schemas.users import ForgotPasswordRequest, RegisterRequest, UserCreate, UserUpdate
from app.utils.password import get_password_hash, verify_password

from .role import role_controller


class UserController(CRUDBase[User, UserCreate, UserUpdate]):
    def __init__(self):
        super().__init__(model=User)

    async def get_by_email(self, email: str) -> Optional[User]:
        return await self.model.filter(email=email).first()

    async def get_by_username(self, username: str) -> Optional[User]:
        return await self.model.filter(username=username).first()

    async def get_by_email_or_username(self, *, email: str, username: str) -> tuple[Optional[User], Optional[User]]:
        return await self.get_by_email(email), await self.get_by_username(username)

    async def create_user(self, obj_in: UserCreate) -> User:
        obj_in.password = get_password_hash(password=obj_in.password)
        user = await self.create(obj_in)
        if not user.registration_source:
            user.registration_source = "admin"
            await user.save()
        return user

    async def update_last_login(self, id: int) -> None:
        user = await self.model.get(id=id)
        user.last_login = datetime.now()
        await user.save()

    async def authenticate(self, credentials: CredentialsSchema) -> Optional["User"]:
        user = await self.model.filter(username=credentials.username).first()
        if not user:
            raise HTTPException(status_code=400, detail="用户名不存在")
        if not verify_password(credentials.password, user.password):
            raise HTTPException(status_code=400, detail="密码错误")
        if not user.is_active:
            raise HTTPException(status_code=400, detail="账号已被禁用")
        return user

    async def update_roles(self, user: User, role_ids: List[int]) -> None:
        await user.roles.clear()
        for role_id in role_ids:
            role_obj = await role_controller.get(id=role_id)
            await user.roles.add(role_obj)

    async def reset_password(self, user_id: int):
        user_obj = await self.get(id=user_id)
        if user_obj.is_superuser:
            raise HTTPException(status_code=403, detail="超级管理员密码不支持在这里重置")
        user_obj.password = get_password_hash(password="123456")
        await user_obj.save()

    async def change_password(self, user_id: int, old_password: str, new_password: str) -> None:
        user_obj = await self.get(id=user_id)
        if not verify_password(old_password, user_obj.password):
            raise HTTPException(status_code=400, detail="原密码不正确")
        user_obj.password = get_password_hash(password=new_password)
        await user_obj.save()

    async def forgot_password(self, req_in: ForgotPasswordRequest) -> None:
        user_obj = await self.model.filter(username=req_in.username, email=req_in.email).first()
        if not user_obj:
            raise HTTPException(status_code=404, detail="用户不存在")
        if not user_obj.is_active:
            raise HTTPException(status_code=400, detail="账号已被禁用")
        user_obj.password = get_password_hash(password=req_in.new_password)
        await user_obj.save()

    async def register_user(self, req_in: RegisterRequest) -> tuple[User, dict]:
        email_user, username_user = await self.get_by_email_or_username(
            email=req_in.email,
            username=req_in.username,
        )
        if email_user:
            raise HTTPException(status_code=400, detail="邮箱已存在")
        if username_user:
            raise HTTPException(status_code=400, detail="用户名已存在")

        invite_code = await invite_code_controller.consume_available_code(req_in.invite_code)
        created_user: User | None = None
        try:
            created_user = await self.create_user(
                UserCreate(
                    email=req_in.email,
                    username=req_in.username,
                    alias=req_in.alias,
                    phone=req_in.phone,
                    password=req_in.password,
                    is_active=True,
                    is_superuser=False,
                    role_ids=[],
                    dept_id=0,
                )
            )
            created_user.registration_source = "invite"
            created_user.invite_code_id = invite_code.id
            await created_user.save()

            reward_summary = await points_controller.grant_invite_rewards(new_user=created_user, invite_code=invite_code)
            personal_invite_code = await invite_code_controller.ensure_owner_default_code(created_user.id)
            return created_user, {
                **reward_summary,
                "personal_invite_code": {
                    "id": personal_invite_code.id,
                    "code": personal_invite_code.code,
                },
            }
        except Exception:
            await invite_code_controller.rollback_consume(invite_code.id)
            if created_user is not None:
                await self._rollback_failed_registration(
                    user=created_user,
                    invite_code_id=invite_code.id,
                    invite_owner_user_id=invite_code.owner_user_id,
                )
            raise

    async def _rollback_failed_registration(
        self,
        *,
        user: User,
        invite_code_id: int,
        invite_owner_user_id: int | None,
    ) -> None:
        invitee_ledger = await PointLedger.filter(unique_key=f"invite_signup:{user.id}").first()
        if invitee_ledger is not None:
            await invitee_ledger.delete()

        if invite_owner_user_id and invite_owner_user_id != user.id:
            inviter_ledger = await PointLedger.filter(
                unique_key=f"invite_reward:{invite_code_id}:{user.id}"
            ).first()
            if inviter_ledger is not None:
                inviter = await self.model.filter(id=invite_owner_user_id).first()
                if inviter is not None:
                    inviter.points_balance = max(
                        0,
                        int(inviter.points_balance or 0) - int(inviter_ledger.change_amount or 0),
                    )
                    await inviter.save(update_fields=["points_balance"])
                await inviter_ledger.delete()

        await invite_code_controller.model.filter(owner_user_id=user.id).delete()
        await user.delete()

    async def update_current_profile(
        self,
        user_id: int,
        *,
        email: str,
        alias: str | None,
        phone: str | None,
    ) -> User:
        user_obj = await self.get(id=user_id)
        email_user = await self.get_by_email(email)
        if email_user and email_user.id != user_id:
            raise HTTPException(status_code=400, detail="邮箱已存在")

        user_obj.email = email
        user_obj.alias = alias
        user_obj.phone = phone
        await user_obj.save()
        return user_obj


user_controller = UserController()
