"""S3 — push transport, device registry and the FCM HTTP v1 request shape.

Offline like the rest of the suite: `conftest.py` replays `oauth2.googleapis.com` and
`fcm.googleapis.com` through respx (named routes `google_token` / `fcm_send`) and fails on any
unmocked host, so nothing here touches Google. The service-account key used by the FCM tests is
generated at run time into `tmp_path` — no credential is committed, and the default setup keeps
running with zero keys on the noop transport.
"""

from __future__ import annotations

import json
import logging
from urllib.parse import parse_qs

import httpx
import jwt
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

from app.config import settings
from app.models.device import MAX_DEVICES_PER_USER
from app.services import push

from tests.conftest import DELHI, FAKE_ACCESS_TOKEN, MUMBAI

ADMIN = {"X-Admin-Key": "mausam-admin"}
PROJECT_ID = "mausam-demo"
CLIENT_EMAIL = "push@mausam-demo.iam.gserviceaccount.com"

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


# --------------------------------------------------------------------- helpers


def new_guest(client) -> dict:
    res = client.post("/api/v1/auth/guest")
    assert res.status_code == 200, res.text
    body = res.json()
    return {"token": body["token"], "headers": {"Authorization": f"Bearer {body['token']}"}}


def register(client, guest, token: str = "fcm-token-delhi-0001", **overrides):
    body = {"token": token, "platform": "android", "lat": DELHI[0], "lon": DELHI[1], **overrides}
    res = client.post("/api/v1/me/devices", json=body, headers=guest["headers"])
    assert res.status_code == 200, res.text
    return res.json()


def push_warning(client, **overrides) -> dict:
    res = client.post("/api/v1/admin/warnings", json={**DELHI_WARNING, **overrides}, headers=ADMIN)
    assert res.status_code == 200, res.text
    return res.json()


def admin_devices(client) -> dict:
    res = client.get("/api/v1/admin/devices", headers=ADMIN)
    assert res.status_code == 200, res.text
    return res.json()


class Recorder:
    """A transport that remembers every batch instead of sending it."""

    name = "recorder"

    def __init__(self) -> None:
        self.batches: list[list[push.PushMessage]] = []

    async def send(self, messages):
        self.batches.append(list(messages))
        return push.PushResult(sent=len(messages))

    @property
    def types(self) -> list[str]:
        return [b[0].data["type"] for b in self.batches if b]


@pytest.fixture
def recorder(monkeypatch) -> Recorder:
    rec = Recorder()
    monkeypatch.setattr(push, "_transport", rec)
    return rec


@pytest.fixture(scope="session")
def rsa_key() -> rsa.RSAPrivateKey:
    """One 2048-bit key for the whole session — generating it per test is the slow part."""
    return rsa.generate_private_key(public_exponent=65537, key_size=2048)


@pytest.fixture
def service_account(tmp_path, rsa_key):
    """Write a throwaway service-account JSON and return `(path, public_key_pem)`."""
    private_pem = rsa_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    ).decode()
    public_pem = (
        rsa_key.public_key()
        .public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.SubjectPublicKeyInfo,
        )
        .decode()
    )
    path = tmp_path / "service-account.json"
    path.write_text(
        json.dumps(
            {
                "type": "service_account",
                "project_id": PROJECT_ID,
                "private_key_id": "key-1",
                "private_key": private_pem,
                "client_email": CLIENT_EMAIL,
                "token_uri": push.GOOGLE_TOKEN_URI,
            }
        ),
        encoding="utf-8",
    )
    return path, public_pem


@pytest.fixture
def fcm(monkeypatch, service_account):
    """Activate the FCM transport for one test."""
    path, public_pem = service_account
    monkeypatch.setattr(settings, "fcm_service_account_file", str(path))
    monkeypatch.setattr(settings, "fcm_project_id", PROJECT_ID)
    push.reset_transport()
    return public_pem


# --------------------------------------------------------------- transport selection


def test_the_default_setup_has_no_push_credentials_and_uses_noop():
    assert settings.fcm_service_account_file == ""
    assert settings.fcm_project_id == ""
    assert push.transport().name == "noop"
    assert isinstance(push.transport(), push.NoopTransport)


def test_fcm_is_selected_only_when_both_env_vars_are_set(monkeypatch, service_account):
    path, _ = service_account

    monkeypatch.setattr(settings, "fcm_service_account_file", str(path))
    push.reset_transport()
    assert push.transport().name == "noop", "the file alone must not activate FCM"

    monkeypatch.setattr(settings, "fcm_service_account_file", "")
    monkeypatch.setattr(settings, "fcm_project_id", PROJECT_ID)
    push.reset_transport()
    assert push.transport().name == "noop", "the project id alone must not activate FCM"

    monkeypatch.setattr(settings, "fcm_service_account_file", str(path))
    push.reset_transport()
    active = push.transport()
    assert isinstance(active, push.FcmTransport)
    assert active.name == "fcm"
    assert active.send_url == f"https://fcm.googleapis.com/v1/projects/{PROJECT_ID}/messages:send"


def test_a_missing_key_file_falls_back_to_noop_with_a_warning(monkeypatch, caplog):
    monkeypatch.setattr(settings, "fcm_service_account_file", "/nope/service-account.json")
    monkeypatch.setattr(settings, "fcm_project_id", PROJECT_ID)
    push.reset_transport()
    with caplog.at_level(logging.WARNING, logger="mausam.push"):
        assert push.transport().name == "noop"
    assert "does not exist" in caplog.text


def test_health_reports_the_push_block(client, guest):
    body = client.get("/api/v1/health").json()
    assert body["push"] == {"transport": "noop", "devices": 0}
    register(client, guest)
    assert client.get("/health").json()["push"] == {"transport": "noop", "devices": 1}


# --------------------------------------------------------------- device registry


def test_device_routes_need_a_bearer_token(client):
    assert client.post("/api/v1/me/devices", json={"token": "abcdefgh"}).status_code == 401
    assert client.delete("/api/v1/me/devices/abcdefgh").status_code == 401


def test_register_then_delete_a_device(client, guest):
    body = register(client, guest, lang="hi")
    assert body["token"] == "fcm-token-delhi-0001"
    assert body["platform"] == "android"
    assert body["lang"] == "hi"
    assert body["lat"] == pytest.approx(DELHI[0])

    state = client.get("/api/v1/admin/state", headers=ADMIN).json()
    assert state["devices"] == 1
    assert state["push_transport"] == "noop"

    res = client.delete("/api/v1/me/devices/fcm-token-delhi-0001", headers=guest["headers"])
    assert res.status_code == 200 and res.json() == {"ok": True}
    assert client.get("/api/v1/admin/state", headers=ADMIN).json()["devices"] == 0
    # deleting it twice is a 404, not a silent success
    assert (
        client.delete("/api/v1/me/devices/fcm-token-delhi-0001", headers=guest["headers"])
    ).status_code == 404


def test_re_registering_the_same_token_updates_it_in_place(client, guest):
    register(client, guest)
    register(client, guest, lat=MUMBAI[0], lon=MUMBAI[1], platform="ios")
    devices = admin_devices(client)
    assert devices["count"] == 1
    assert devices["devices"][0]["platform"] == "ios"
    assert devices["devices"][0]["lat"] == pytest.approx(MUMBAI[0])


def test_a_device_can_only_be_deleted_by_its_owner(client, guest):
    register(client, guest)
    other = new_guest(client)
    res = client.delete("/api/v1/me/devices/fcm-token-delhi-0001", headers=other["headers"])
    assert res.status_code == 404
    assert res.json()["error"]["code"] == "not_found"
    assert admin_devices(client)["count"] == 1, "someone else's token must survive"


def test_admin_devices_lists_the_transport_and_redacts_tokens(client, guest):
    register(client, guest, token="fcm-token-abcdef123456")
    body = admin_devices(client)
    assert body["transport"] == "noop"
    assert body["count"] == 1
    row = body["devices"][0]
    assert row["token_suffix"] == "…123456"
    assert "fcm-token" not in json.dumps(body), "a push token is a send-capability; never echo it"
    assert client.get("/api/v1/admin/devices").status_code == 401


def test_the_registry_is_capped_per_user(client, guest):
    for i in range(MAX_DEVICES_PER_USER + 2):
        register(client, guest, token=f"fcm-token-{i:06d}")
    body = admin_devices(client)
    assert body["count"] == MAX_DEVICES_PER_USER
    assert "…000000" not in [d["token_suffix"] for d in body["devices"]]


def test_an_unsupported_language_is_rejected(client, guest):
    res = client.post(
        "/api/v1/me/devices",
        json={"token": "fcm-token-xx", "lang": "xx"},
        headers=guest["headers"],
    )
    assert res.status_code == 400


# --------------------------------------------------------------- broadcast wiring


def test_every_admin_broadcast_also_goes_to_the_push_transport(client, guest, recorder):
    register(client, guest)

    warning = push_warning(client)
    client.post("/api/v1/admin/scenario", json={"name": "heatwave"}, headers=ADMIN)
    client.post("/api/v1/admin/now-override", json={"now": "2026-09-08T07:30"}, headers=ADMIN)
    client.post("/api/v1/admin/now-override", json={"now": None}, headers=ADMIN)
    client.delete(f"/api/v1/admin/warnings/{warning['id']}", headers=ADMIN)

    assert recorder.types == [
        "warning_issued",
        "scenario_changed",
        "now_override",
        "now_override",
        "warning_cleared",
    ]
    issued = recorder.batches[0][0].data
    assert issued["affects_you"] == "true"
    assert json.loads(issued["warning"])["id"] == warning["id"]
    assert issued["severity"] == "orange" and issued["title"] == warning["title"]
    # the data-only messages carry strings only — FCM rejects anything else
    for batch in recorder.batches:
        for message in batch:
            assert all(isinstance(v, str) for v in message.data.values())
    assert recorder.batches[1][0].data == {"type": "scenario_changed", "scenario": "heatwave"}
    assert recorder.batches[3][0].data == {"type": "now_override", "now": ""}, "null → empty string"
    assert recorder.batches[4][0].data == {"type": "warning_cleared", "id": warning["id"]}


def test_affects_you_is_computed_per_device(client, guest, recorder):
    register(client, guest, token="device-delhi", lat=DELHI[0], lon=DELHI[1])
    register(client, guest, token="device-mumbai", lat=MUMBAI[0], lon=MUMBAI[1])
    register(client, guest, token="device-nowhere", lat=None, lon=None)

    push_warning(client)

    by_token = {m.token: m.data["affects_you"] for m in recorder.batches[0]}
    assert by_token == {
        "device-delhi": "true",
        "device-mumbai": "false",
        "device-nowhere": "false",
    }


def test_a_statewide_hazard_reaches_the_whole_state(client, guest, recorder):
    register(client, guest, token="device-nagpur", lat=21.15, lon=79.09)
    register(client, guest, token="device-delhi", lat=DELHI[0], lon=DELHI[1])
    push_warning(
        client,
        hazard="heatwave",
        title="Heatwave — Maharashtra",
        district=None,
        state="Maharashtra",
        lat=None,
        lon=None,
        radius_km=75,
    )
    by_token = {m.token: m.data["affects_you"] for m in recorder.batches[0]}
    assert by_token == {"device-nagpur": "true", "device-delhi": "false"}


def test_no_devices_means_no_transport_call(client, recorder):
    push_warning(client)
    assert recorder.batches == []


def test_a_broken_transport_never_fails_the_admin_call(client, guest, monkeypatch, caplog):
    class Broken:
        name = "broken"

        async def send(self, messages):
            raise RuntimeError("nope")

    register(client, guest)
    monkeypatch.setattr(push, "_transport", Broken())
    with caplog.at_level(logging.WARNING, logger="mausam.push"):
        push_warning(client)
    assert "push transport broken failed" in caplog.text


def test_the_noop_transport_logs_at_info(client, guest, caplog):
    register(client, guest)
    with caplog.at_level(logging.INFO, logger="mausam.push"):
        push_warning(client)
    assert "push (noop): warning_issued → 1 device(s)" in caplog.text
    assert "affects_you=true for 1" in caplog.text


# --------------------------------------------------------------- FCM HTTP v1


def test_fcm_builds_the_http_v1_request(client, guest, mock_upstream, fcm):
    public_pem = fcm
    register(client, guest, token="fcm-token-real-0001")
    warning = push_warning(client)

    # --- the OAuth2 leg: a self-signed RS256 assertion exchanged for an access token
    token_call = mock_upstream["google_token"].calls.last.request
    assert str(token_call.url) == push.GOOGLE_TOKEN_URI
    form = {k: v[0] for k, v in parse_qs(token_call.content.decode()).items()}
    assert form["grant_type"] == "urn:ietf:params:oauth:grant-type:jwt-bearer"
    claims = jwt.decode(
        form["assertion"], public_pem, algorithms=["RS256"], audience=push.GOOGLE_TOKEN_URI
    )
    assert claims["iss"] == CLIENT_EMAIL
    assert claims["scope"] == "https://www.googleapis.com/auth/firebase.messaging"
    assert claims["exp"] - claims["iat"] == push.ASSERTION_TTL_S
    assert jwt.get_unverified_header(form["assertion"])["kid"] == "key-1"

    # --- the send leg
    send_call = mock_upstream["fcm_send"].calls.last.request
    assert str(send_call.url) == (
        f"https://fcm.googleapis.com/v1/projects/{PROJECT_ID}/messages:send"
    )
    assert send_call.headers["authorization"] == f"Bearer {FAKE_ACCESS_TOKEN}"
    assert send_call.headers["content-type"].startswith("application/json")

    message = json.loads(send_call.content)["message"]
    assert message["token"] == "fcm-token-real-0001"
    assert message["android"] == {"priority": "high"}
    assert message["apns"]["headers"]["apns-push-type"] == "background"
    assert message["apns"]["payload"]["aps"]["content-available"] == 1
    assert "notification" not in message, "data-only: the app localises its own tray notification"
    assert message["data"]["type"] == "warning_issued"
    assert message["data"]["affects_you"] == "true"
    assert json.loads(message["data"]["warning"])["id"] == warning["id"]

    assert client.get("/health").json()["push"]["transport"] == "fcm"


def test_fcm_reuses_the_access_token_across_sends(client, guest, mock_upstream, fcm):
    register(client, guest)
    push_warning(client)
    push_warning(client, title="Second warning")
    assert mock_upstream["fcm_send"].call_count == 2
    assert mock_upstream["google_token"].call_count == 1, "the access token is cached until expiry"


def test_fcm_prunes_a_token_the_platform_rejects(client, guest, mock_upstream, fcm):
    register(client, guest, token="fcm-token-dead-0001")
    mock_upstream["fcm_send"].mock(
        return_value=httpx.Response(
            404, json={"error": {"status": "NOT_FOUND", "message": "Requested entity not found"}}
        )
    )
    push_warning(client)
    assert admin_devices(client)["count"] == 0, "an UNREGISTERED token is dropped from the registry"


def test_fcm_keeps_the_token_when_the_failure_is_transient(client, guest, mock_upstream, fcm):
    register(client, guest)
    mock_upstream["fcm_send"].mock(return_value=httpx.Response(503, text="backend unavailable"))
    push_warning(client)
    assert admin_devices(client)["count"] == 1


def test_a_token_endpoint_failure_is_survivable(client, guest, mock_upstream, fcm, caplog):
    register(client, guest)
    mock_upstream["google_token"].mock(return_value=httpx.Response(401, text="invalid_grant"))
    with caplog.at_level(logging.WARNING, logger="mausam.push"):
        push_warning(client)  # the admin call still succeeds
    assert "no access token" in caplog.text
    assert admin_devices(client)["count"] == 1


def test_dead_token_detection():
    assert push.is_dead_token(404, "Requested entity was not found.")
    assert push.is_dead_token(400, "The registration token is not a valid FCM registration token")
    assert not push.is_dead_token(503, "backend unavailable")
    assert not push.is_dead_token(429, "quota exceeded")
