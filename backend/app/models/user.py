"""User row (04 §Objects → User)."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import JSON, Boolean, DateTime, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base
from app.core.timeutil import UTC

#: 04 §User — the defaults the app renders when the user has not customised them.
DEFAULT_SCHOOL_WINDOWS: list[dict[str, str]] = [
    {"label": "morning_drop", "start": "07:00", "end": "09:00"},
    {"label": "afternoon_pickup", "start": "13:00", "end": "16:00"},
]
DEFAULT_COMMUTE_WINDOWS: list[dict[str, str]] = [
    {"label": "morning", "start": "08:00", "end": "10:00"},
    {"label": "evening", "start": "17:00", "end": "20:00"},
]


def _utcnow() -> datetime:
    return datetime.now(UTC)


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    phone: Mapped[str | None] = mapped_column(String(24), index=True, default=None)
    is_guest: Mapped[bool] = mapped_column(Boolean, default=True)
    language: Mapped[str] = mapped_column(String(8), default="en")
    units: Mapped[str] = mapped_column(String(16), default="metric")
    personas: Mapped[list[dict[str, Any]]] = mapped_column(JSON, default=list)
    home_location: Mapped[dict[str, Any] | None] = mapped_column(JSON, default=None)
    school_windows: Mapped[list[dict[str, Any]]] = mapped_column(
        JSON, default=lambda: list(DEFAULT_SCHOOL_WINDOWS)
    )
    commute_windows: Mapped[list[dict[str, Any]]] = mapped_column(
        JSON, default=lambda: list(DEFAULT_COMMUTE_WINDOWS)
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
