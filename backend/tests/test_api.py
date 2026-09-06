"""Router contract tests for /health, /locations/*, /weather/* (04)."""

from __future__ import annotations

import json

from app.config import settings
from app.core import geo, i18n

BASE = "/api/v1"


def test_health(client):
    r = client.get(f"{BASE}/health")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ok"
    assert set(body["providers"]) == {"imd", "open_meteo", "marine", "air"}
    assert body["scenario"] == "live"
    assert body["now_override"] is None
    assert body["time"].endswith("+00:00")


def test_health_is_also_served_without_the_api_prefix(client):
    assert client.get("/health").status_code == 200


def test_locations_popular_covers_coastal_and_hill(client):
    r = client.get(f"{BASE}/locations/popular")
    assert r.status_code == 200
    rows = r.json()
    assert len(rows) >= 40
    names = {row["name"] for row in rows}
    assert {"Panaji", "Puri", "Kovalam", "Shimla", "Leh", "Port Blair"} <= names
    assert any(row["is_coastal"] for row in rows)
    assert any((row["elevation_m"] or 0) > 1500 for row in rows)
    assert all(row["timezone"] == "Asia/Kolkata" for row in rows)


def test_locations_search_hits_the_curated_list_first(client):
    r = client.get(f"{BASE}/locations/search", params={"q": "panaj", "limit": 5})
    assert r.status_code == 200
    rows = r.json()
    assert rows[0]["name"] == "Panaji"
    assert rows[0]["id"] == "city:panaji"
    assert rows[0]["is_coastal"] is True

    # prefix hits are ordered by population, so "pan" gives Panipat before Panaji
    names = [c["name"] for c in client.get(
        f"{BASE}/locations/search", params={"q": "pan", "limit": 8}).json()]
    assert names[:2] == ["Panipat", "Panaji"]


def test_locations_reverse(client):
    r = client.get(f"{BASE}/locations/reverse", params={"lat": 28.61, "lon": 77.21})
    assert r.status_code == 200
    body = r.json()
    assert body["id"] == "city:delhi"
    assert body["admin1"] == "Delhi"
    assert body["is_coastal"] is False


def test_locations_reverse_rejects_bad_coordinates(client):
    r = client.get(f"{BASE}/locations/reverse", params={"lat": 999, "lon": 0})
    assert r.status_code == 400
    assert r.json()["error"]["code"] == "validation_error"


def test_snapshot_coastal_has_marine_and_tides(client):
    r = client.get(f"{BASE}/weather/snapshot", params={"lat": 15.49, "lon": 73.83})
    assert r.status_code == 200
    body = r.json()
    assert body["location"]["name"] == "Panaji"
    assert body["marine"] is not None
    assert body["tides"]["source"] == "estimated"
    assert body["derived"]["sea"]["sea_state"]


def test_snapshot_inland_has_null_marine(client):
    r = client.get(f"{BASE}/weather/snapshot", params={"lat": 28.61, "lon": 77.21})
    assert r.status_code == 200
    body = r.json()
    assert body["marine"] is None
    assert body["tides"] is None
    assert body["sources"]["marine"] is None


def test_snapshot_scenario_dense_fog(client):
    r = client.get(
        f"{BASE}/weather/snapshot",
        params={"lat": 28.61, "lon": 77.21, "scenario": "dense_fog"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["current"]["visibility_km"] == 0.2
    assert body["derived"]["visibility"]["visibility_km"] == 0.2
    assert body["warnings"][0]["hazard"] == "fog"


def test_snapshot_rejects_an_unknown_scenario(client):
    r = client.get(
        f"{BASE}/weather/snapshot",
        params={"lat": 28.61, "lon": 77.21, "scenario": "nope"},
    )
    assert r.status_code == 400
    assert r.json()["error"]["code"] == "unknown_scenario"


def test_snapshot_accepts_a_demo_clock(client):
    r = client.get(
        f"{BASE}/weather/snapshot",
        params={
            "lat": 28.61, "lon": 77.21,
            "now_override": "2026-09-07T07:30:00+05:30",
        },
    )
    assert r.status_code == 200
    windows = r.json()["derived"]["school_commute"]["windows"]
    # 07:30 is inside the 07:00–09:00 drop window, so "next occurrence" is today
    assert windows[0]["start"] == "2026-09-07T07:00:00+05:30"
    assert windows[1]["start"] == "2026-09-07T13:00:00+05:30"


def test_radar(client):
    r = client.get(f"{BASE}/weather/radar")
    assert r.status_code == 200
    body = r.json()
    assert body["past"]
    assert body["tile_template"].endswith("/256/{z}/{x}/{y}/2/1_1.png")


def test_scenario_listing(client):
    r = client.get(f"{BASE}/weather/scenarios")
    assert r.status_code == 200
    names = {s["name"] for s in r.json()["scenarios"]}
    assert {"live", "dense_fog", "cyclone", "heatwave", "monsoon_flood"} <= names


# ------------------------------------------------------------------ data files


def test_cities_dataset_meets_the_spec():
    rows = geo.cities()
    assert len(rows) >= 150
    ids = [c["id"] for c in rows]
    assert len(ids) == len(set(ids))
    for c in rows:
        assert set(c) >= {
            "id", "name", "admin1", "admin2", "lat", "lon", "tz",
            "is_coastal", "elevation_m", "population",
        }
        assert 6.0 <= c["lat"] <= 37.6 and 68.0 <= c["lon"] <= 97.5
    names = {c["name"] for c in rows}
    # state capitals, coastal towns and hill stations named in 07 §A1
    assert {"New Delhi", "Mumbai", "Chennai", "Kolkata", "Bengaluru", "Hyderabad",
            "Panaji", "Puri", "Kovalam", "Gokarna", "Diu", "Digha", "Port Blair",
            "Shimla", "Manali", "Ooty", "Darjeeling", "Leh"} <= names
    assert sum(1 for c in rows if c["is_coastal"]) >= 30


def test_coastal_points_cover_the_islands():
    pts = geo.coastal_points()
    assert len(pts) >= 80
    states = {p["state"] for p in pts}
    assert "Andaman and Nicobar Islands" in states
    assert "Lakshadweep" in states
    assert {"Gujarat", "Maharashtra", "Goa", "Karnataka", "Kerala", "Tamil Nadu",
            "Andhra Pradesh", "Odisha", "West Bengal"} <= states


def test_coastal_detection():
    assert geo.is_coastal(15.49, 73.83) is True   # Panaji
    assert geo.is_coastal(19.08, 72.88) is True   # Mumbai
    assert geo.is_coastal(11.62, 92.73) is True   # Port Blair
    assert geo.is_coastal(28.61, 77.21) is False  # Delhi
    assert geo.is_coastal(31.10, 77.17) is False  # Shimla


def test_planting_calendar_has_seven_zones_and_two_to_four_crops():
    cal = geo.planting_calendar()
    assert set(cal) == {"north", "south", "east", "west", "central", "northeast", "hills"}
    for zone, months in cal.items():
        assert set(months) == {str(m) for m in range(1, 13)}
        for month, crops in months.items():
            assert 2 <= len(crops) <= 4, (zone, month)
            for crop in crops:
                assert set(crop) == {"name", "stage", "action"}
                assert crop["stage"] in ("sow", "grow", "irrigate", "harvest", "protect")


def test_imd_ids_are_valid_city_references():
    table = geo.imd_ids()
    known = {c["id"] for c in geo.cities()}
    for key in table:
        if key.startswith("_"):
            continue
        assert key in known, key
        assert table[key]["station_id"]


def test_i18n_seed_has_every_card_title_and_the_estimate_labels():
    en = i18n.catalog("en")
    assert i18n.t("en", "estimated") == "Estimated"
    assert "harmonic model" in i18n.t("en", "tides.disclaimer")
    for card_type in ("current_conditions", "aqi", "tides", "school_commute",
                      "planting_guidance", "comfort_index"):
        assert f"card.{card_type}.title" in en
    for code in (0, 45, 65, 95):
        assert f"condition.{code}" in en
    assert i18n.t("en", "missing.key") == "missing.key"
    assert i18n.normalize_lang("hi-IN") == "hi"
    assert i18n.normalize_lang("de") == "en"


def test_env_example_documents_every_setting():
    text = (settings.data_dir.parent.parent / ".env.example").read_text(encoding="utf-8")
    for key in ("DEMO_MODE", "ADMIN_KEY", "JWT_SECRET", "DATABASE_URL", "REDIS_URL",
                "DATA_GOV_IN_KEY", "TOMTOM_KEY", "IMD_BASE_URL", "IMD_ENABLED",
                "DEFAULT_SCENARIO", "CORS_ORIGINS", "HTTP_TIMEOUT_S", "LOG_LEVEL"):
        assert key in text, key


def test_recorded_fixtures_are_committed():
    fixtures = settings.data_dir.parent.parent / "tests" / "fixtures"
    for slug in ("delhi", "panaji", "shimla", "mumbai", "london"):
        for kind in ("forecast", "air", "marine", "reverse"):
            path = fixtures / f"{kind}_{slug}.json"
            assert path.exists(), path
            env = json.loads(path.read_text(encoding="utf-8"))
            assert {"url", "params", "status", "json"} <= set(env)
