"""Persistence for admin-injected warnings (04 §/admin/warnings, 05 §Warnings merge).

`/home` calls `active_warnings()` and hands the result to
`services.snapshot.get_snapshot(admin_warnings=...)`, which merges + location-filters them
through `services/warnings.merge()`. Rows whose `expires_at_ts` has passed never leave here,
so an expired warning disappears from `/home` without anyone deleting it.
"""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.core.timeutil import UTC, iso, parse_any, tz_for
from app.models.admin_warning import (
    DEFAULT_RADIUS_KM,
    DEFAULT_TTL_MINUTES,
    AdminWarning,
    new_warning_id,
)
from app.state import demo_state

#: Admin warnings are stamped in IST — this is an India demo and the console shows IST.
DEMO_TZ = "Asia/Kolkata"


def effective_now() -> datetime:
    """The clock the admin console is driving: the global demo override, else real time."""
    if demo_state.now_override:
        try:
            return parse_any(demo_state.now_override)
        except ValueError:  # pragma: no cover - the setter validates first
            pass
    return datetime.now(tz_for(DEMO_TZ))


def create(
    db: Session,
    *,
    severity: str,
    hazard: str,
    title: str,
    description: str = "",
    district: str | None = None,
    state: str | None = None,
    lat: float | None = None,
    lon: float | None = None,
    radius_km: float | None = DEFAULT_RADIUS_KM,
    ttl_minutes: int = DEFAULT_TTL_MINUTES,
    now: datetime | None = None,
) -> AdminWarning:
    ref = now or effective_now()
    expires = ref + timedelta(minutes=max(1, int(ttl_minutes)))
    row = AdminWarning(
        id=new_warning_id(),
        severity=severity,
        hazard=hazard,
        title=title,
        description=description or "",
        district=district,
        state=state,
        lat=lat,
        lon=lon,
        radius_km=radius_km,
        issued_at=iso(ref),
        valid_from=iso(ref),
        valid_to=iso(expires),
        expires_at_ts=expires.timestamp(),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def get(db: Session, warning_id: str) -> AdminWarning | None:
    return db.get(AdminWarning, warning_id)


def remove(db: Session, warning_id: str) -> bool:
    row = db.get(AdminWarning, warning_id)
    if row is None:
        return False
    db.delete(row)
    db.commit()
    return True


def purge_expired(db: Session, *, now: datetime | None = None) -> int:
    """Drop rows that expired more than a day ago (housekeeping, never required for reads)."""
    ref = (now or effective_now()).timestamp() - 86400
    result = db.execute(delete(AdminWarning).where(AdminWarning.expires_at_ts < ref))
    db.commit()
    return int(result.rowcount or 0)


def rows(db: Session, *, now: datetime | None = None) -> list[AdminWarning]:
    """Every warning still inside its TTL, newest first."""
    ref = (now or effective_now()).timestamp()
    stmt = (
        select(AdminWarning)
        .where(AdminWarning.expires_at_ts > ref)
        .order_by(AdminWarning.expires_at_ts.desc())
    )
    return list(db.execute(stmt).scalars().all())


def active_warnings(db: Session, *, now: datetime | None = None) -> list[dict[str, Any]]:
    """Live rows as 04 `Warning` dicts. Empty list when nothing is pushed."""
    return [row.to_warning() for row in rows(db, now=now)]


def all_warnings(db: Session) -> list[dict[str, Any]]:
    """Every stored row regardless of expiry (used by tests and debugging)."""
    stmt = select(AdminWarning).order_by(AdminWarning.expires_at_ts.desc())
    return [row.to_warning() for row in db.execute(stmt).scalars().all()]


def utc_now() -> datetime:
    return datetime.now(UTC)
