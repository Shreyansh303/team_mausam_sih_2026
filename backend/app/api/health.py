"""GET /health (04)."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from fastapi import APIRouter

from app.config import settings
from app.core.timeutil import UTC, iso
from app.providers import imd
from app.state import demo_state

router = APIRouter(tags=["health"])


@router.get("/health")
async def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "version": settings.app_version,
        "time": iso(datetime.now(UTC)),
        "providers": {
            "imd": imd.status(),
            "open_meteo": "available",
            "marine": "available",
            "air": "available",
        },
        "scenario": demo_state.scenario,
        "now_override": demo_state.now_override,
    }
