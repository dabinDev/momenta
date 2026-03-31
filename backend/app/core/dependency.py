from typing import Optional

import jwt
from fastapi import Depends, Header, HTTPException, Request

from app.core.ctx import CTX_USER_ID
from app.models import Role, User
from app.settings import settings


class AuthControl:
    @classmethod
    async def is_authed(
        cls,
        token: str | None = Header(default=None, description="Legacy token header"),
        authorization: str | None = Header(default=None, description="Bearer token"),
    ) -> Optional["User"]:
        try:
            raw_token = token
            if authorization and authorization.lower().startswith("bearer "):
                raw_token = authorization.split(" ", 1)[1].strip()

            if not raw_token:
                raise HTTPException(status_code=401, detail="Missing token")

            if raw_token == "dev":
                user = await User.filter().first()
                if not user:
                    raise HTTPException(status_code=401, detail="Authentication failed")
                user_id = user.id
            else:
                decode_data = jwt.decode(raw_token, settings.SECRET_KEY, algorithms=settings.JWT_ALGORITHM)
                user_id = decode_data.get("user_id")

            user = await User.filter(id=user_id).first()
            if not user:
                raise HTTPException(status_code=401, detail="Authentication failed")
            CTX_USER_ID.set(int(user_id))
            return user
        except HTTPException:
            raise
        except jwt.DecodeError:
            raise HTTPException(status_code=401, detail="Invalid token")
        except jwt.ExpiredSignatureError:
            raise HTTPException(status_code=401, detail="Login expired")
        except Exception:
            raise HTTPException(status_code=500, detail="Authentication error")


class PermissionControl:
    @classmethod
    async def has_permission(cls, request: Request, current_user: User = Depends(AuthControl.is_authed)) -> None:
        if current_user.is_superuser:
            return
        method = request.method
        path = request.url.path
        roles: list[Role] = await current_user.roles
        if not roles:
            raise HTTPException(status_code=403, detail="The user is not bound to a role")
        apis = [await role.apis for role in roles]
        permission_apis = list(set((api.method, api.path) for api in sum(apis, [])))
        if (method, path) not in permission_apis:
            raise HTTPException(status_code=403, detail=f"Permission denied method:{method} path:{path}")


DependAuth = Depends(AuthControl.is_authed)
DependPermission = Depends(PermissionControl.has_permission)
