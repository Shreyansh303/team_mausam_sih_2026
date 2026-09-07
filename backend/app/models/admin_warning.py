"""Admin-injected warning (05 §Layout, 04 §POST /admin/warnings).

The demo console pushes these; `/home` merges every row whose `expires_at_ts` is still in the
future into the snapshot through `services/warnings.merge()`.

Times are stored as ISO-8601 strings (exactly what the 04 `Warning` object carries) plus one
epoch float, `expires_at_ts`, used for the "still live" filter. SQLite drops the offset from a
`DateTime(timezone=True)` column, so a naive/aware comparison would explode on the first query;
an epoch number is portable across SQLite and Postgres and needs no timezone gymnastics.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import DateTime, Float, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base
from app.core.timeutil import UTC
from app.schemas.warning import color_for

#: 04 §POST /admin/warnings defaults.
DEFAULT_RADIUS_KM = 75.0
DEFAULT_TTL_MINUTES = 120


def new_warning_id() -> str:
    return f"wrn_{uuid.uuid4().hex[:10]}"


class AdminWarning(Base):
    __tablename__ = "admin_warnings"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_warning_id)
    severity: Mapped[str] = mapped_column(String(8), default="yellow")
    hazard: Mapped[str] = mapped_column(String(24), default="other")
    title: Mapped[str] = mapped_column(String(200))
    description: Mapped[str] = mapped_column(String(1000), default="")
    district: Mapped[str | None] = mapped_column(String(120), default=None)
    state: Mapped[str | None] = mapped_column(String(120), default=None)
    lat: Mapped[float | None] = mapped_column(Float, default=None)
    lon: Mapped[float | None] = mapped_column(Float, default=None)
    radius_km: Mapped[float | None] = mapped_column(Float, default=DEFAULT_RADIUS_KM)

    issued_at: Mapped[str] = mapped_column(String(40))
    valid_from: Mapped[str] = mapped_column(String(40))
    valid_to: Mapped[str] = mapped_column(String(40))
    #: `valid_to` as epoch seconds — the column the "is it still live?" query filters on.
    expires_at_ts: Mapped[float] = mapped_column(Float, index=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )

    def to_warning(self) -> dict[str, Any]:
        """The 04 `Warning` object, ready for `services/warnings.merge()`."""
        return {
            "id": self.id,
            "severity": self.severity,
            "hazard": self.hazard,
            "title": self.title,
            "description": self.description or "",
            "issued_at": self.issued_at,
            "valid_from": self.valid_from,
            "valid_to": self.valid_to,
            "district": self.district,
            "state": self.state,
            "lat": self.lat,
            "lon": self.lon,
            "radius_km": self.radius_km,
            "source": "admin",
            "color_hex": color_for(self.severity),
        }
