"""Snapshot assembly for an inland and a coastal city, plus the scenario overlay (05 §Snapshot)."""

from __future__ import annotations

import pytest

from app.services import snapshot as snapshot_svc
from tests.conftest import DELHI, MUMBAI, PANAJI, SHIMLA

REQUIRED_DERIVED = {
    "comfort", "heat", "workout", "school_commute", "commute",
    "frost", "visibility", "flight_risk", "packing", "planting",
}


async def test_delhi_is_inland_no_marine_no_tides():
    snap = await snapshot_svc.build_snapshot(*DELHI)
    assert snap.location.name
    assert snap.location.admin1 == "Delhi"
    assert snap.location.is_coastal is False
    assert snap.marine is None
    assert snap.tides is None
    assert snap.sources["marine"] is None
    assert snap.sources["weather"] == "open-meteo"


async def test_panaji_is_coastal_with_marine_and_estimated_tides():
    snap = await snapshot_svc.build_snapshot(*PANAJI)
    assert snap.location.is_coastal is True
    assert snap.marine is not None
    assert snap.marine.wave_height_m is not None
    assert snap.marine.sea_state in (
        "Calm", "Smooth", "Slight", "Moderate", "Rough", "Very Rough", "High"
    )
    assert snap.tides is not None
    assert snap.tides.source == "estimated"
    assert snap.tides.events
    assert snap.derived["sea"]["surf_rating"] in range(0, 6)
    assert snap.sources["tides"] == "estimated"


async def test_snapshot_shape_matches_the_contract():
    snap = await snapshot_svc.build_snapshot(*DELHI)
    assert len(snap.hourly) == 48
    assert len(snap.daily) == 16
    assert REQUIRED_DERIVED <= set(snap.derived)
    # times carry the location's offset (04)
    assert snap.current.time.endswith("+05:30")
    assert snap.hourly[0].time.endswith("+05:30")
    assert snap.daily[0].sunrise.endswith("+05:30")
    # current uv/visibility come from the matching hourly row, in km
    assert snap.current.visibility_km is not None
    assert snap.current.visibility_km < 100
    assert snap.current.uv_index is not None
    assert snap.current.condition_text


async def test_air_quality_uses_the_cpcb_scale_and_mg_co():
    snap = await snapshot_svc.build_snapshot(*DELHI)
    aq = snap.air_quality
    assert aq is not None and aq.aqi is not None
    assert aq.category in ("Good", "Satisfactory", "Moderate", "Poor", "Very Poor", "Severe")
    assert aq.dominant_pollutant
    assert aq.co is not None and aq.co < 50  # mg/m³, not µg/m³
    assert aq.hourly and len(aq.hourly) <= 24


async def test_pollen_is_estimated_for_indian_locations():
    snap = await snapshot_svc.build_snapshot(*DELHI)
    assert snap.pollen.source == "estimated"
    assert 0 <= snap.pollen.index <= 4
    assert set(snap.pollen.by_type) == {"tree", "grass", "weed"}


async def test_modelled_values_declare_themselves_estimated():
    snap = await snapshot_svc.build_snapshot(*PANAJI)
    assert snap.tides.source == "estimated"
    assert snap.pollen.source == "estimated"
    assert snap.traffic.source == "estimated"


async def test_shimla_is_a_hill_station_not_coastal():
    snap = await snapshot_svc.build_snapshot(*SHIMLA)
    assert snap.location.is_coastal is False
    assert snap.location.elevation_m and snap.location.elevation_m > 1000
    assert snap.derived["planting"]["zone"] == "hills"


async def test_mumbai_is_coastal():
    snap = await snapshot_svc.build_snapshot(*MUMBAI)
    assert snap.location.is_coastal is True
    assert snap.marine is not None
    assert snap.tides is not None


# ------------------------------------------------------------------ scenarios


async def test_dense_fog_scenario_overrides_visibility_and_adds_a_warning():
    snap = await snapshot_svc.build_snapshot(*DELHI, scenario="dense_fog")
    assert snap.current.visibility_km == 0.2
    assert snap.hourly[0].visibility_km == 0.3
    assert snap.derived["visibility"]["category"] == "Dense fog"
    assert snap.derived["visibility"]["urgency"] == 0.8
    assert [w.hazard for w in snap.warnings] == ["fog"]
    assert snap.warnings[0].severity == "orange"
    assert snap.warnings[0].source == "scenario"
    assert snap.warnings[0].color_hex == "#F28C28"
    assert snap.warnings[0].district == snap.location.admin2
    assert snap.nowcast.source == "scenario"
    assert snap.scenario == "dense_fog"


async def test_severe_aqi_scenario_recomputes_the_index():
    snap = await snapshot_svc.build_snapshot(*DELHI, scenario="severe_aqi")
    assert snap.air_quality.pm2_5 == 320.0
    assert snap.air_quality.pm10 == 480.0
    assert snap.air_quality.category == "Severe"
    assert snap.air_quality.dominant_pollutant == "PM10"
    assert snap.sources["air"] == "scenario"


async def test_cyclone_scenario_overrides_marine_and_blocks_swimming():
    snap = await snapshot_svc.build_snapshot(*PANAJI, scenario="cyclone")
    assert snap.marine.wave_height_m == 4.5
    assert snap.marine.sea_state == "Very Rough"
    assert snap.derived["sea"]["safe_for_swimming"] is False
    assert snap.derived["sea"]["urgency"] == 1.0
    assert any(w.hazard == "cyclone" and w.severity == "red" for w in snap.warnings)


async def test_cyclone_scenario_leaves_an_inland_city_without_marine():
    snap = await snapshot_svc.build_snapshot(*DELHI, scenario="cyclone")
    assert snap.marine is None
    assert snap.tides is None
    assert "sea" not in snap.derived


async def test_heatwave_scenario_drives_the_heat_block():
    snap = await snapshot_svc.build_snapshot(*DELHI, scenario="heatwave")
    heat = snap.derived["heat"]
    assert heat["level"] in ("danger", "extreme_danger")
    assert heat["urgency"] == 1.0  # red heatwave warning
    assert heat["advice"]


async def test_frost_scenario_raises_frost_risk():
    snap = await snapshot_svc.build_snapshot(*SHIMLA, scenario="frost")
    assert snap.derived["frost"]["risk"] == "high"
    assert snap.derived["frost"]["tmin_c"] == -1.0


async def test_monsoon_flood_scenario_drives_rain_and_soil():
    snap = await snapshot_svc.build_snapshot(*MUMBAI, scenario="monsoon_flood")
    assert snap.derived["rain"]["intensity"] == "very_heavy"
    assert snap.derived["rainfall_outlook"]["next_24h_mm"] > 100
    assert snap.derived["soil"]["status"] == "saturated"
    assert any(w.hazard == "very_heavy_rain" for w in snap.warnings)


async def test_clear_pleasant_scenario_is_calm():
    snap = await snapshot_svc.build_snapshot(*DELHI, scenario="clear_pleasant")
    assert snap.current.temp_c == 26.0
    assert snap.warnings == []
    assert snap.nowcast.severity == "none"
    assert snap.derived["comfort"]["category"] in ("Comfortable", "Ideal")


async def test_unknown_scenario_is_a_no_op_overlay():
    snap = await snapshot_svc.build_snapshot(*DELHI, scenario="does_not_exist")
    assert snap.warnings == []
    assert snap.sources["weather"] == "open-meteo"


@pytest.mark.parametrize("place", [DELHI, PANAJI])
async def test_snapshot_cache_returns_the_same_object(place):
    a = await snapshot_svc.get_snapshot(*place)
    b = await snapshot_svc.get_snapshot(*place)
    assert a is b
