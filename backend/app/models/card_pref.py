"""Per-user card preferences: pin / hide (04 §/me/card-prefs)."""

from __future__ import annotations

from sqlalchemy import Boolean, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class CardPref(Base):
    __tablename__ = "card_prefs"

    user_id: Mapped[str] = mapped_column(
        String(32), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    card_type: Mapped[str] = mapped_column(String(48), primary_key=True)
    pinned: Mapped[bool] = mapped_column(Boolean, default=False)
    hidden: Mapped[bool] = mapped_column(Boolean, default=False)
