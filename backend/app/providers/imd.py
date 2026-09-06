"""IMD Mausam API client — whitelisting-aware (05 §Providers, 01 §Data sources).

The public IMD endpoints answer `401 … IP needs to be whitelisted` from non-whitelisted hosts.
When that happens we mark the provider unavailable for 10 minutes, log once, and return None so
the snapshot silently falls back to Open-Meteo + derived values. Parsing is defensive: any
exception yields None. Ask IMD for whitelisting (see backend README) to switch it on for real.
"""

from __future__ import annotations

import logging
import time
from typing import Any

from app.config import settings
from app.core import cache
from app.core.geo import imd_ids, nearest_city
from app.providers.base import Result, fetch_json

log = logging.getLogger("mausam.providers.imd")

SOURCE = "imd"
UNAVAILABLE_SECONDS = 600

_unavailable_until: float = 0.0
_logged_once = False


def is_available() -> bool:
    return settings.imd_on and time.time() >= _unavailable_until


def status() -> str:
    if not settings.imd_on:
        return "disabled"
    return "available" if is_available() else "unavailable"


def reset_availability() -> None:
    """Test hook."""
    global _unavailable_until, _logged_once
    _unavailable_until = 0.0
    _logged_once = False


def _mark_unavailable(reason: str) -> None:
    global _unavailable_until, _logged_once
    _unavailable_until = time.time() + UNAVAILABLE_SECONDS
    if not _logged_once:
        log.warning(
            "IMD provider unavailable for %ss (%s). Request IP whitelisting from IMD to enable.",
            UNAVAILABLE_SECONDS,
            reason,
        )
        _logged_once = True


def ids_for(lat: float, lon: float) -> dict[str, Any]:
    """Station / district ids for the nearest curated city, if we know any."""
    table = imd_ids()
    city, dist = nearest_city(lat, lon)
    if not city or dist > 60:
        return {}
    return dict(table.get(city["id"], {}))


async def _call(endpoint: str, ident: str | Any) -> Any | None:
    if not is_available() or ident in (None, ""):
        return None
    url = f"{settings.imd_base_url.rstrip('/')}/{endpoint}"
    res: Result = await fetch_json(url, {"id": ident}, source=SOURCE, retries=0)
    if not res.ok:
        err = (res.error or "").lower()
        if res.status in (401, 403) or "whitelist" in err:
            _mark_unavailable(res.error or f"http_{res.status}")
        return None
    return res.data


async def current_wx(lat: float, lon: float) -> dict[str, Any] | None:
    ids = ids_for(lat, lon)
    station = ids.get("station_id")
    if not station:
        return None
    key = cache.key_for("imd_current", lat, lon, id=station)
    return await cache.get_or_fetch(
        "imd_current",
        key,
        settings.cache_ttl_imd,
        lambda: _call("current_wx_api.php", station),
    )


async def nowcast(lat: float, lon: float) -> dict[str, Any] | None:
    ids = ids_for(lat, lon)
    district = ids.get("district_id")
    if not district:
        return None
    key = cache.key_for("imd_nowcast", lat, lon, id=district)
    return await cache.get_or_fetch(
        "imd_nowcast",
        key,
        settings.cache_ttl_imd,
        lambda: _call("nowcastapi.php", district),
    )


async def warnings(lat: float, lon: float) -> list[dict[str, Any]] | None:
    ids = ids_for(lat, lon)
    district = ids.get("district_id")
    if not district:
        return None
    key = cache.key_for("imd_warnings", lat, lon, id=district)
    data = await cache.get_or_fetch(
        "imd_warnings",
        key,
        settings.cache_ttl_imd,
        lambda: _call("warnings_district_api.php", district),
    )
    if data is None:
        return None
    return data if isinstance(data, list) else [data]


def parse_nowcast(payload: Any) -> dict[str, Any] | None:
    """Defensive parse of the district nowcast payload."""
    try:
        if not payload:
            return None
        item = payload[0] if isinstance(payload, list) else payload
        if not isinstance(item, dict):
            return None
        text = (
            item.get("Nowcast_Message")
            or item.get("nowcast_message")
            or item.get("message")
            or item.get("Warning_Message")
        )
        if not text:
            return None
        colour = str(item.get("Color") or item.get("colour") or "").strip().lower()
        severity = "severe" if colour in ("red", "orange") else "moderate"
        return {
            "text": str(text).strip(),
            "severity": severity,
            "issued_at": item.get("Issue_Time") or item.get("issue_time"),
            "valid_till": item.get("Valid_Till") or item.get("valid_till"),
        }
    except Exception:  # noqa: BLE001 - "any exception → None" (05)
        return None


def parse_warnings(payload: Any) -> list[dict[str, Any]]:
    """Defensive parse of the district warning payload into partial Warning dicts."""
    out: list[dict[str, Any]] = []
    try:
        items = payload if isinstance(payload, list) else [payload]
        colour_map = {"1": "yellow", "2": "orange", "3": "red"}
        for item in items:
            if not isinstance(item, dict):
                continue
            for day in range(1, 6):
                colour = item.get(f"Day{day}_Color") or item.get(f"day{day}_colour")
                text = item.get(f"Day{day}_Warning") or item.get(f"day{day}_warning")
                if not colour or not text:
                    continue
                sev = colour_map.get(str(colour).strip(), str(colour).strip().lower())
                if sev not in ("yellow", "orange", "red"):
                    continue
                out.append(
                    {
                        "severity": sev,
                        "title": str(text).strip()[:120],
                        "description": str(text).strip(),
                        "district": item.get("District") or item.get("district"),
                        "state": item.get("State") or item.get("state"),
                        "day_offset": day - 1,
                    }
                )
    except Exception:  # noqa: BLE001
        return []
    return out
