"""Offline test harness: every upstream host is replayed from tests/fixtures/ through respx.

Fixtures were captured once by `scripts/record_fixtures.py` against the real APIs. No test in
this suite touches the network — respx asserts that by raising on any unmocked request.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import httpx
import pytest
import respx

from app.api import ws
from app.config import settings
from app.core import cache, db, geo, i18n
from app.providers import imd, scenarios
from app.services import push
from app.state import demo_state

FIXTURES = Path(__file__).parent / "fixtures"

#: rounded (lat, lon) → fixture slug
SLUGS: dict[tuple[float, float], str] = {
    (28.61, 77.21): "delhi",
    (15.49, 73.83): "panaji",
    (31.10, 77.17): "shimla",
    (19.08, 72.88): "mumbai",
    (51.51, -0.13): "london",
}

#: What the mocked Google token endpoint hands back (tests assert the Bearer header carries it).
FAKE_ACCESS_TOKEN = "ya29.test-access-token"

DELHI = (28.61, 77.21)
PANAJI = (15.49, 73.83)
SHIMLA = (31.10, 77.17)
MUMBAI = (19.08, 72.88)
LONDON = (51.51, -0.13)


def load(name: str) -> dict[str, Any]:
    """Load a recorded envelope `{url, params, status, json}`."""
    with (FIXTURES / f"{name}.json").open("r", encoding="utf-8") as fh:
        return json.load(fh)


def body(name: str) -> Any:
    return load(name)["json"]


def slug_for(request: httpx.Request) -> str:
    params = request.url.params
    lat = round(float(params["latitude"]), 2)
    lon = round(float(params["longitude"]), 2)
    key = (lat, lon)
    if key not in SLUGS:
        raise AssertionError(f"No recorded fixture for ({lat}, {lon}); record it first.")
    return SLUGS[key]


def _reply(env: dict[str, Any]) -> httpx.Response:
    return httpx.Response(env["status"], json=env["json"])


@pytest.fixture(autouse=True)
def reset_state():
    """Caches and provider availability must not leak between tests."""
    cache.clear_all()
    imd.reset_availability()
    scenarios.reload()
    i18n.reload()
    geo.cities.cache_clear()
    geo.coastal_points.cache_clear()
    demo_state.reset()
    ws.manager.reset()
    push.reset_transport()
    yield
    cache.clear_all()
    demo_state.reset()
    ws.manager.reset()
    push.reset_transport()


@pytest.fixture(autouse=True)
def fresh_db():
    """Every test gets an empty in-memory SQLite (never the developer's data/mausam.db)."""
    db.configure("sqlite://")
    db.init_db()
    yield
    db.reset_engine()
    db.configure(None)


@pytest.fixture(autouse=True)
def mock_upstream():
    """Replay every provider host from the recorded fixtures."""
    with respx.mock(assert_all_called=False) as mock:
        mock.get(settings.open_meteo_forecast_url).mock(
            side_effect=lambda req: _reply(load(f"forecast_{slug_for(req)}"))
        )
        mock.get(settings.open_meteo_air_url).mock(
            side_effect=lambda req: _reply(load(f"air_{slug_for(req)}"))
        )
        mock.get(settings.open_meteo_marine_url).mock(
            side_effect=lambda req: _reply(load(f"marine_{slug_for(req)}"))
        )
        mock.get(settings.bigdatacloud_url).mock(
            side_effect=lambda req: _reply(load(f"reverse_{slug_for(req)}"))
        )
        mock.get(settings.open_meteo_geocode_url).mock(side_effect=_geocode)
        mock.get(settings.rainviewer_url).mock(side_effect=lambda req: _reply(load("radar")))
        mock.route(host="mausam.imd.gov.in").mock(side_effect=_imd)
        # S3 push (services/push.py). Named so a test can assert on the captured requests
        # (`mock_upstream["fcm_send"].calls`) or re-`mock()` them to return a failure.
        mock.post(host="oauth2.googleapis.com", name="google_token").mock(
            return_value=httpx.Response(
                200,
                json={
                    "access_token": FAKE_ACCESS_TOKEN,
                    "expires_in": 3600,
                    "token_type": "Bearer",
                },
            )
        )
        mock.post(host="fcm.googleapis.com", name="fcm_send").mock(
            return_value=httpx.Response(200, json={"name": "projects/demo/messages/0:1"})
        )
        yield mock


def _geocode(request: httpx.Request) -> httpx.Response:
    name = (request.url.params.get("name") or "").strip().lower()
    path = FIXTURES / f"geocode_{name}.json"
    if path.exists():
        return _reply(load(f"geocode_{name}"))
    return httpx.Response(200, json={"generationtime_ms": 0.1})


def _imd(request: httpx.Request) -> httpx.Response:
    """IMD answers 401 for non-whitelisted hosts — exactly what we recorded."""
    return httpx.Response(
        401, text="Your IP/Domain needs to be whitelisted", headers={"content-type": "text/plain"}
    )


@pytest.fixture
def client():
    from fastapi.testclient import TestClient

    from app.main import app

    with TestClient(app) as c:
        yield c


@pytest.fixture
def guest(client):
    """A fresh guest token plus its auth header (04 §POST /auth/guest)."""
    res = client.post("/api/v1/auth/guest")
    assert res.status_code == 200, res.text
    body = res.json()
    return {
        "token": body["token"],
        "user": body["user"],
        "headers": {"Authorization": f"Bearer {body['token']}"},
    }
