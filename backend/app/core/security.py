"""JWT (HS256) guest + OTP auth and the admin key dependency (04 §Auth, 05 §Layout).

Tokens carry `{sub: user_id, guest: bool, iat, exp}`. Guests get the same token shape as OTP
users so `/home` never has to branch; `POST /auth/verify-otp` merges a guest into the phone
account when the client sends its old token in `X-Guest-Token`.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta
from typing import Any

import jwt
from fastapi import Depends, Header
from sqlalchemy.orm import Session

from app.config import settings
from app.core.db import get_db
from app.core.errors import UnauthorizedError
from app.core.timeutil import UTC

ALGORITHM = "HS256"
DEMO_OTP = "123456"


def new_user_id() -> str:
    return f"usr_{uuid.uuid4().hex[:12]}"


def new_place_id() -> str:
    return f"plc_{uuid.uuid4().hex[:12]}"


def create_token(user_id: str, *, is_guest: bool = True, days: int | None = None) -> str:
    now = datetime.now(UTC)
    payload = {
        "sub": user_id,
        "guest": bool(is_guest),
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(days=days or settings.jwt_expire_days)).timestamp()),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=ALGORITHM)


def decode_token(token: str) -> dict[str, Any]:
    try:
        return jwt.decode(token, settings.jwt_secret, algorithms=[ALGORITHM])
    except jwt.ExpiredSignatureError as exc:
        raise UnauthorizedError("Token expired") from exc
    except jwt.PyJWTError as exc:
        raise UnauthorizedError("Invalid token") from exc


def user_id_from_token(token: str) -> str:
    sub = decode_token(token).get("sub")
    if not sub:
        raise UnauthorizedError("Token has no subject")
    return str(sub)


def _bearer(authorization: str | None) -> str:
    if not authorization:
        raise UnauthorizedError("Missing Authorization header")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise UnauthorizedError("Expected 'Authorization: Bearer <jwt>'")
    return token.strip()


def current_user(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    """Resolve the authenticated `User` row (404-safe: an unknown subject is a 401)."""
    from app.models.user import User

    uid = user_id_from_token(_bearer(authorization))
    user = db.get(User, uid)
    if user is None:
        raise UnauthorizedError("Unknown user")
    return user


def optional_user(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    from app.models.user import User

    if not authorization:
        return None
    try:
        uid = user_id_from_token(_bearer(authorization))
    except UnauthorizedError:
        return None
    return db.get(User, uid)


def guest_user_id(x_guest_token: str | None) -> str | None:
    """User id inside an `X-Guest-Token` header, or None when it is absent/invalid."""
    if not x_guest_token:
        return None
    try:
        return user_id_from_token(x_guest_token.strip())
    except UnauthorizedError:
        return None


def require_admin(x_admin_key: str | None = Header(default=None)) -> str:
    """`X-Admin-Key` gate for the admin routes (04 §Admin auth)."""
    if not x_admin_key or x_admin_key != settings.admin_key:
        raise UnauthorizedError("Invalid admin key")
    return x_admin_key
