"""Admin routes, admin warnings in `/home`, the WebSocket protocol and `lite` trimming.

Everything runs offline: `conftest.py` replays the recorded upstream payloads through respx and
`TestClient` drives both HTTP and WebSocket traffic on the same event loop.
"""

from __future__ import annotations

from datetime import timedelta

import pytest

from app.core import cache
from app.core import db as db_core
from app.core.timeutil import iso, parse_any
from app.models.admin_warning import AdminWarning, new_warning_id
from app.services import admin_warnings as admin_svc

from tests.conftest import DELHI, MUMBAI

ADMIN = {"X-Admin-Key": "mausam-admin"}
#: A Tuesday morning in IST — the same instant the docs/fixtures use.
NOW = "2026-09-08T07:30:00+05:30"

DELHI_WARNING = {
    "severity": "orange",
    "hazard": "thunderstorm",
    "title": "Thunderstorm warning — Delhi",
    "description": "Thunderstorm with lightning and gusty winds likely in the next 3 hours.",
    "district": "New Delhi",
    "state": "Delhi",
    "lat": DELHI[0],
    "lon": DELHI[1],
    "radius_km": 75,
    "ttl_minutes": 120,
}


def home(client, guest, **params):
    query = {"lat": DELHI[0], "lon": DELHI[1], "personas": "parent", **params}
    res = client.get("/api/v1/home", params=query, headers=guest["headers"])
    assert res.status_code == 200, res.text
    return res.json()


def push(client, **overrides):
    body = {**DELHI_WARNING, **overrides}
    res = client.post("/api/v1/admin/warnings", json=body, headers=ADMIN)
    assert res.status_code == 200, res.text
    return res.json()


# --------------------------------------------------------------------- admin auth


def test_admin_requires_the_key(client):
    assert client.get("/api/v1/admin/state").status_code == 401
    assert client.get("/api/v1/admin/state", headers={"X-Admin-Key": "nope"}).status_code == 401
    res = client.post("/api/v1/admin/warnings", json=DELHI_WARNING, headers={"X-Admin-Key": "nope"})
    assert res.status_code == 401
    assert res.json()["error"]["code"] == "unauthorized"
    # ... and with the right key it works.
    assert client.get("/api/v1/admin/state", headers=ADMIN).status_code == 200


def test_console_is_html_and_needs_no_key(client):
    res = client.get("/admin/console")
    assert res.status_code == 200
    assert res.headers["content-type"].startswith("text/html")
    body = res.text
    for needle in (
        "Mausam demo console",
        "Orange thunderstorm — Delhi",
        "Red cyclone — Goa",
        "Orange dense fog — Delhi",
        "Red heatwave — Nagpur",
        "Orange very heavy rain — Mumbai",
        "/admin/warnings",
        "/locations/popular",
        "X-Admin-Key",
        "localStorage",
    ):
        assert needle in body, needle


# --------------------------------------------------------------------- state


def test_scenario_and_now_override_become_the_global_default(client, guest):
    res = client.post("/api/v1/admin/scenario", json={"name": "thunderstorm"}, headers=ADMIN)
    assert res.status_code == 200
    assert res.json()["scenario"] == "thunderstorm"
    assert client.get("/api/v1/health").json()["scenario"] == "thunderstorm"
    # /home picks the global scenario up when the request does not override it
    assert home(client, guest)["context"]["scenario"] == "thunderstorm"
    # ... and a per-request scenario still wins (04 §GET /home)
    assert home(client, guest, scenario="clear_pleasant")["context"]["scenario"] == "clear_pleasant"

    bad = client.post("/api/v1/admin/scenario", json={"name": "nope"}, headers=ADMIN)
    assert bad.status_code == 400
    assert bad.json()["error"]["code"] == "unknown_scenario"

    res = client.post("/api/v1/admin/now-override", json={"now": NOW}, headers=ADMIN)
    assert res.status_code == 200
    assert res.json()["now_override"] == NOW
    assert home(client, guest)["context"]["now"] == NOW
    assert client.get("/home/now").json()["now_override"] == NOW

    res = client.post("/api/v1/admin/now-override", json={"now": None}, headers=ADMIN)
    assert res.json()["now_override"] is None


def test_naive_now_override_is_read_as_ist(client):
    res = client.post(
        "/api/v1/admin/now-override", json={"now": "2026-09-08T07:30"}, headers=ADMIN
    )
    assert res.status_code == 200
    assert res.json()["now_override"] == NOW


def test_reset_user(client, guest):
    uid = guest["user"]["id"]
    client.post(
        "/api/v1/events",
        json={"events": [{"type": "aqi", "action": "pin", "ts": NOW}]},
        headers=guest["headers"],
    )
    assert "aqi" in client.get("/api/v1/me/card-prefs", headers=guest["headers"]).json()["pins"]

    res = client.post("/api/v1/admin/reset-user", json={"user_id": uid}, headers=ADMIN)
    assert res.status_code == 200 and res.json()["ok"] is True
    prefs = client.get("/api/v1/me/card-prefs", headers=guest["headers"]).json()
    assert prefs["pins"] == []

    missing = client.post("/api/v1/admin/reset-user", json={"user_id": "usr_nope"}, headers=ADMIN)
    assert missing.status_code == 404


# --------------------------------------------------------------------- warnings → /home


def test_admin_warning_is_pinned_on_home_with_a_banner(client, guest):
    before = home(client, guest)
    assert before["context"]["warning_count"] == 0
    assert before["banner"] is None
    assert "warnings" not in [c["type"] for c in before["pinned"]]

    warning = push(client)
    assert warning["source"] == "admin"
    assert warning["id"].startswith("wrn_")
    assert warning["radius_km"] == 75
    assert warning["color_hex"] == "#F28C28"
    # ttl_minutes = 120 → valid_to is two hours after issued_at
    assert parse_any(warning["valid_to"]) - parse_any(warning["issued_at"]) == timedelta(hours=2)

    after = home(client, guest)
    assert after["context"]["warning_count"] == 1
    assert after["banner"] is not None
    assert after["banner"]["warning_id"] == warning["id"]
    assert after["banner"]["severity"] == "orange"

    pinned = [c for c in after["pinned"] if c["type"] == "warnings"]
    assert pinned, [c["type"] for c in after["pinned"]]
    card = pinned[0]
    assert card["urgency"] >= 0.8
    assert card["data"]["warnings"][0]["id"] == warning["id"]
    assert after["sources"]["warnings"] == "admin"

    # GET /admin/state lists it, DELETE removes it from /home again
    state = client.get("/api/v1/admin/state", headers=ADMIN).json()
    assert [w["id"] for w in state["warnings"]] == [warning["id"]]

    gone = client.delete(f"/api/v1/admin/warnings/{warning['id']}", headers=ADMIN)
    assert gone.status_code == 200 and gone.json()["ok"] is True
    assert client.delete(f"/api/v1/admin/warnings/{warning['id']}", headers=ADMIN).status_code == 404

    final = home(client, guest)
    assert final["context"]["warning_count"] == 0
    assert final["banner"] is None
    assert "warnings" not in [c["type"] for c in final["pinned"]]


def test_admin_write_drops_snapshots_but_keeps_provider_caches_warm(client, guest):
    """The write must not be hidden by a cached snapshot — and must not cost a cold refetch."""
    home(client, guest)
    warm = cache.stats()
    assert warm.get("snapshot", 0) > 0
    assert warm.get("om_forecast", 0) > 0

    push(client)
    after = cache.stats()
    assert after.get("snapshot", 0) == 0
    for bucket in ("om_forecast", "om_air", "radar"):
        assert after.get(bucket, 0) == warm.get(bucket, 0), bucket


def test_admin_warning_is_filtered_by_location(client, guest):
    push(client)
    far = client.get(
        "/api/v1/home",
        params={"lat": MUMBAI[0], "lon": MUMBAI[1], "personas": "parent"},
        headers=guest["headers"],
    )
    assert far.status_code == 200
    assert far.json()["context"]["warning_count"] == 0


def test_expired_admin_warning_vanishes_from_home_and_state(client, guest):
    """A row past its TTL is never loaded — no delete needed (05 §Warnings merge)."""
    push(client, ttl_minutes=120)
    assert home(client, guest)["context"]["warning_count"] == 1

    expired_id = new_warning_id()
    with db_core.session_scope() as session:
        stale = parse_any("2020-01-01T00:00:00+05:30")
        session.add(
            AdminWarning(
                id=expired_id,
                severity="red",
                hazard="cyclone",
                title="Stale cyclone warning",
                description="",
                district="New Delhi",
                state="Delhi",
                lat=DELHI[0],
                lon=DELHI[1],
                radius_km=200,
                issued_at=iso(stale - timedelta(hours=2)),
                valid_from=iso(stale - timedelta(hours=2)),
                valid_to=iso(stale),
                expires_at_ts=stale.timestamp(),
            )
        )

    with db_core.session_scope() as session:
        assert expired_id in [w["id"] for w in admin_svc.all_warnings(session)]
        assert expired_id not in [w["id"] for w in admin_svc.active_warnings(session)]

    state = client.get("/api/v1/admin/state", headers=ADMIN).json()
    assert expired_id not in [w["id"] for w in state["warnings"]]

    payload = home(client, guest)
    assert payload["context"]["warning_count"] == 1
    card = next(c for c in payload["pinned"] if c["type"] == "warnings")
    assert expired_id not in [w["id"] for w in card["data"]["warnings"]]
    assert payload["banner"]["severity"] == "orange"  # not the stale red one


def test_warning_body_is_validated(client):
    bad_hazard = client.post(
        "/api/v1/admin/warnings", json={**DELHI_WARNING, "hazard": "meteors"}, headers=ADMIN
    )
    assert bad_hazard.status_code == 400
    untargeted = client.post(
        "/api/v1/admin/warnings",
        json={"severity": "red", "hazard": "flood", "title": "Nowhere"},
        headers=ADMIN,
    )
    assert untargeted.status_code == 400


# --------------------------------------------------------------------- websocket


def ws_url(lat: float, lon: float, token: str | None = None) -> str:
    url = f"/ws/alerts?lat={lat}&lon={lon}"
    return url if token is None else f"{url}&token={token}"


def test_ws_hello_and_warning_issued_affects_you(client, guest):
    near = client.websocket_connect(ws_url(DELHI[0], DELHI[1], guest["token"]))
    far = client.websocket_connect(ws_url(MUMBAI[0], MUMBAI[1], guest["token"]))
    with near, far:
        hello = near.receive_json()
        assert hello["type"] == "hello"
        assert hello["scenario"] == "live"
        assert hello["server_time"]
        assert far.receive_json()["type"] == "hello"

        assert client.get("/api/v1/admin/state", headers=ADMIN).json()["connected_clients"] == 2

        warning = push(client)

        near_msg = near.receive_json()
        assert near_msg["type"] == "warning_issued"
        assert near_msg["warning"]["id"] == warning["id"]
        assert near_msg["warning"]["source"] == "admin"
        assert near_msg["affects_you"] is True

        far_msg = far.receive_json()
        assert far_msg["type"] == "warning_issued"
        assert far_msg["affects_you"] is False

        client.delete(f"/api/v1/admin/warnings/{warning['id']}", headers=ADMIN)
        cleared = near.receive_json()
        assert cleared == {"type": "warning_cleared", "id": warning["id"]}
        assert far.receive_json()["type"] == "warning_cleared"


def test_ws_scenario_and_now_override_broadcasts(client):
    with client.websocket_connect(ws_url(*DELHI)) as sock:
        assert sock.receive_json()["type"] == "hello"

        client.post("/api/v1/admin/scenario", json={"name": "heatwave"}, headers=ADMIN)
        assert sock.receive_json() == {"type": "scenario_changed", "scenario": "heatwave"}

        client.post("/api/v1/admin/now-override", json={"now": NOW}, headers=ADMIN)
        assert sock.receive_json() == {"type": "now_override", "now": NOW}

        client.post("/api/v1/admin/now-override", json={"now": None}, headers=ADMIN)
        assert sock.receive_json() == {"type": "now_override", "now": None}


def test_ws_location_message_moves_the_client(client):
    with client.websocket_connect(ws_url(*MUMBAI)) as sock:
        assert sock.receive_json()["type"] == "hello"
        sock.send_json({"type": "pong"})
        sock.send_json({"type": "location", "lat": DELHI[0], "lon": DELHI[1]})

        warning = push(client)
        msg = sock.receive_json()
        assert msg["type"] == "warning_issued"
        assert msg["warning"]["id"] == warning["id"]
        assert msg["affects_you"] is True


def test_ws_rejects_a_bad_token(client):
    from starlette.websockets import WebSocketDisconnect

    with pytest.raises(WebSocketDisconnect) as excinfo:
        with client.websocket_connect(ws_url(DELHI[0], DELHI[1], "not-a-jwt")) as sock:
            sock.receive_json()
    assert excinfo.value.code == 1008
    assert client.get("/api/v1/admin/state", headers=ADMIN).json()["connected_clients"] == 0


def test_ws_disconnect_is_dropped_from_the_registry(client):
    with client.websocket_connect(ws_url(*DELHI)) as sock:
        assert sock.receive_json()["type"] == "hello"
        assert client.get("/api/v1/admin/state", headers=ADMIN).json()["connected_clients"] == 1
    assert client.get("/api/v1/admin/state", headers=ADMIN).json()["connected_clients"] == 0


# --------------------------------------------------------------------- lite + perf


def test_lite_trims_hourly_to_12_and_omits_more_cards(client, guest):
    full = home(client, guest, now_override=NOW)
    lite = home(client, guest, now_override=NOW, lite=1)

    assert full["more_cards"], "the full payload has a more_cards tail to trim"
    assert lite["more_cards"] == []

    def hourly_of(payload):
        for card in payload["pinned"] + [payload["hero"]] + payload["cards"] + payload["more_cards"]:
            if card["type"] == "hourly_forecast":
                return card["data"]["hours"]
        raise AssertionError("hourly_forecast card missing")

    # 04: `lite=1` trims hourly arrays to 12. The 24-h strip starts at the demo clock (it used
    # to start at the recorded payload's live `current.time`, which left only 17 rows),
    # so the full card carries 24 rows and the lite one exactly 12.
    assert len(hourly_of(full)) == 24
    assert len(hourly_of(lite)) == 12

    def by_type(payload, wanted):
        pool = payload["pinned"] + [payload["hero"]] + payload["cards"] + payload["more_cards"]
        return next((c for c in pool if c["type"] == wanted), None)

    aqi_full, aqi_lite = by_type(full, "aqi"), by_type(lite, "aqi")
    assert len(aqi_full["data"]["hourly"]) > 12
    assert len(aqi_lite["data"]["hourly"]) == 12

    radar = by_type(lite, "radar")
    if radar is not None:
        assert len(radar["data"]["frames"]) <= 3


def test_home_logs_one_timing_line(client, guest, caplog):
    with caplog.at_level("INFO", logger="mausam.api.home"):
        home(client, guest)
    lines = [r.getMessage() for r in caplog.records if r.name == "mausam.api.home"]
    assert len(lines) == 1, lines
    line = lines[0]
    assert line.startswith("home lat=28.61 lon=77.21 personas=parent")
    assert line.endswith("ms")
