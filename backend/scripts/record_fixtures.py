"""Record real upstream responses into backend/tests/fixtures/ (run manually, commit the JSON).

    backend/.venv/Scripts/python scripts/record_fixtures.py

Tests never touch the network: `tests/conftest.py` replays these files through respx. Re-run this
script when an upstream response shape changes, then re-run the suite.

Each fixture is an envelope so the mock can reproduce the status code as well as the body:

    {"url": ..., "params": {...}, "status": 200, "recorded_at": "...", "json": {...}}
"""

from __future__ import annotations

import asyncio
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

BACKEND = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND))

import httpx  # noqa: E402

from app.config import settings  # noqa: E402
from app.providers import open_meteo  # noqa: E402

OUT = BACKEND / "tests" / "fixtures"

PLACES: list[tuple[str, float, float]] = [
    ("delhi", 28.61, 77.21),
    ("panaji", 15.49, 73.83),
    ("shimla", 31.10, 77.17),
    ("mumbai", 19.08, 72.88),
    ("london", 51.51, -0.13),
]

GEOCODE_QUERIES = ["goa", "delhi", "london"]


async def grab(
    client: httpx.AsyncClient, name: str, url: str, params: dict | None
) -> dict:
    resp = await client.get(url, params=params)
    try:
        body = resp.json()
    except ValueError:
        body = {"_raw": resp.text[:2000]}
    env = {
        "url": url,
        "params": params or {},
        "status": resp.status_code,
        "recorded_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "json": body,
    }
    path = OUT / f"{name}.json"
    path.write_text(json.dumps(env, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"  {name:28s} HTTP {resp.status_code}  {path.stat().st_size / 1024:.0f} KB")
    return env


async def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    async with httpx.AsyncClient(timeout=30.0, follow_redirects=True) as client:
        for slug, lat, lon in PLACES:
            print(f"{slug} ({lat}, {lon})")
            await grab(
                client,
                f"forecast_{slug}",
                settings.open_meteo_forecast_url,
                open_meteo.forecast_params(lat, lon),
            )
            air = await grab(
                client,
                f"air_{slug}",
                settings.open_meteo_air_url,
                open_meteo.air_params(lat, lon),
            )
            pollen_fields = {
                k: v
                for k, v in ((air.get("json") or {}).get("current") or {}).items()
                if "pollen" in k
            }
            print(f"    pollen fields: {pollen_fields or 'none reported'}")
            await grab(
                client,
                f"marine_{slug}",
                settings.open_meteo_marine_url,
                open_meteo.marine_params(lat, lon),
            )
            await grab(
                client,
                f"reverse_{slug}",
                settings.bigdatacloud_url,
                {"latitude": lat, "longitude": lon, "localityLanguage": "en"},
            )

        print("geocoding")
        for q in GEOCODE_QUERIES:
            await grab(
                client,
                f"geocode_{q}",
                settings.open_meteo_geocode_url,
                open_meteo.geocode_params(q, 10),
            )

        print("radar")
        await grab(client, "radar", settings.rainviewer_url, None)

        print("imd (expected 401 until the host IP is whitelisted)")
        await grab(
            client,
            "imd_current_delhi",
            f"{settings.imd_base_url.rstrip('/')}/current_wx_api.php",
            {"id": "42182"},
        )

    print(f"\nWrote fixtures to {OUT}")


if __name__ == "__main__":
    asyncio.run(main())
