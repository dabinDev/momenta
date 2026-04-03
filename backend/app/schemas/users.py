from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, EmailStr, Field


class BaseUser(BaseModel):
    id: int
    email: Optional[EmailStr] = None
    username: Optional[str] = None
    alias: Optional[str] = None
    phone: Optional[str] = None
    is_active: Optional[bool] = True
    is_superuser: Optional[bool] = False
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    last_login: Optional[datetime] = None
    roles: Optional[list] = []


class UserCreate(BaseModel):
    email: EmailStr = Field(example="admin@qq.com")
    username: str = Field(example="admin")
    alias: Optional[str] = Field(default=None, example="Zhang")
    phone: Optional[str] = Field(default=None, example="13800000000")
    password: str = Field(example="123456", min_length=6)
    is_active: Optional[bool] = True
    is_superuser: Optional[bool] = False
    role_ids: Optional[List[int]] = []
    dept_id: Optional[int] = Field(default=0, description="Department ID")

    def create_dict(self):
        return self.model_dump(exclude_unset=True, exclude={"role_ids"})


class UserUpdate(BaseModel):
    id: int
    email: EmailStr
    username: str
    alias: Optional[str] = None
    phone: Optional[str] = None
    is_active: Optional[bool] = True
    is_superuser: Optional[bool] = False
    role_ids: Optional[List[int]] = []
    dept_id: Optional[int] = 0


class UpdatePassword(BaseModel):
    old_password: str = Field(description="Old password", min_length=6)
    new_password: str = Field(description="New password", min_length=6)


class ForgotPasswordRequest(BaseModel):
    username: str = Field(description="Username")
    email: EmailStr = Field(description="Email")
    new_password: str = Field(description="New password", min_length=6)


class RegisterRequest(BaseModel):
    username: str = Field(description="Username", min_length=3)
    email: EmailStr = Field(description="Email")
    password: str = Field(description="Password", min_length=6)
    invite_code: str = Field(description="Invite code", min_length=1)
    alias: Optional[str] = Field(default=None, description="Alias")
    phone: Optional[str] = Field(default=None, description="Phone")


class UpdateCurrentUserProfile(BaseModel):
    email: EmailStr = Field(description="Email")
    alias: Optional[str] = Field(default=None, description="Alias")
    phone: Optional[str] = Field(default=None, description="Phone")
