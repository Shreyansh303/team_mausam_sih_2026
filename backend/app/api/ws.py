"""WebSocket `/ws/alerts` + the in-memory connection registry (04 §WebSocket, 05 §WS manager).

The registry lives here; **every broadcast is fired from `api/admin.py`**, right after the DB
write. `app/engine/` stays pure and never touches sockets.

Server → client (04, verbatim):
    {"type":"hello","server_time":"…","scenario":"live"}
    {"type":"ping"}                                    every 30 s
    {"type":"warning_issued","warning":Warning,"affects_you":true}
    {"type":"warning_cleared","id":"…"}
    {"type":"scenario_changed","scenario":"heatwave"}
    {"type":"now_override","now":"…"|null}
Client → server: {"type":"pong"} · {"type":"location","lat":..,"lon":..}
"""

from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass
from typing import Any

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect

from app.config import settings
from app.core import geo
from app.core.errors import UnauthorizedError
from app.core.security import user_id_from_token
from app.core.timeutil import now_in, iso, tz_for
from app.services import warnings as warnings_svc
from app.state import demo_state

log = logging.getLogger("mausam.ws")

router = APIRouter(tags=["ws"])

#: 04 — the server pings every 30 s and the client answers `{"type":"pong"}`.
PING_INTERVAL_S = 30.0
#: A curated city this far from the client stands in for its district/state.
NEAREST_CITY_KM = 60.0
#: 1008 = policy violation (RFC 6455) — used for a bad/missing token.
CLOSE_POLICY_VIOLATION = 1008


@dataclass
class Client:
    """One live socket: `{ws: {user_id, lat, lon}}` per 05, plus the resolved district/state."""

    ws: WebSocket
    user_id: str | None = None
    lat: float | None = None
    lon: float | None = None
    district: str | None = None
    state: str | None = None

    def set_location(self, lat: float | None, lon: float | None) -> None:
        self.lat = lat
        self.lon = lon
        self.district = None
        self.state = None
        if lat is None or lon is None:
            return
        city, dist_km = geo.nearest_city(lat, lon)
        if city and dist_km <= NEAREST_CITY_KM:
            self.district = city.get("admin2") or city.get("name")
            self.state = city.get("admin1")


class ConnectionManager:
    """In-memory socket registry. One process, one manager — good enough for the demo."""

    def __init__(self) -> None:
        self._clients: dict[WebSocket, Client] = {}

    # --- registry ---------------------------------------------------------
    async def connect(
        self, ws: WebSocket, *, user_id: str | None, lat: float | None, lon: float | None
    ) -> Client:
        await ws.accept()
        client = Client(ws=ws, user_id=user_id)
        client.set_location(lat, lon)
        self._clients[ws] = client
        log.info("ws connect user=%s lat=%s lon=%s (total=%d)", user_id, lat, lon, self.count)
        return client

    def disconnect(self, ws: WebSocket) -> None:
        if self._clients.pop(ws, None) is not None:
            log.info("ws disconnect (total=%d)", self.count)

    @property
    def count(self) -> int:
        return len(self._clients)

    def clients(self) -> list[Client]:
        return list(self._clients.values())

    def reset(self) -> None:
        """Forget every socket (tests only — does not close them)."""
        self._clients.clear()

    # --- sending ----------------------------------------------------------
    async def send(self, client: Client, message: dict[str, Any]) -> bool:
        """Send one message; drop the connection when the socket is dead."""
        try:
            await client.ws.send_json(message)
            return True
        except Exception as exc:  # noqa: BLE001 - any socket error means "gone"
            log.info("dropping dead ws connection: %s", exc)
            self.disconnect(client.ws)
            return False

    async def broadcast(self, mtype: str, payload: dict[str, Any] | None = None) -> int:
        """Fan a message out to every client. Returns how many got it."""
        message = {"type": mtype, **(payload or {})}
        sent = 0
        for client in self.clients():
            if await self.send(client, message):
                sent += 1
        return sent

    async def broadcast_warning(self, warning: dict[str, Any]) -> int:
        """`warning_issued` with per-client `affects_you` (radius / district / state match)."""
        sent = 0
        for client in self.clients():
            affects = False
            if client.lat is not None and client.lon is not None:
                affects = warnings_svc.applies_to(
                    warning,
                    lat=client.lat,
                    lon=client.lon,
                    district=client.district,
                    state=client.state,
                )
            message = {
                "type": "warning_issued",
                "warning": warning,
                "affects_you": bool(affects),
            }
            if await self.send(client, message):
                sent += 1
        return sent


#: Process-wide singleton used by `api/admin.py`.
manager = ConnectionManager()


def connected_clients() -> int:
    return manager.count


async def broadcast(mtype: str, payload: dict[str, Any] | None = None) -> int:
    return await manager.broadcast(mtype, payload)


async def broadcast_warning(warning: dict[str, Any]) -> int:
    return await manager.broadcast_warning(warning)


def server_time() -> str:
    """The clock the client should trust: the global demo override, else real IST."""
    if demo_state.now_override:
        return demo_state.now_override
    return iso(now_in(tz_for("Asia/Kolkata")))


def hello_message() -> dict[str, Any]:
    return {"type": "hello", "server_time": server_time(), "scenario": demo_state.scenario}


async def _pinger(ws: WebSocket) -> None:
    """04 — `{"type":"ping"}` every 30 s; a failed send drops the connection."""
    try:
        while True:
            await asyncio.sleep(PING_INTERVAL_S)
            client = manager._clients.get(ws)  # noqa: SLF001 - same module
            if client is None:
                return
            if not await manager.send(client, {"type": "ping"}):
                return
    except asyncio.CancelledError:  # pragma: no cover - normal shutdown
        raise


def _authenticate(token: str | None) -> str | None:
    """Resolve the JWT subject. A bad token is always fatal; a missing one only outside demos."""
    if token:
        return user_id_from_token(token)
    if settings.demo_mode:
        return None
    raise UnauthorizedError("Missing token")


@router.websocket("/ws/alerts")
async def alerts(
    ws: WebSocket,
    token: str | None = Query(default=None),
    lat: float | None = Query(default=None, ge=-90, le=90),
    lon: float | None = Query(default=None, ge=-180, le=180),
) -> None:
    try:
        user_id = _authenticate(token)
    except UnauthorizedError as exc:
        await ws.close(code=CLOSE_POLICY_VIOLATION, reason=exc.message)
        return

    client = await manager.connect(ws, user_id=user_id, lat=lat, lon=lon)
    await manager.send(client, hello_message())
    ping_task = asyncio.create_task(_pinger(ws))
    try:
        while True:
            raw = await ws.receive_json()
            if not isinstance(raw, dict):
                continue
            kind = raw.get("type")
            if kind == "pong":
                continue
            if kind == "location":
                # 04: the app sends this when the user changes location. No reply — the next
                # `warning_issued` simply carries an `affects_you` for the new coordinates.
                try:
                    client.set_location(float(raw["lat"]), float(raw["lon"]))
                except (KeyError, TypeError, ValueError):
                    log.info("ignoring malformed location frame: %r", raw)
    except WebSocketDisconnect:
        pass
    except Exception as exc:  # noqa: BLE001 - malformed frame, client vanished, …
        log.info("ws closed: %s", exc)
    finally:
        ping_task.cancel()
        manager.disconnect(ws)
