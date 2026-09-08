"""GET /health (04)."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter

from app.config import settings
from app.core.timeutil import iso, now_in, tz_for
from app.providers import imd
from app.state import demo_state

router = APIRouter(tags=["health"])


@router.get("/health")
async def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "version": settings.app_version,
        # 04 §Base: every timestamp in this API carries a location offset, and the demo
        # clock is read as IST. /health has no location, so it reports the same IST clock
        # the WebSocket `hello.server_time` does instead of drifting to UTC.
        "time": iso(now_in(tz_for("Asia/Kolkata"))),
        "providers": {
            "imd": imd.status(),
            "open_meteo": "available",
            "marine": "available",
            "air": "available",
        },
        "scenario": demo_state.scenario,
        "now_override": demo_state.now_override,
    }
