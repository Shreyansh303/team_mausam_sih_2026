"""Raw engagement events (04 §POST /events). Kept for the v2 ML ranker in 03 §Learning."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import JSON, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base
from app.core.timeutil import UTC

ACTIONS = ("impression", "tap", "expand", "dismiss", "pin", "unpin", "hide", "unhide")
MAX_BATCH = 100


class Event(Base):
    __tablename__ = "events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(
        String(32), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    card_type: Mapped[str] = mapped_column(String(48), index=True)
    action: Mapped[str] = mapped_column(String(16))
    ts: Mapped[str | None] = mapped_column(String(40), default=None)
    meta: Mapped[dict[str, Any] | None] = mapped_column(JSON, default=None)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )
