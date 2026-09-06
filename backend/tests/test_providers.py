"""Providers parse the recorded upstream payloads correctly (05 §Providers)."""

from __future__ import annotations

import pytest

from app.core import cache
from app.providers import bigdatacloud, imd, open_meteo, rainviewer, scenarios
from tests.conftest import DELHI, LONDON, PANAJI, SHIMLA, body


async def test_forecast_has_the_requested_blocks():
    res = await open_meteo.fetch_forecast(*DELHI)
    assert res.ok and res.source == "open-meteo"
    data = res.data
    assert data["timezone"] == "Asia/Kolkata"
    assert data["utc_offset_seconds"] == 19800
    for field in ("temperature_2m", "relative_humidity_2m", "weather_code", "wind_gusts_10m"):
        assert field in data["current"]
    for field in ("visibility", "uv_index", "soil_moisture_0_to_1cm", "dew_point_2m"):
        assert field in data["hourly"]
    for field in ("sunrise", "sunset", "daylight_duration", "uv_index_max"):
        assert field in data["daily"]
    assert len(data["daily"]["time"]) == 16
    assert len(data["hourly"]["time"]) == 16 * 24


async def test_forecast_params_match_the_spec():
    p = open_meteo.forecast_params(28.61, 77.21)
    assert p["timezone"] == "auto" and p["forecast_days"] == 16
    assert "apparent_temperature" in p["current"]
    assert "soil_moisture_9_to_27cm" in p["hourly"]
    assert "precipitation_probability_max" in p["daily"]


async def test_air_quality_reports_null_pollen_for_india():
    """Verified against the recorded fixture: CAMS pollen is Europe-only (05 §Pollen)."""
    res = await open_meteo.fetch_air(*DELHI)
    current = res.data["current"]
    assert current["pm2_5"] is not None
    assert all(current[f] is None for f in current if f.endswith("_pollen"))

    london = body("air_london")["current"]
    assert any(london[f] is not None for f in london if f.endswith("_pollen"))


async def test_marine_is_none_inland_and_present_on_the_coast():
    inland = await open_meteo.fetch_marine(*DELHI)
    assert inland.ok and inland.data is None and inland.error == "not_marine"

    cache.clear_all()
    coastal = await open_meteo.fetch_marine(*PANAJI)
    assert coastal.ok and coastal.data["current"]["wave_height"] is not None


async def test_geocode_ranks_india_first():
    res = await open_meteo.geocode("london")
    ranked = open_meteo.rank_geocode_results(res.data)
    assert ranked
    codes = [r.get("country_code") for r in ranked]
    if "IN" in codes:
        assert codes.index("IN") < codes.index("GB")


async def test_reverse_geocode_parses_city_state_district():
    res = await bigdatacloud.reverse(*DELHI)
    parsed = bigdatacloud.parse(res.data)
    assert parsed["country_code"] == "IN"
    assert parsed["admin1"]
    assert parsed["name"]


async def test_radar_frames_and_tile_template():
    res = await rainviewer.fetch_maps()
    parsed = rainviewer.parse(res.data)
    assert parsed["past"], "expected past radar frames"
    assert parsed["tile_template"].endswith("/256/{z}/{x}/{y}/2/1_1.png")
    assert parsed["tile_template"].startswith(parsed["host"])
    assert parsed["past"][0]["time"].endswith("+00:00")


async def test_imd_401_marks_the_provider_unavailable_and_returns_none():
    imd.reset_availability()
    assert imd.is_available()
    out = await imd._call("current_wx_api.php", "42182")
    assert out is None
    assert not imd.is_available()
    assert imd.status() == "unavailable"


async def test_imd_ids_are_known_for_curated_cities_only():
    ids = imd.ids_for(*DELHI)
    assert ids.get("station_id") == "42182"
    assert imd.ids_for(*LONDON) == {}


def test_scenario_loader_and_deep_merge():
    assert scenarios.load("live") is None
    assert scenarios.exists("live")
    fog = scenarios.load("dense_fog")
    assert fog["overrides"]["current"]["visibility_km"] == 0.2
    assert fog["overrides"]["hourly_all"]["visibility_km"] == 0.3
    assert {"clear_pleasant", "cyclone", "dense_fog", "frost", "heatwave", "heavy_rain",
            "live", "monsoon_flood", "severe_aqi", "thunderstorm"} == set(scenarios.available())

    merged = scenarios.deep_merge({"a": {"x": 1, "y": 2}, "b": 3}, {"a": {"y": 9}, "c": 4})
    assert merged == {"a": {"x": 1, "y": 9}, "b": 3, "c": 4}


def test_scenario_overrides_broadcast_to_every_hour():
    payload = {
        "current": {"visibility_km": 12.0},
        "hourly": [{"visibility_km": 12.0}, {"visibility_km": 11.0}],
        "daily": [{"tmin_c": 20}],
        "air_quality": {"pm2_5": 10},
        "marine": None,
    }
    out = scenarios.apply_overrides(payload, scenarios.load("dense_fog"))
    assert out["current"]["visibility_km"] == 0.2
    assert [h["visibility_km"] for h in out["hourly"]] == [0.3, 0.3]
    assert out["daily"][0]["tmin_c"] == 7.0
    assert out["air_quality"]["pm2_5"] == 180.0
    assert out["marine"] is None


@pytest.mark.parametrize("place", [DELHI, PANAJI, SHIMLA])
async def test_provider_results_are_cached(place):
    first = await open_meteo.fetch_forecast(*place)
    second = await open_meteo.fetch_forecast(*place)
    assert first is second
