"""Timezones, ISO-8601 with the location offset, dayparts and IMD seasons (02)."""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

UTC = timezone.utc

# 02 §Dayparts (local hour)
DAYPARTS: list[tuple[int, int, str]] = [
    (0, 5, "night"),
    (5, 8, "dawn"),
    (8, 11, "morning"),
    (11, 15, "midday"),
    (15, 18, "afternoon"),
    (18, 21, "evening"),
    (21, 24, "late"),
]

# 02 §IMD seasons (month)
SEASONS: dict[int, str] = {
    1: "winter",
    2: "winter",
    3: "pre_monsoon",
    4: "pre_monsoon",
    5: "pre_monsoon",
    6: "monsoon",
    7: "monsoon",
    8: "monsoon",
    9: "monsoon",
    10: "post_monsoon",
    11: "post_monsoon",
    12: "post_monsoon",
}


def tz_for(name: str | None, offset_seconds: int | None = None) -> timezone | ZoneInfo:
    """Resolve a tz by IANA name; fall back to a fixed offset (Open-Meteo `utc_offset_seconds`)."""
    if name:
        try:
            return ZoneInfo(name)
        except (ZoneInfoNotFoundError, ValueError, KeyError):
            pass
    if offset_seconds is not None:
        return timezone(timedelta(seconds=int(offset_seconds)))
    return UTC


def now_in(tz: timezone | ZoneInfo) -> datetime:
    return datetime.now(UTC).astimezone(tz)


def parse_local(value: str, tz: timezone | ZoneInfo) -> datetime:
    """Parse an Open-Meteo naive local timestamp (`2026-09-07T07:30`) into an aware datetime."""
    dt = datetime.fromisoformat(value)
    if dt.tzinfo is None:
        return dt.replace(tzinfo=tz)
    return dt.astimezone(tz)


def parse_any(value: str, tz: timezone | ZoneInfo | None = None) -> datetime:
    """Parse an ISO-8601 string (with or without offset, `Z` allowed)."""
    v = value.strip().replace("Z", "+00:00")
    dt = datetime.fromisoformat(v)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=tz or UTC)
    return dt


def iso(dt: datetime) -> str:
    """ISO-8601 with the offset, second precision (04: `2026-09-07T07:30:00+05:30`)."""
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=UTC)
    return dt.replace(microsecond=0).isoformat()


def iso_utc(dt: datetime | None = None) -> str:
    dt = dt or datetime.now(UTC)
    return iso(dt.astimezone(UTC))


def daypart(dt: datetime) -> str:
    h = dt.hour
    for lo, hi, name in DAYPARTS:
        if lo <= h < hi:
            return name
    return "night"


def season(dt: datetime | date) -> str:
    return SEASONS[dt.month]


def is_weekend(dt: datetime | date) -> bool:
    return dt.weekday() >= 5


def next_occurrence(
    ref: datetime, start_hm: tuple[int, int], end_hm: tuple[int, int]
) -> tuple[datetime, datetime]:
    """Next occurrence of a local [start, end) daily window relative to `ref`."""
    start = ref.replace(hour=start_hm[0], minute=start_hm[1], second=0, microsecond=0)
    end = ref.replace(hour=end_hm[0], minute=end_hm[1], second=0, microsecond=0)
    if end <= ref:
        start += timedelta(days=1)
        end += timedelta(days=1)
    return start, end


def hhmm(dt: datetime) -> str:
    return dt.strftime("%H:%M")


def minutes_between(a: datetime, b: datetime) -> int:
    return int((b - a).total_seconds() // 60)
