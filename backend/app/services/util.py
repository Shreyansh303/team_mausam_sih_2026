"""Small helpers shared by the derived services (hour slicing, safe aggregates)."""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any, Iterable

from app.core.timeutil import parse_any


def hour_dt(hour: dict[str, Any]) -> datetime | None:
    try:
        return parse_any(hour["time"])
    except (KeyError, TypeError, ValueError):
        return None


def hours_between(
    hourly: list[dict[str, Any]], start: datetime, end: datetime
) -> list[dict[str, Any]]:
    out = []
    for h in hourly:
        dt = hour_dt(h)
        if dt is not None and start <= dt < end:
            out.append(h)
    return out


def hours_from(
    hourly: list[dict[str, Any]], start: datetime, count: int
) -> list[dict[str, Any]]:
    out = []
    for h in hourly:
        dt = hour_dt(h)
        if dt is not None and dt >= start:
            out.append(h)
            if len(out) >= count:
                break
    return out


def next_hours(
    hourly: list[dict[str, Any]], now: datetime, hours: int
) -> list[dict[str, Any]]:
    return hours_between(hourly, now, now + timedelta(hours=hours))


def vals(rows: Iterable[dict[str, Any]], key: str) -> list[float]:
    out: list[float] = []
    for r in rows:
        v = r.get(key)
        if v is not None:
            try:
                out.append(float(v))
            except (TypeError, ValueError):
                continue
    return out


def vmax(rows: Iterable[dict[str, Any]], key: str, default: float | None = None) -> float | None:
    v = vals(rows, key)
    return max(v) if v else default


def vmin(rows: Iterable[dict[str, Any]], key: str, default: float | None = None) -> float | None:
    v = vals(rows, key)
    return min(v) if v else default


def vmean(rows: Iterable[dict[str, Any]], key: str, default: float | None = None) -> float | None:
    v = vals(rows, key)
    return round(sum(v) / len(v), 2) if v else default


def clamp(value: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, value))


def rnd(value: float | None, digits: int = 1) -> float | None:
    return None if value is None else round(float(value), digits)


THUNDER_CODES = {95, 96, 99}
FOG_CODES = {45, 48}
RAIN_CODES = set(range(51, 68)) | set(range(80, 83))
SNOW_CODES = {71, 73, 75, 77, 85, 86}


def has_code(rows: Iterable[dict[str, Any]], codes: set[int]) -> bool:
    for r in rows:
        c = r.get("condition_code")
        if c is not None and int(c) in codes:
            return True
    return False
