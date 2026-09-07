"""Saved place (04 §Objects → Place). Max 8 per user, enforced in the router."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base
from app.core.timeutil import UTC

MAX_PLACES = 8
KINDS = ("home", "work", "school", "travel", "other")


class Place(Base):
    __tablename__ = "places"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    user_id: Mapped[str] = mapped_column(
        String(32), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(120))
    lat: Mapped[float] = mapped_column(Float)
    lon: Mapped[float] = mapped_column(Float)
    country: Mapped[str | None] = mapped_column(String(80), default="India")
    country_code: Mapped[str | None] = mapped_column(String(8), default="IN")
    admin1: Mapped[str | None] = mapped_column(String(120), default=None)
    admin2: Mapped[str | None] = mapped_column(String(120), default=None)
    kind: Mapped[str] = mapped_column(String(16), default="travel")
    timezone: Mapped[str] = mapped_column(String(64), default="Asia/Kolkata")
    is_coastal: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )
