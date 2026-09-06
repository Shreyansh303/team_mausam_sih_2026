"""CPCB AQI table, band edges and the CO unit conversion (05 §Formulas)."""

from __future__ import annotations

import pytest

from app.services import aqi_cpcb as aqi


@pytest.mark.parametrize(
    "pollutant,value,expected",
    [
        ("pm2_5", 0, 0),
        ("pm2_5", 30, 50),  # top of Good
        ("pm2_5", 31, 51),  # bottom of Satisfactory
        ("pm2_5", 60, 100),
        ("pm2_5", 61, 101),
        ("pm2_5", 90, 200),
        ("pm2_5", 120, 300),
        ("pm2_5", 250, 400),
        ("pm10", 50, 50),
        ("pm10", 51, 51),
        ("pm10", 100, 100),
        ("pm10", 250, 200),
        ("pm10", 430, 400),
        ("no2", 40, 50),
        ("no2", 400, 400),
        ("o3", 50, 50),
        ("so2", 40, 50),
        ("co", 1.0, 50),
        ("co", 2.0, 100),
        ("co", 10, 200),
    ],
)
def test_sub_index_band_edges(pollutant, value, expected):
    assert aqi.sub_index(pollutant, value) == pytest.approx(expected, abs=0.51)


def test_sub_index_interpolates_inside_a_band():
    # PM2.5 45.5 sits halfway through 31–60 → halfway through 51–100
    assert aqi.sub_index("pm2_5", 45.5) == pytest.approx(75.5, abs=0.6)


def test_above_the_severe_band_is_clamped_at_500():
    assert aqi.sub_index("pm2_5", 251) > 400
    assert aqi.sub_index("pm2_5", 5000) == 500
    assert aqi.compute(pm2_5=5000)["aqi"] == 500


def test_missing_pollutants_are_ignored():
    assert aqi.sub_index("pm2_5", None) is None
    out = aqi.compute(pm2_5=None, pm10=None)
    assert out["aqi"] is None and out["category"] is None


@pytest.mark.parametrize(
    "value,category",
    [
        (0, "Good"), (50, "Good"), (51, "Satisfactory"), (100, "Satisfactory"),
        (101, "Moderate"), (200, "Moderate"), (201, "Poor"), (300, "Poor"),
        (301, "Very Poor"), (400, "Very Poor"), (401, "Severe"), (500, "Severe"),
    ],
)
def test_category_bands(value, category):
    assert aqi.category_for(value) == category


def test_aqi_is_the_max_sub_index_and_names_the_dominant_pollutant():
    out = aqi.compute(pm2_5=45.5, pm10=260, no2=20, o3=40, so2=10, co_mg=0.5)
    assert out["dominant_pollutant"] == "PM10"
    assert out["aqi"] == pytest.approx(aqi.sub_index("pm10", 260), abs=1)
    assert out["category"] == "Poor"


def test_co_is_converted_from_micrograms_to_milligrams():
    assert aqi.co_ugm3_to_mgm3(1542.0) == 1.542
    assert aqi.co_ugm3_to_mgm3(None) is None
    # 1542 µg/m³ is 1.54 mg/m³ → Satisfactory, not off-scale.
    assert aqi.category_for(aqi.sub_index("co", 1.542)) == "Satisfactory"


def test_severe_aqi_scenario_values():
    """The severe_aqi scenario (pm2_5 320, pm10 480) must land in the Severe band."""
    out = aqi.compute(pm2_5=320, pm10=480, no2=145, so2=48, o3=40, co_mg=3.2)
    assert out["category"] == "Severe"
    assert out["dominant_pollutant"] == "PM10"
    assert 400 < out["aqi"] <= 500
