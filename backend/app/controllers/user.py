from datetime import datetime
from typing import List, Optional

from fastapi.exceptions import HTTPException

from app.core.crud import CRUDBase
from app.models.admin import User
from app.controllers.invite_code import invite_code_controller
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
            raise HTTPException(status_code=400, detail="Invalid username")
        if not verify_password(credentials.password, user.password):
            raise HTTPException(status_code=400, detail="Incorrect password")
        if not user.is_active:
            raise HTTPException(status_code=400, detail="User is disabled")
        return user

    async def update_roles(self, user: User, role_ids: List[int]) -> None:
        await user.roles.clear()
        for role_id in role_ids:
            role_obj = await role_controller.get(id=role_id)
            await user.roles.add(role_obj)

    async def reset_password(self, user_id: int):
        user_obj = await self.get(id=user_id)
        if user_obj.is_superuser:
            raise HTTPException(status_code=403, detail="Superuser password cannot be reset here")
        user_obj.password = get_password_hash(password="123456")
        await user_obj.save()

    async def change_password(self, user_id: int, old_password: str, new_password: str) -> None:
        user_obj = await self.get(id=user_id)
        if not verify_password(old_password, user_obj.password):
            raise HTTPException(status_code=400, detail="Old password is incorrect")
        user_obj.password = get_password_hash(password=new_password)
        await user_obj.save()

    async def forgot_password(self, req_in: ForgotPasswordRequest) -> None:
        user_obj = await self.model.filter(username=req_in.username, email=req_in.email).first()
        if not user_obj:
            raise HTTPException(status_code=404, detail="User not found")
        if not user_obj.is_active:
            raise HTTPException(status_code=400, detail="User is disabled")
        user_obj.password = get_password_hash(password=req_in.new_password)
        await user_obj.save()

    async def register_user(self, req_in: RegisterRequest) -> User:
        email_user, username_user = await self.get_by_email_or_username(
            email=req_in.email,
            username=req_in.username,
        )
        if email_user:
            raise HTTPException(status_code=400, detail="Email already exists")
        if username_user:
            raise HTTPException(status_code=400, detail="Username already exists")

        invite_code = await invite_code_controller.consume_available_code(req_in.invite_code)
        try:
            user = await self.create_user(
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
            user.registration_source = "invite"
            user.invite_code_id = invite_code.id
            await user.save()
            return user
        except Exception:
            await invite_code_controller.rollback_consume(invite_code.id)
            raise

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
            raise HTTPException(status_code=400, detail="Email already exists")

        user_obj.email = email
        user_obj.alias = alias
        user_obj.phone = phone
        await user_obj.save()
        return user_obj


user_controller = UserController()
