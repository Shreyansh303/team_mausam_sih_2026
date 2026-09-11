"""Push transport + device registry (S3 — design in `docs/09_PUSH_NOTIFICATIONS.md`).

`api/ws.py` only reaches an app that is **open**. This module is the second delivery path: the
same four broadcasts `api/admin.py` fires on the socket are also handed to a `PushTransport`,
which can wake a closed handset.

Two transports:

* `NoopTransport` — the default. Logs what *would* have been sent at INFO and nothing leaves the
  process. This is what runs with zero configuration, so the demo setup needs no Firebase project,
  no credentials and no keys (docs/00_VISION.md, principle 9: no secrets in the repository).
* `FcmTransport` — FCM HTTP v1 (`POST /v1/projects/{project}/messages:send`), data-only messages,
  OAuth2 access token minted from a service-account JSON. Selected **only** when both
  `FCM_SERVICE_ACCOUNT_FILE` and `FCM_PROJECT_ID` are set and the file exists.

`affects_you` is computed per device from the stored `lat`/`lon` with the same
`services/warnings.applies_to()` rule the WebSocket uses, so a device in Mumbai and a device in
Delhi get the same warning with a different flag — exactly like two sockets.
"""

from __future__ import annotations

import asyncio
import json
import logging
import time
from collections.abc import Iterable, Sequence
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any, Protocol

import httpx
import jwt
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.core import geo
from app.core.timeutil import UTC
from app.models.device import MAX_DEVICES_PER_USER, Device
from app.services import warnings as warnings_svc

log = logging.getLogger("mausam.push")

#: FCM HTTP v1 send endpoint. One message per device — v1 has no multicast in REST.
FCM_SEND_URL = "https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
#: Google's OAuth2 token endpoint (the service-account JSON usually carries the same value).
GOOGLE_TOKEN_URI = "https://oauth2.googleapis.com/token"
FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
JWT_BEARER_GRANT = "urn:ietf:params:oauth:grant-type:jwt-bearer"
#: Google caps the self-signed assertion at one hour.
ASSERTION_TTL_S = 3600
#: Renew the access token this many seconds before it actually expires.
TOKEN_SKEW_S = 60
#: A demo registry is small; this keeps a burst of sends from opening 500 sockets at once.
MAX_CONCURRENT_SENDS = 8
#: Same radius `api/ws.py` uses to turn a coordinate into a district/state for `applies_to`.
NEAREST_CITY_KM = 60.0


class PushError(RuntimeError):
    """Configuration or upstream failure inside a transport. Never reaches the client."""


@dataclass(frozen=True, slots=True)
class PushMessage:
    """One data-only message for one device. FCM `data` values must all be strings."""

    token: str
    data: dict[str, str]


@dataclass(slots=True)
class PushResult:
    sent: int = 0
    failed: int = 0
    #: Tokens FCM rejected as unregistered — pruned from the registry by `_deliver()`.
    invalid_tokens: list[str] = field(default_factory=list)

    @property
    def total(self) -> int:
        return self.sent + self.failed


class PushTransport(Protocol):
    """What `api/admin.py` needs from a push backend."""

    name: str

    async def send(self, messages: Sequence[PushMessage]) -> PushResult:  # pragma: no cover
        ...


# --------------------------------------------------------------------------- transports


class NoopTransport:
    """Default transport: log the intent at INFO, deliver nothing."""

    name = "noop"

    async def send(self, messages: Sequence[PushMessage]) -> PushResult:
        if not messages:
            return PushResult()
        kind = messages[0].data.get("type", "message")
        affected = sum(1 for m in messages if m.data.get("affects_you") == "true")
        log.info(
            "push (noop): %s → %d device(s)%s — set FCM_SERVICE_ACCOUNT_FILE and FCM_PROJECT_ID "
            "to deliver for real",
            kind,
            len(messages),
            f", affects_you=true for {affected}" if kind == "warning_issued" else "",
        )
        for m in messages:
            log.debug("push (noop) → %s %s", redact(m.token), m.data)
        return PushResult(sent=len(messages))


class FcmTransport:
    """FCM HTTP v1 data messages, authenticated with a service-account JWT (RS256 → OAuth2).

    The flow is the documented one: sign `{iss, scope, aud, iat, exp}` with the service account's
    private key, exchange the assertion at `token_uri` for an access token (cached for its
    lifetime), then `POST {"message": {...}}` per device with `Authorization: Bearer <token>`.
    """

    name = "fcm"

    def __init__(
        self,
        *,
        service_account_file: str | Path,
        project_id: str,
        send_url_template: str = FCM_SEND_URL,
        timeout_s: float | None = None,
    ) -> None:
        self.service_account_file = Path(service_account_file)
        self.project_id = project_id
        self._send_url_template = send_url_template
        self.timeout_s = timeout_s if timeout_s is not None else settings.http_timeout_s
        self._account: dict[str, Any] | None = None
        self._access_token: str | None = None
        self._token_expires_at: float = 0.0

    # --- credentials ------------------------------------------------------
    @property
    def send_url(self) -> str:
        return self._send_url_template.format(project_id=self.project_id)

    def service_account(self) -> dict[str, Any]:
        """Read (and memoise) the service-account JSON. Never logged, never echoed."""
        if self._account is None:
            try:
                with self.service_account_file.open("r", encoding="utf-8") as fh:
                    account = json.load(fh)
            except (OSError, ValueError) as exc:
                raise PushError(f"cannot read {self.service_account_file}: {exc}") from exc
            missing = [k for k in ("client_email", "private_key") if not account.get(k)]
            if missing:
                raise PushError(
                    f"{self.service_account_file} is not a service account key "
                    f"(missing {', '.join(missing)})"
                )
            self._account = account
        return self._account

    def _assertion(self, account: dict[str, Any], now: float) -> str:
        headers = {"kid": account["private_key_id"]} if account.get("private_key_id") else None
        claims = {
            "iss": account["client_email"],
            "scope": FCM_SCOPE,
            "aud": account.get("token_uri") or GOOGLE_TOKEN_URI,
            "iat": int(now),
            "exp": int(now + ASSERTION_TTL_S),
        }
        try:
            return jwt.encode(claims, account["private_key"], algorithm="RS256", headers=headers)
        except Exception as exc:  # noqa: BLE001 - bad key, or PyJWT built without `crypto`
            raise PushError(
                f"cannot sign the OAuth2 assertion ({exc}); "
                "install the crypto extra: pip install 'PyJWT[crypto]'"
            ) from exc

    async def access_token(self) -> str:
        """Cached OAuth2 access token for the service account."""
        now = time.time()
        if self._access_token and now < self._token_expires_at:
            return self._access_token
        account = self.service_account()
        token_uri = account.get("token_uri") or GOOGLE_TOKEN_URI
        try:
            async with httpx.AsyncClient(timeout=self.timeout_s) as client:
                resp = await client.post(
                    token_uri,
                    data={
                        "grant_type": JWT_BEARER_GRANT,
                        "assertion": self._assertion(account, now),
                    },
                )
        except httpx.HTTPError as exc:
            raise PushError(f"token endpoint unreachable: {exc}") from exc
        if resp.status_code >= 400:
            raise PushError(f"token endpoint returned HTTP {resp.status_code}: {resp.text[:200]}")
        try:
            body = resp.json()
        except ValueError as exc:
            raise PushError(f"token endpoint returned non-JSON: {exc}") from exc
        token = body.get("access_token")
        if not token:
            raise PushError("token endpoint returned no access_token")
        self._access_token = str(token)
        self._token_expires_at = now + float(body.get("expires_in", ASSERTION_TTL_S)) - TOKEN_SKEW_S
        return self._access_token

    # --- sending ----------------------------------------------------------
    async def send(self, messages: Sequence[PushMessage]) -> PushResult:
        if not messages:
            return PushResult()
        try:
            access_token = await self.access_token()
        except PushError as exc:
            log.warning("fcm: no access token (%s); %d message(s) dropped", exc, len(messages))
            return PushResult(failed=len(messages))

        result = PushResult()
        gate = asyncio.Semaphore(MAX_CONCURRENT_SENDS)
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json; charset=utf-8",
        }
        async with httpx.AsyncClient(timeout=self.timeout_s, headers=headers) as client:
            outcomes = await asyncio.gather(
                *(self._send_one(client, gate, m) for m in messages)
            )
        for message, (ok, invalid) in zip(messages, outcomes, strict=True):
            if ok:
                result.sent += 1
            else:
                result.failed += 1
            if invalid:
                result.invalid_tokens.append(message.token)
        log.info(
            "push (fcm): %s → %d sent, %d failed, %d stale token(s)",
            messages[0].data.get("type", "message"),
            result.sent,
            result.failed,
            len(result.invalid_tokens),
        )
        return result

    async def _send_one(
        self, client: httpx.AsyncClient, gate: asyncio.Semaphore, message: PushMessage
    ) -> tuple[bool, bool]:
        """Returns `(delivered, token_is_dead)`."""
        async with gate:
            try:
                resp = await client.post(self.send_url, json=fcm_body(message))
            except httpx.HTTPError as exc:
                log.warning("fcm: %s → transport error %s", redact(message.token), exc)
                return False, False
        if resp.status_code < 300:
            return True, False
        body = resp.text[:300]
        dead = is_dead_token(resp.status_code, body)
        log.warning(
            "fcm: %s → HTTP %s %s%s",
            redact(message.token),
            resp.status_code,
            body,
            " (token dropped)" if dead else "",
        )
        return False, dead


def fcm_body(message: PushMessage) -> dict[str, Any]:
    """The FCM v1 `{"message": …}` envelope for one device.

    Data-only on purpose: the app builds the tray notification itself, in the user's language,
    from the catalogue it already ships (a `notification` block would arrive in whatever language
    the server picked). `android.priority=high` wakes a backgrounded app; the APNs block is the
    iOS background push (`content-available: 1` must be sent at priority 5 — Apple rejects 10).
    See `docs/09_PUSH_NOTIFICATIONS.md` §Android / iOS delivery.
    """
    return {
        "message": {
            "token": message.token,
            "data": dict(message.data),
            "android": {"priority": "high"},
            "apns": {
                "headers": {"apns-priority": "5", "apns-push-type": "background"},
                "payload": {"aps": {"content-available": 1}},
            },
        }
    }


def is_dead_token(status: int, body: str) -> bool:
    """404 UNREGISTERED, or a 400 naming the registration token → drop the row."""
    if status == 404:
        return True
    lowered = body.lower()
    return status == 400 and ("registration token" in lowered or "unregistered" in lowered)


def redact(token: str) -> str:
    """Push tokens are send-capabilities. Logs and `/admin/devices` only ever show the tail."""
    return f"…{token[-6:]}" if len(token) > 6 else "…"


# --------------------------------------------------------------------------- selection

_transport: PushTransport | None = None


def build_transport() -> PushTransport:
    """FCM when both env vars are set and the key file exists, else the noop transport."""
    path = (settings.fcm_service_account_file or "").strip()
    project_id = (settings.fcm_project_id or "").strip()
    if not path or not project_id:
        return NoopTransport()
    if not Path(path).is_file():
        log.warning(
            "FCM_SERVICE_ACCOUNT_FILE=%s does not exist — staying on the noop push transport", path
        )
        return NoopTransport()
    log.info("push transport: FCM HTTP v1, project %s", project_id)
    return FcmTransport(service_account_file=path, project_id=project_id)


def transport() -> PushTransport:
    global _transport
    if _transport is None:
        _transport = build_transport()
    return _transport


def reset_transport() -> None:
    """Forget the selected transport (tests, and any future config reload)."""
    global _transport
    _transport = None


# --------------------------------------------------------------------------- registry


def devices_for(db: Session, user_id: str) -> list[Device]:
    stmt = select(Device).where(Device.user_id == user_id).order_by(Device.updated_at.desc())
    return list(db.execute(stmt).scalars().all())


def all_devices(db: Session) -> list[Device]:
    return list(db.execute(select(Device).order_by(Device.updated_at.desc())).scalars().all())


def device_count(db: Session) -> int:
    return len(all_devices(db))


def register(
    db: Session,
    *,
    user_id: str,
    token: str,
    lat: float | None = None,
    lon: float | None = None,
    lang: str = "en",
    platform: str = "android",
) -> Device:
    """Upsert one token. A token that reappears under another account moves to it."""
    device = db.get(Device, token)
    now = datetime.now(UTC)
    if device is None:
        device = Device(token=token, user_id=user_id, created_at=now)
        db.add(device)
    device.user_id = user_id
    device.lat = lat
    device.lon = lon
    device.lang = lang
    device.platform = platform
    device.updated_at = now
    db.flush()
    _evict_oldest(db, user_id)
    return device


def _evict_oldest(db: Session, user_id: str) -> None:
    """Keep at most `MAX_DEVICES_PER_USER` rows per account (reinstalls mint new tokens)."""
    rows = devices_for(db, user_id)
    for stale in rows[MAX_DEVICES_PER_USER:]:
        log.info("device registry: evicting %s for %s (over the cap)", redact(stale.token), user_id)
        db.delete(stale)
    if len(rows) > MAX_DEVICES_PER_USER:
        db.flush()


def unregister(db: Session, *, user_id: str, token: str) -> bool:
    """Delete one of **this user's** tokens. Someone else's token is a miss, not a delete."""
    device = db.get(Device, token)
    if device is None or device.user_id != user_id:
        return False
    db.delete(device)
    db.flush()
    return True


def prune(db: Session, tokens: Iterable[str]) -> int:
    removed = 0
    for token in tokens:
        device = db.get(Device, token)
        if device is not None:
            db.delete(device)
            removed += 1
    if removed:
        db.flush()
        log.info("device registry: pruned %d stale token(s)", removed)
    return removed


# --------------------------------------------------------------------------- payloads


def _area(lat: float, lon: float) -> tuple[str | None, str | None]:
    """(district, state) for a coordinate — the same lookup `api/ws.py` does per socket."""
    city, dist_km = geo.nearest_city(lat, lon)
    if city and dist_km <= NEAREST_CITY_KM:
        return (city.get("admin2") or city.get("name")), city.get("admin1")
    return None, None


def affects(device: Device, warning: dict[str, Any]) -> bool:
    """`affects_you` for one device (04 §WebSocket — identical rule, per stored coordinate)."""
    if device.lat is None or device.lon is None:
        return False
    district, state = _area(device.lat, device.lon)
    return bool(
        warnings_svc.applies_to(
            warning, lat=device.lat, lon=device.lon, district=district, state=state
        )
    )


def _stringify(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def data_payload(mtype: str, payload: dict[str, Any] | None = None) -> dict[str, str]:
    """A WS broadcast as an FCM `data` dict — every value a string, `None` → `""`."""
    data = {"type": mtype}
    for key, value in (payload or {}).items():
        data[key] = _stringify(value)
    return data


def warning_messages(devices: Sequence[Device], warning: dict[str, Any]) -> list[PushMessage]:
    """One `warning_issued` message per device, `affects_you` computed for each.

    The whole 04 `Warning` travels as a JSON string in `data.warning`; the handful of flat keys
    next to it let the app raise a tray notification without parsing it first.
    """
    blob = json.dumps(warning, ensure_ascii=False, separators=(",", ":"))
    base = {
        "type": "warning_issued",
        "warning": blob,
        "id": str(warning.get("id", "")),
        "severity": str(warning.get("severity", "")),
        "hazard": str(warning.get("hazard", "")),
        "title": str(warning.get("title", "")),
        "color_hex": str(warning.get("color_hex", "")),
    }
    return [
        PushMessage(token=d.token, data={**base, "affects_you": _stringify(affects(d, warning))})
        for d in devices
    ]


# --------------------------------------------------------------------------- delivery


async def _deliver(db: Session, messages: Sequence[PushMessage]) -> PushResult:
    """Hand the messages to the active transport. A push failure never fails the request."""
    active = transport()
    try:
        result = await active.send(messages)
    except Exception as exc:  # noqa: BLE001 - a broken transport must not 500 the admin call
        log.warning("push transport %s failed: %s", active.name, exc)
        return PushResult(failed=len(messages))
    if result.invalid_tokens:
        prune(db, result.invalid_tokens)
    return result


async def notify_warning(db: Session, warning: dict[str, Any]) -> PushResult:
    """`warning_issued` to every registered device, `affects_you` per device."""
    devices = all_devices(db)
    if not devices:
        return PushResult()
    return await _deliver(db, warning_messages(devices, warning))


async def notify(db: Session, mtype: str, payload: dict[str, Any] | None = None) -> PushResult:
    """`warning_cleared` / `scenario_changed` / `now_override` — data-only, same for everyone."""
    devices = all_devices(db)
    if not devices:
        return PushResult()
    data = data_payload(mtype, payload)
    return await _deliver(db, [PushMessage(token=d.token, data=data) for d in devices])
