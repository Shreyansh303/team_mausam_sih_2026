"""Admin/demo routes (04 §/admin/*) and the single-file demo console (05 §Admin console).

Every mutating route does the same three things in the same order:
    1. write (DB row or `demo_state`)
    2. drop the assembled-snapshot cache — a snapshot cached before the write would otherwise be
       served for up to `CACHE_TTL_SNAPSHOT` seconds without the new warning
    3. broadcast on the WebSocket (`api/ws.py`) — never from `app/engine/`, which stays pure
    4. hand the same message to the push transport (`services/push.py`), which reaches devices
       whose app is closed. Noop (log only) until a Firebase project is configured — S3,
       `docs/09_PUSH_NOTIFICATIONS.md`.
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, Depends
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.api import ws
from app.config import BASE_DIR, settings
from app.core import cache
from app.core.db import get_db
from app.core.errors import NotFoundError, ValidationError
from app.core.security import require_admin
from app.core.timeutil import iso, parse_any, tz_for
from app.models.user import User as UserModel
from app.providers import scenarios
from app.schemas.admin import (
    AdminState,
    NowOverrideBody,
    ResetUserBody,
    ScenarioBody,
    WarningCreate,
)
from app.schemas.device import AdminDevice, AdminDevices
from app.schemas.user import OkResponse
from app.schemas.warning import Warning
from app.services import admin_warnings as admin_svc
from app.services import push as push_svc
from app.services import users as users_svc
from app.state import demo_state

log = logging.getLogger("mausam.api.admin")

router = APIRouter(prefix="/admin", tags=["admin"])

CONSOLE_HTML = BASE_DIR / "static" / "admin" / "index.html"


def _invalidate_snapshots() -> None:
    """Drop every assembled snapshot so the next `/home` sees the write.

    Only the `snapshot` bucket, not `cache.clear_all()`: an admin write cannot change what
    Open-Meteo returned, and clearing the provider buckets too made the very next `/home` refetch
    every upstream — 2.7 s measured, against the < 400 ms warm target in `docs/01`.
    """
    cache.invalidate("snapshot")


def _state(db: Session) -> AdminState:
    return AdminState(
        scenario=demo_state.scenario,
        now_override=demo_state.now_override,
        warnings=[Warning.model_validate(w) for w in admin_svc.active_warnings(db)],
        connected_clients=ws.connected_clients(),
        devices=push_svc.device_count(db),
        push_transport=push_svc.transport().name,
    )


# --------------------------------------------------------------------------- console


@router.get("/console", include_in_schema=False)
async def console() -> FileResponse:
    """The demo console. No admin key here — the page asks for it and keeps it in localStorage."""
    if not CONSOLE_HTML.exists():  # pragma: no cover - shipped with the package
        raise NotFoundError("Admin console is not installed")
    return FileResponse(CONSOLE_HTML, media_type="text/html; charset=utf-8")


# --------------------------------------------------------------------------- state


@router.get("/state", response_model=AdminState, dependencies=[Depends(require_admin)])
async def get_state(db: Session = Depends(get_db)) -> AdminState:
    return _state(db)


@router.post("/scenario", response_model=AdminState, dependencies=[Depends(require_admin)])
async def set_scenario(body: ScenarioBody, db: Session = Depends(get_db)) -> AdminState:
    name = body.name.strip()
    if name != "live" and not scenarios.exists(name):
        raise ValidationError(f"Unknown scenario '{name}'", code="unknown_scenario")
    demo_state.scenario = name
    _invalidate_snapshots()
    await ws.broadcast("scenario_changed", {"scenario": name})
    await push_svc.notify(db, "scenario_changed", {"scenario": name})
    log.info("admin scenario -> %s", name)
    return _state(db)


@router.post("/now-override", response_model=AdminState, dependencies=[Depends(require_admin)])
async def set_now_override(body: NowOverrideBody, db: Session = Depends(get_db)) -> AdminState:
    raw = (body.now or "").strip()
    value: str | None = None
    if raw:
        try:
            # A naive value (what `<input type="datetime-local">` sends) is read as IST — the
            # console is an India demo tool, and UTC would silently shift the clock by 5.5 h.
            value = iso(parse_any(raw, tz_for(admin_svc.DEMO_TZ)))
        except ValueError as exc:
            raise ValidationError(f"Bad now: {exc}") from exc
    demo_state.now_override = value
    _invalidate_snapshots()
    await ws.broadcast("now_override", {"now": value})
    await push_svc.notify(db, "now_override", {"now": value})
    log.info("admin now_override -> %s", value)
    return _state(db)


# --------------------------------------------------------------------------- warnings


@router.post("/warnings", response_model=Warning, dependencies=[Depends(require_admin)])
async def push_warning(body: WarningCreate, db: Session = Depends(get_db)) -> Warning:
    row = admin_svc.create(
        db,
        severity=body.severity,
        hazard=body.hazard,
        title=body.title,
        description=body.description,
        district=body.district,
        state=body.state,
        lat=body.lat,
        lon=body.lon,
        radius_km=body.radius_km,
        ttl_minutes=body.ttl_minutes,
    )
    warning = row.to_warning()
    _invalidate_snapshots()
    delivered = await ws.broadcast_warning(warning)
    pushed = await push_svc.notify_warning(db, warning)
    log.info(
        "admin warning %s %s/%s pushed to %d ws client(s) and %d device(s) via %s",
        warning["id"], warning["severity"], warning["hazard"], delivered,
        pushed.sent, push_svc.transport().name,
    )
    return Warning.model_validate(warning)


@router.delete(
    "/warnings/{warning_id}", response_model=OkResponse, dependencies=[Depends(require_admin)]
)
async def clear_warning(warning_id: str, db: Session = Depends(get_db)) -> OkResponse:
    if not admin_svc.remove(db, warning_id):
        raise NotFoundError(f"Unknown warning '{warning_id}'")
    _invalidate_snapshots()
    await ws.broadcast("warning_cleared", {"id": warning_id})
    await push_svc.notify(db, "warning_cleared", {"id": warning_id})
    log.info("admin warning %s cleared", warning_id)
    return OkResponse(ok=True)


# --------------------------------------------------------------------------- devices


@router.get("/devices", response_model=AdminDevices, dependencies=[Depends(require_admin)])
async def list_devices(db: Session = Depends(get_db)) -> AdminDevices:
    """Registered push devices (S3). Tokens are send-capabilities — only the tail is returned."""
    rows = push_svc.all_devices(db)
    return AdminDevices(
        transport=push_svc.transport().name,
        count=len(rows),
        devices=[
            AdminDevice(
                token_suffix=push_svc.redact(d.token),
                user_id=d.user_id,
                platform=d.platform,
                lat=d.lat,
                lon=d.lon,
                lang=d.lang,
                updated_at=d.updated_at,
            )
            for d in rows
        ],
    )


# --------------------------------------------------------------------------- users


@router.post("/reset-user", response_model=OkResponse, dependencies=[Depends(require_admin)])
async def reset_user(body: ResetUserBody, db: Session = Depends(get_db)) -> OkResponse:
    user = db.get(UserModel, body.user_id.strip())
    if user is None:
        raise NotFoundError(f"Unknown user '{body.user_id}'")
    users_svc.reset_learning(db, user.id)
    log.info("admin reset learning for %s", user.id)
    return OkResponse(ok=True)


@router.get("/config", include_in_schema=False)
async def console_config() -> dict[str, Any]:
    """Tiny bootstrap the console reads before the admin key is entered."""
    return {
        "demo_mode": bool(settings.demo_mode),
        "api_base": "/api/v1",
        "ws_path": "/ws/alerts",
        "scenario": demo_state.scenario,
        "now_override": demo_state.now_override,
    }
