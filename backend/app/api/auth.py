"""POST /auth/guest · /auth/request-otp · /auth/verify-otp (04)."""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, Header
from sqlalchemy.orm import Session

from app.config import settings
from app.core.db import get_db
from app.core.errors import UnauthorizedError
from app.core.security import DEMO_OTP, create_token, guest_user_id
from app.schemas.user import (
    OtpRequest,
    OtpRequestResponse,
    OtpVerify,
    TokenResponse,
)
from app.services import users as users_svc

log = logging.getLogger("mausam.api.auth")

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/guest", response_model=TokenResponse)
async def guest(db: Session = Depends(get_db)) -> TokenResponse:
    user = users_svc.create_guest(db)
    return TokenResponse(token=create_token(user.id, is_guest=True), user=users_svc.to_schema(user))


@router.post("/request-otp", response_model=OtpRequestResponse)
async def request_otp(body: OtpRequest) -> OtpRequestResponse:
    """Demo OTP flow — no SMS gateway. `demo_otp` is only returned when DEMO_MODE=1."""
    log.info("otp requested for %s", body.phone[-4:].rjust(len(body.phone), "*"))
    return OtpRequestResponse(ok=True, demo_otp=DEMO_OTP if settings.demo_mode else None)


@router.post("/verify-otp", response_model=TokenResponse)
async def verify_otp(
    body: OtpVerify,
    x_guest_token: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> TokenResponse:
    if body.otp.strip() != DEMO_OTP:
        raise UnauthorizedError("Incorrect OTP")

    user = users_svc.by_phone(db, body.phone)
    if user is None:
        user = users_svc.create_guest(db)
        user.phone = body.phone
        user.is_guest = False
    user.is_guest = False

    guest_id = guest_user_id(x_guest_token)
    if guest_id and guest_id != user.id:
        users_svc.merge_guest(db, guest_id=guest_id, target_id=user.id)

    db.flush()
    return TokenResponse(token=create_token(user.id, is_guest=False), user=users_svc.to_schema(user))
