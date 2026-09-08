"""Shared plumbing for the 33 card builders.

A builder returns a `CardContent`: the `data` block (exactly the keys listed for that card in
docs/02), a subtitle, an insight and provenance. `home.py` wraps it into the 04 `Card`.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

from app.core.i18n import resolve, t
from app.core.timeutil import parse_any
from app.engine.context import Bundle, Context, UserProfile

#: `?lite=1` trims hourly arrays to this many points (04 §GET /home).
LITE_HOURS = 12
LITE_RADAR_FRAMES = 3


@dataclass
class CardContent:
    data: dict[str, Any] = field(default_factory=dict)
    subtitle: str = ""
    headline: str = ""
    detail: str = ""
    icon: str = "cloud"
    source: str = "open-meteo"
    estimated: bool = False


Builder = Callable[[Bundle, Context, UserProfile], CardContent]


# ----------------------------------------------------------------- small helpers


def hhmm(value: str | None) -> str:
    """`2026-09-07T07:30:00+05:30` → `07:30`."""
    if not value:
        return "—"
    try:
        return parse_any(value).strftime("%H:%M")
    except (TypeError, ValueError):
        return "—"


#: Weekday / month abbreviations resolve through the catalog — `strftime` is locale-blind here.
DOW = ("mon", "tue", "wed", "thu", "fri", "sat", "sun")
MONTHS = ("jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec")


def daylabel(lang: str, value: str | None, *, with_dow: bool = False) -> str:
    """`2026-09-12` → `12 Sep`, or `Sat 12 Sep` with `with_dow` — localized (05 §i18n)."""
    if not value:
        return "—"
    try:
        moment = parse_any(value)
    except (TypeError, ValueError):
        return str(value)
    month = t(lang, "month." + MONTHS[moment.month - 1])
    if with_dow:
        return t(
            lang,
            "date.dow_day_month",
            dow=t(lang, "dow." + DOW[moment.weekday()]),
            day=moment.day,
            month=month,
        )
    return t(lang, "date.day_month", day=moment.day, month=month)


def num(value: Any, digits: int = 0) -> str:
    if value is None:
        return "—"
    try:
        return f"{float(value):.{digits}f}"
    except (TypeError, ValueError):
        return str(value)


def condition_text(lang: str, code: int | None) -> str:
    return t(lang, f"condition.{int(code)}" if code is not None else "condition.unknown")


def trim(rows: list[Any], limit: int, lite: bool, lite_limit: int = LITE_HOURS) -> list[Any]:
    return list(rows[: lite_limit if lite else limit])


def key_of(value: str | None) -> str:
    """`Very Poor` → `very_poor` for i18n lookups."""
    return (value or "").strip().lower().replace(" ", "_").replace("-", "_")


def local_now(ctx: Context) -> datetime:
    return ctx.now


def advice_list(lang: str, keys: list[str], **kw: Any) -> list[str]:
    return [t(lang, k, **kw) for k in keys]


def flight_detail(lang: str, block: dict[str, Any]) -> str:
    """Compose `flight_risk.detail_tokens` into one sentence in `lang` (05 §i18n)."""
    tokens = list(block.get("detail_tokens") or [])
    if not tokens:
        return str(block.get("detail") or "")
    lead = resolve(lang, tokens[0])
    bits = [resolve(lang, tok) for tok in tokens[1:]]
    return f"{lead}: {'; '.join(bits)}." if bits else lead


def localized_warning(lang: str, warning: dict[str, Any]) -> dict[str, Any]:
    """Scenario warnings carry canned copy; the catalog holds it under
    `scenario.warning.<hazard>.{title,description}`. IMD and admin-pushed warnings are written
    by a human and pass through untouched."""
    if warning.get("source") != "scenario":
        return warning
    hazard = str(warning.get("hazard") or "other")
    out = dict(warning)
    for field, key in (
        ("title", f"scenario.warning.{hazard}.title"),
        ("description", f"scenario.warning.{hazard}.description"),
    ):
        value = t(lang, key)
        if value != key:
            out[field] = value
    return out
