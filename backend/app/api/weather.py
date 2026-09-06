"""GET /weather/snapshot · /weather/radar (04)."""

from __future__ import annotations

import logging
import time
from typing import Any

from fastapi import APIRouter, Query

from app.core.errors import NoDataError, ValidationError
from app.core.timeutil import parse_any
from app.providers import rainviewer, scenarios
from app.schemas.snapshot import RadarResponse, Snapshot
from app.services import snapshot as snapshot_svc
from app.state import demo_state

log = logging.getLogger("mausam.api.weather")

router = APIRouter(prefix="/weather", tags=["weather"])


@router.get("/snapshot", response_model=Snapshot)
async def get_snapshot(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    scenario: str | None = Query(None),
    now_override: str | None = Query(None),
) -> Snapshot:
    name = scenario or demo_state.scenario or "live"
    if not scenarios.exists(name):
        raise ValidationError(f"Unknown scenario '{name}'", code="unknown_scenario")
    now = None
    override = now_override or demo_state.now_override
    if override:
        try:
            now = parse_any(override)
        except ValueError as exc:
            raise ValidationError(f"Bad now_override: {exc}") from exc
    t0 = time.perf_counter()
    snap = await snapshot_svc.get_snapshot(lat, lon, scenario=name, now=now)
    log.info(
        "snapshot lat=%s lon=%s scenario=%s %dms",
        lat, lon, name, int((time.perf_counter() - t0) * 1000),
    )
    return snap


@router.get("/radar", response_model=RadarResponse)
async def get_radar() -> dict[str, Any]:
    res = await rainviewer.fetch_maps()
    parsed = rainviewer.parse(res.data) if res.ok else None
    if not parsed:
        raise NoDataError("Radar frames unavailable")
    return parsed


@router.get("/scenarios")
async def list_scenarios() -> dict[str, Any]:
    """Names available for `?scenario=` (handy for the app's demo sheet)."""
    out = []
    for name in scenarios.available():
        data = scenarios.load(name) or {}
        out.append({"name": name, "description": data.get("description", "")})
    return {"active": demo_state.scenario, "scenarios": [{"name": "live", "description": "Real upstream data"}] + out}
