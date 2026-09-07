"""Aggregated engagement counters per user per card type (03 §Learning v1)."""

from __future__ import annotations

from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base

COUNTERS = ("impressions", "taps", "expands", "dismisses", "pins")


class Engagement(Base):
    __tablename__ = "engagement"

    user_id: Mapped[str] = mapped_column(
        String(32), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    card_type: Mapped[str] = mapped_column(String(48), primary_key=True)
    impressions: Mapped[int] = mapped_column(Integer, default=0)
    taps: Mapped[int] = mapped_column(Integer, default=0)
    expands: Mapped[int] = mapped_column(Integer, default=0)
    dismisses: Mapped[int] = mapped_column(Integer, default=0)
    pins: Mapped[int] = mapped_column(Integer, default=0)

    def as_dict(self) -> dict[str, int]:
        return {c: int(getattr(self, c) or 0) for c in COUNTERS}
