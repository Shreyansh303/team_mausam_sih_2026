"""GET /home — the personalized home screen (04 §GET /home).

This is the only place in the home path that performs I/O: the location snapshot, the radar
frames and (concurrently, capped at 5) one snapshot per saved place. Everything after that is
the pure engine in `app/engine/`.
"""

from __future__ import annotations

import asyncio
import logging
import time
from datetime import datetime
from typing import Any

from fastapi import APIRouter, Depends, Header, Query
from sqlalchemy.orm import Session

from app.config import settings
from app.core.db import get_db
from app.core.errors import NotFoundError, ValidationError
from app.core.i18n import normalize_lang
from app.core.timeutil import iso, now_in, parse_any, tz_for
from app.engine import home as engine_home
from app.engine import icons
from app.engine import ml as ml_ranker
from app.engine.context import Bundle, UserProfile, build_context
from app.core.security import current_user
from app.models.user import User as UserModel
from app.providers import rainviewer, scenarios
from app.schemas.home import HomeResponse
from app.schemas.location import LocationResult
from app.schemas.snapshot import Snapshot
from app.schemas.user import PERSONA_IDS
from app.services import admin_warnings as admin_warnings_svc
from app.services import locations as locations_svc
from app.services import snapshot as snapshot_svc
from app.services import users as users_svc
from app.state import demo_state

log = logging.getLogger("mausam.api.home")

router = APIRouter(tags=["home"])

#: 05 §Performance — at most this many saved-place snapshots per request.
MAX_PLACE_SNAPSHOTS = 5
RADAR_ZOOM = 7


# --------------------------------------------------------------------------- helpers


def parse_personas(raw: str | None) -> list[str] | None:
    """`?personas=parent,commuter` → `["parent", "commuter"]` (max 3, validated)."""
    if raw is None:
        return None
    ids = [p.strip() for p in raw.split(",") if p.strip()]
    unknown = [p for p in ids if p not in PERSONA_IDS]
    if unknown:
        raise ValidationError(f"Unknown persona(s): {', '.join(unknown)}")
    return ids[:3]


async def resolve_location(
    db: Session,
    user: UserModel,
    lat: float | None,
    lon: float | None,
    place_id: str | None,
) -> tuple[float, float]:
    """`place_id` wins over lat/lon; a saved place is looked up first, then the curated list."""
    if place_id:
        for place in users_svc.places_for(db, user.id):
            if place.id == place_id:
                return place.lat, place.lon
        curated = locations_svc.by_id(place_id)
        if curated is not None:
            return curated.lat, curated.lon
        raise NotFoundError(f"Unknown place_id '{place_id}'")
    if lat is None or lon is None:
        raise ValidationError("Provide lat and lon, or place_id")
    return lat, lon


async def radar_extra(lat: float, lon: float, snap: dict[str, Any]) -> dict[str, Any] | None:
    """RainViewer frames + the 2-hour rain probability from the hourly forecast (02 §6)."""
    try:
        res = await rainviewer.fetch_maps()
        parsed = rainviewer.parse(res.data) if res.ok else None
    except Exception as exc:  # pragma: no cover - radar is best-effort
        log.info("radar unavailable: %s", exc)
        parsed = None
    if not parsed:
        return None
    frames = list(parsed.get("past") or []) + list(parsed.get("nowcast") or [])
    hourly = snap.get("hourly") or []
    prob = max([h.get("precip_prob_pct") or 0 for h in hourly[:2]] or [0])
    return {
        "host": parsed.get("host", ""),
        "frames": frames,
        "tile_template": parsed.get("tile_template", ""),
        "center": {"lat": lat, "lon": lon},
        "zoom": RADAR_ZOOM,
        "rain_within_2h_prob_pct": int(prob),
    }


def place_summary(place: Any, snap: dict[str, Any]) -> dict[str, Any]:
    """The 02 §19 row plus the blocks `travel_alerts` and `packing_suggestions` need."""
    cur = snap.get("current") or {}
    today = (snap.get("daily") or [{}])[0]
    hourly = snap.get("hourly") or []
    warnings = snap.get("warnings") or []
    rank = {"yellow": 1, "orange": 2, "red": 3}
    highest = None
    for w in warnings:
        sev = w.get("severity")
        if highest is None or rank.get(sev, 0) > rank.get(highest, 0):
            highest = sev
    code = cur.get("condition_code")
    return {
        "id": place.id,
        "name": place.name,
        "lat": place.lat,
        "lon": place.lon,
        "country": place.country,
        "local_time": cur.get("time"),
        "temp_c": cur.get("temp_c"),
        "condition_code": code,
        "icon": icons.for_code(code, bool(cur.get("is_day", True))),
        "tmax_c": today.get("tmax_c"),
        "tmin_c": today.get("tmin_c"),
        "precip_prob_pct": (hourly[0].get("precip_prob_pct") if hourly else None),
        "highest_severity": highest,
        # extras consumed by travel_alerts / packing_suggestions
        "flight_risk": (snap.get("derived") or {}).get("flight_risk") or {},
        "packing": (snap.get("derived") or {}).get("packing") or {},
        "warnings": warnings,
    }


async def place_extras(
    places: list[Any],
    *,
    scenario: str,
    now: datetime | None,
    admin_warnings: list[dict[str, Any]] | None = None,
) -> list[dict[str, Any]]:
    """05 §Performance — saved-place snapshots fetched concurrently, capped at 5."""
    subset = places[:MAX_PLACE_SNAPSHOTS]
    if not subset:
        return []
    results = await asyncio.gather(
        *(
            snapshot_svc.get_snapshot(
                p.lat, p.lon, scenario=scenario, now=now, admin_warnings=admin_warnings
            )
            for p in subset
        ),
        return_exceptions=True,
    )
    out: list[dict[str, Any]] = []
    for place, res in zip(subset, results):
        if isinstance(res, BaseException):
            log.info("place snapshot failed for %s: %s", place.name, res)
            continue
        out.append(place_summary(place, res.model_dump()))
    return out


# --------------------------------------------------------------------------- route


@router.get("/home", response_model=HomeResponse)
async def get_home(
    lat: float | None = Query(None, ge=-90, le=90),
    lon: float | None = Query(None, ge=-180, le=180),
    place_id: str | None = Query(None),
    lang: str | None = Query(None),
    personas: str | None = Query(None),
    now_override: str | None = Query(None),
    scenario: str | None = Query(None),
    event_date: str | None = Query(None, pattern=r"^\d{4}-\d{2}-\d{2}$"),
    lite: int = Query(0),
    accept_language: str | None = Header(default=None),
    user: UserModel = Depends(current_user),
    db: Session = Depends(get_db),
) -> HomeResponse:
    t0 = time.perf_counter()

    lat_v, lon_v = await resolve_location(db, user, lat, lon, place_id)

    name = scenario or demo_state.scenario or settings.default_scenario
    if not scenarios.exists(name) and name != "live":
        raise ValidationError(f"Unknown scenario '{name}'", code="unknown_scenario")

    override = now_override or demo_state.now_override
    now: datetime | None = None
    if override:
        try:
            now = parse_any(override)
        except ValueError as exc:
            raise ValidationError(f"Bad now_override: {exc}") from exc

    language = normalize_lang(lang or user.language or accept_language)
    is_lite = bool(lite)

    # A3: live admin-pushed warnings are merged into the snapshot (and location-filtered
    # there). Passing a non-empty list also bypasses the 5-minute snapshot cache, which is what
    # we want — a warning pushed 10 s ago must show up on the next /home.
    admin_warnings = admin_warnings_svc.active_warnings(db, now=now) or None

    snapshot: Snapshot = await snapshot_svc.get_snapshot(
        lat_v, lon_v, scenario=name, now=now, admin_warnings=admin_warnings
    )
    snap = snapshot.model_dump()
    location = LocationResult.model_validate(snap["location"])

    tzinfo = tz_for(location.timezone)
    local_now = now.astimezone(tzinfo) if now else now_in(tzinfo)
    local_now = local_now.replace(microsecond=0)

    saved_places = users_svc.places_for(db, user.id)
    radar, places = await asyncio.gather(
        radar_extra(lat_v, lon_v, snap),
        place_extras(
            saved_places, scenario=name, now=now, admin_warnings=admin_warnings
        ),
    )

    pins, hidden = users_svc.prefs_for(db, user.id)
    override_personas = parse_personas(personas)
    if override_personas is not None:
        persona_rows = users_svc.normalize_personas(override_personas)
    else:
        persona_rows = list(user.personas or [])

    # S1 · Learning v2. The engine stays pure — the model is loaded here, like every other
    # input, and only when ENGINE_ML=1. `None` (the default) is the v1 path, unchanged.
    ml_model = ml_ranker.model_for(db, user.id) if settings.ml_on else None

    profile = UserProfile(
        personas=[(p["id"], float(p.get("weight", 1.0))) for p in persona_rows],
        pins=pins,
        hidden=hidden,
        engagement=users_svc.engagement_for(db, user.id),
        saved_places=[users_svc.place_to_schema(p).model_dump() for p in saved_places],
        language=language,
        units=user.units or "metric",
        ml=ml_model,
    )

    ctx = build_context(
        now=local_now,
        location=snap["location"],
        active_warnings=snap.get("warnings") or [],
        scenario=name,
        lang=language,
        event_date=event_date,
        lite=is_lite,
    )

    bundle = Bundle(snap=snap, extras={"radar": radar, "places": places})
    response = engine_home.assemble(
        bundle=bundle, ctx=ctx, profile=profile, location=location
    )

    # 05 §Performance — one timing line per request at INFO.
    log.info(
        "home lat=%s lon=%s personas=%s scenario=%s lang=%s lite=%d warnings=%d %dms",
        round(lat_v, 3),
        round(lon_v, 3),
        ",".join(profile.persona_ids) or "-",
        name,
        language,
        int(is_lite),
        len(ctx.active_warnings),
        int((time.perf_counter() - t0) * 1000),
    )
    return response


@router.get("/home/now", include_in_schema=False)
async def home_clock() -> dict[str, Any]:
    """Tiny helper the demo console uses to read the effective clock."""
    return {"server_time": iso(now_in(tz_for("Asia/Kolkata"))), "now_override": demo_state.now_override}
