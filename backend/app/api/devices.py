"""POST /me/devices · DELETE /me/devices/{token} (04 §Devices — optional, S3).

Registering a token is what lets a **closed** app be woken by a warning; see
`docs/08_PUSH_NOTIFICATIONS.md`. With no transport configured the rows are still kept and the
noop transport logs each intended send, so the whole flow is exercisable with zero credentials.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.core.errors import NotFoundError, ValidationError
from app.core.i18n import SUPPORTED
from app.core.security import current_user
from app.models.device import Device as DeviceModel
from app.models.user import User as UserModel
from app.schemas.device import Device, DeviceRegister
from app.schemas.user import OkResponse
from app.services import push as push_svc

router = APIRouter(prefix="/me/devices", tags=["devices"])


def to_schema(device: DeviceModel) -> Device:
    return Device(
        token=device.token,
        platform=device.platform,
        lat=device.lat,
        lon=device.lon,
        lang=device.lang,
        updated_at=device.updated_at,
    )


@router.post("", response_model=Device)
async def register_device(
    body: DeviceRegister,
    user: UserModel = Depends(current_user),
    db: Session = Depends(get_db),
) -> Device:
    """Upsert this handset's push token. Call it on every launch — tokens rotate."""
    lang = (body.lang or user.language or "en").lower()
    if lang not in SUPPORTED:
        raise ValidationError(f"Unsupported language '{lang}'")
    device = push_svc.register(
        db,
        user_id=user.id,
        token=body.token.strip(),
        lat=body.lat,
        lon=body.lon,
        lang=lang,
        platform=body.platform,
    )
    return to_schema(device)


# `{token:path}` because a registration token is opaque: it carries ':' and, in principle, '/'.
@router.delete("/{token:path}", response_model=OkResponse)
async def unregister_device(
    token: str,
    user: UserModel = Depends(current_user),
    db: Session = Depends(get_db),
) -> OkResponse:
    """Delete one of **your own** tokens (sign-out, notifications turned off)."""
    if not push_svc.unregister(db, user_id=user.id, token=token.strip()):
        raise NotFoundError("No registered device with that token")
    return OkResponse(ok=True)
