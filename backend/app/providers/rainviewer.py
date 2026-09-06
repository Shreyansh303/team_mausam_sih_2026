"""RainViewer radar frames (keyless) — 05 §Providers."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from app.config import settings
from app.core import cache
from app.core.timeutil import UTC, iso
from app.providers.base import Result, fetch_json

SOURCE = "rainviewer"
TILE_SUFFIX = "/256/{z}/{x}/{y}/2/1_1.png"


async def fetch_maps() -> Result:
    return await cache.get_or_fetch(
        "radar",
        cache.key_for("radar"),
        settings.cache_ttl_radar,
        lambda: fetch_json(settings.rainviewer_url, None, source=SOURCE),
    )


def parse(payload: dict[str, Any] | None) -> dict[str, Any] | None:
    if not payload:
        return None
    host = payload.get("host") or "https://tilecache.rainviewer.com"
    radar = payload.get("radar") or {}

    def frames(items: Any) -> list[dict[str, str]]:
        out: list[dict[str, str]] = []
        for f in items or []:
            ts = f.get("time")
            path = f.get("path")
            if ts is None or not path:
                continue
            out.append(
                {"time": iso(datetime.fromtimestamp(int(ts), tz=UTC)), "path": path}
            )
        return out

    past = frames(radar.get("past"))
    nowcast = frames(radar.get("nowcast"))
    # `{path}` stays a placeholder: the client substitutes the frame path it is showing.
    return {
        "host": host,
        "past": past,
        "nowcast": nowcast,
        "tile_template": host + "{path}" + TILE_SUFFIX,
    }
