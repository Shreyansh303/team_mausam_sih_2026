"""GET /health (04)."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.config import settings
from app.core.db import get_db
from app.core.timeutil import iso, now_in, tz_for
from app.providers import imd
from app.services import push as push_svc
from app.state import demo_state

router = APIRouter(tags=["health"])


@router.get("/health")
async def health(db: Session = Depends(get_db)) -> dict[str, Any]:
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
        # Which push transport is live and how many devices are registered
        # (`noop` until FCM_SERVICE_ACCOUNT_FILE + FCM_PROJECT_ID are set).
        "push": {"transport": push_svc.transport().name, "devices": push_svc.device_count(db)},
        # Whether the v2 ML ranker is blended into /home (ENGINE_ML=1). False is the
        # default and means the deterministic v1 formula is the only thing ranking cards.
        "engine": {"ml": settings.ml_on},
        "scenario": demo_state.scenario,
        "now_override": demo_state.now_override,
    }
