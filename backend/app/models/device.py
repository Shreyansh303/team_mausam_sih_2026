"""Registered push device (S3 — `docs/08_PUSH_NOTIFICATIONS.md`, 04 §Devices).

One row per FCM registration token. The token is the primary key because that is what the
platform hands the app and what identifies the handset to FCM; a token that moves to another
account simply changes `user_id` (re-registering under a new login is an upsert, not a
duplicate). `lat`/`lon` are the last position the app reported and are what
`services/warnings.applies_to()` uses to compute `affects_you` per device — the push equivalent
of the coordinates a WebSocket client connects with.
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base
from app.core.timeutil import UTC

#: FCM registration tokens are ~160-200 chars today; 255 leaves room and stays a legal PK width.
TOKEN_MAX_LEN = 255
#: A handful per account (phone + tablet + a reinstall or two). The oldest is evicted beyond this.
MAX_DEVICES_PER_USER = 8
PLATFORMS = ("android", "ios", "web")


def _now() -> datetime:
    return datetime.now(UTC)


class Device(Base):
    __tablename__ = "devices"

    token: Mapped[str] = mapped_column(String(TOKEN_MAX_LEN), primary_key=True)
    user_id: Mapped[str] = mapped_column(
        String(32), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    lat: Mapped[float | None] = mapped_column(Float, default=None)
    lon: Mapped[float | None] = mapped_column(Float, default=None)
    lang: Mapped[str] = mapped_column(String(8), default="en")
    platform: Mapped[str] = mapped_column(String(16), default="android")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
