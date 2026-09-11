"""Write `docs/fixtures/home_*.json` — the contract samples the Flutter app is built against.

Fully offline: it drives the real FastAPI app through `TestClient` while every upstream host is
replayed from `backend/tests/fixtures/*.json` by the same respx harness the test-suite uses, so
the payloads are byte-for-byte what a running backend returns for the same request.

    backend/.venv/Scripts/python scripts/gen_fixtures.py

Every file is one `HomeResponse` exactly per docs/04. `NOW` is fixed so re-running the script
produces the same JSON (apart from the `usr_`/`plc_` ids, which are random per run).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

BACKEND = Path(__file__).resolve().parent.parent
REPO = BACKEND.parent
OUT = REPO / "docs" / "fixtures"
sys.path.insert(0, str(BACKEND))

import httpx  # noqa: E402
import respx  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.config import settings  # noqa: E402
from app.core import db  # noqa: E402
from tests.conftest import _reply, load, slug_for  # noqa: E402

API = "/api/v1"
#: A Tuesday morning in IST — fixed so the fixtures are deterministic.
NOW = "2026-09-08T07:30:00+05:30"
DELHI = (28.61, 77.21)
PANAJI = (15.49, 73.83)

PERSONAS = (
    "health",
    "fitness",
    "beach",
    "traveler",
    "parent",
    "agriculture",
    "commuter",
    "event_planner",
)

#: persona → (coords, extra saved places). `beach` gets a coastal location, `traveler` a place
#: to watch, because both persona's cards are gated on exactly that (02).
PERSONA_SETUP: dict[str, tuple[tuple[float, float], list[dict[str, Any]]]] = {
    "beach": (PANAJI, []),
    "traveler": (
        DELHI,
        [
            {"name": "Panaji", "lat": PANAJI[0], "lon": PANAJI[1], "kind": "travel"},
            {"name": "Mumbai", "lat": 19.08, "lon": 72.88, "kind": "travel"},
        ],
    ),
}


def mock_upstream() -> respx.MockRouter:
    """The same replay harness as `tests/conftest.py`, so no request leaves the machine."""
    mock = respx.mock(assert_all_called=False)
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
    mock.get(settings.open_meteo_geocode_url).mock(
        return_value=httpx.Response(200, json={"generationtime_ms": 0.1})
    )
    mock.get(settings.rainviewer_url).mock(side_effect=lambda req: _reply(load("radar")))
    mock.route(host="mausam.imd.gov.in").mock(
        return_value=httpx.Response(401, text="Your IP/Domain needs to be whitelisted")
    )
    return mock


def new_guest(client: TestClient) -> dict[str, str]:
    res = client.post(API + "/auth/guest")
    res.raise_for_status()
    return {"Authorization": f"Bearer {res.json()['token']}"}


def fetch_home(client: TestClient, headers: dict[str, str], **params: Any) -> dict[str, Any]:
    res = client.get(
        API + "/home", params={"now_override": NOW, **params}, headers=headers
    )
    if res.status_code != 200:
        raise SystemExit(f"/home failed ({res.status_code}): {res.text[:500]}")
    return res.json()


def write(name: str, payload: dict[str, Any]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}.json"
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=False) + "\n",
        encoding="utf-8",
    )
    cards = 1 + len(payload["pinned"]) + len(payload["cards"]) + len(payload["more_cards"])
    print(f"{path.relative_to(REPO)}: {cards} cards, {path.stat().st_size // 1024} KB")


def generate() -> None:
    from app.main import app

    with mock_upstream(), TestClient(app) as client:
        for persona in PERSONAS:
            coords, places = PERSONA_SETUP.get(persona, (DELHI, []))
            headers = new_guest(client)
            client.put(
                API + "/me/profile",
                json={"personas": [{"id": persona, "weight": 1.0}]},
                headers=headers,
            )
            for place in places:
                client.post(API + "/me/places", json=place, headers=headers)
            write(
                f"home_{persona}",
                fetch_home(
                    client,
                    headers,
                    lat=coords[0],
                    lon=coords[1],
                    personas=persona,
                    scenario="clear_pleasant",
                ),
            )

        # A severe payload: a parent in Delhi during the thunderstorm scenario (pinned warning
        # + banner), and a coastal one: the beach persona in Panaji.
        headers = new_guest(client)
        write(
            "home_severe",
            fetch_home(
                client,
                headers,
                lat=DELHI[0],
                lon=DELHI[1],
                personas="parent",
                scenario="thunderstorm",
            ),
        )

        headers = new_guest(client)
        write(
            "home_coastal",
            fetch_home(
                client,
                headers,
                lat=PANAJI[0],
                lon=PANAJI[1],
                personas="beach",
                scenario="clear_pleasant",
            ),
        )


def main() -> None:
    # Never touch the developer's data/mausam.db.
    db.configure("sqlite://")
    db.init_db()
    try:
        generate()
    finally:
        db.reset_engine()
        db.configure(None)
    print(f"\nwrote {len(list(OUT.glob('home_*.json')))} fixtures to {OUT}")


if __name__ == "__main__":
    main()
