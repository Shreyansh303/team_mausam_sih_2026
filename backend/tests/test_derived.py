"""Derived metric formulas from docs/02 and docs/05."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest

from app.core.timeutil import daypart, iso, season
from app.services import (
    comfort,
    commute,
    flight_risk,
    frost,
    marine,
    nowcast,
    packing,
    planting,
    pollen,
    school_commute,
    tides,
    visibility,
    workout,
)

IST = timezone(timedelta(hours=5, minutes=30))


def synthetic_day(
    start: datetime,
    hours: int = 30,
    **overrides,
) -> list[dict]:
    """A flat 30-hour hourly series; pass callables or constants to shape a field."""
    rows = []
    for i in range(hours):
        t = start + timedelta(hours=i)
        row = {
            "time": iso(t),
            "temp_c": 24.0,
            "feels_like_c": 24.0,
            "humidity_pct": 50.0,
            "dew_point_c": 13.0,
            "precip_prob_pct": 0.0,
            "precip_mm": 0.0,
            "wind_kph": 8.0,
            "wind_dir_deg": 270.0,
            "gust_kph": 14.0,
            "uv_index": 3.0 if 7 <= t.hour <= 17 else 0.0,
            "visibility_km": 15.0,
            "cloud_pct": 20.0,
            "condition_code": 0,
            "is_day": 6 <= t.hour <= 18,
            "soil_moisture_surface": 0.22,
            "soil_moisture_root": 0.25,
            "soil_temp_c": 25.0,
        }
        for key, value in overrides.items():
            row[key] = value(t) if callable(value) else value
        rows.append(row)
    return rows


# ------------------------------------------------------------------ comfort


def test_dew_point_magnus_known_value():
    assert comfort.dew_point_c(25.0, 60.0) == pytest.approx(16.7, abs=0.1)
    assert comfort.dew_point_c(30.0, 80.0) == pytest.approx(26.2, abs=0.2)
    assert comfort.dew_point_c(None, 60) is None


def test_heat_index_nws_known_value():
    # 90 °F / 70 % RH ≈ 106 °F ≈ 41 °C (NWS reference table)
    assert comfort.heat_index_c(32.22, 70.0) == pytest.approx(41.1, abs=0.6)
    # Below 80 °F the simple formula is used and stays close to the air temperature.
    assert comfort.heat_index_c(20.0, 50.0) == pytest.approx(19.4, abs=1.5)


@pytest.mark.parametrize(
    "hi,level",
    [(20, None), (28, "caution"), (35, "extreme_caution"), (45, "danger"), (60, "extreme_danger")],
)
def test_heat_levels(hi, level):
    assert comfort.heat_level(hi) == level


@pytest.mark.parametrize(
    "dew,rh,category",
    [(5, 40, "Dry"), (12, 55, "Comfortable"), (18, 70, "Humid"), (25, 90, "Oppressive"),
     (18, 20, "Dry")],
)
def test_humidity_bands(dew, rh, category):
    assert comfort.humidity_category(dew, rh) == category


@pytest.mark.parametrize(
    "kph,force",
    [(0, 0), (1, 0), (4, 1), (11, 2), (19, 3), (28, 4), (38, 5), (49, 6),
     (61, 7), (74, 8), (88, 9), (102, 10), (117, 11), (150, 12)],
)
def test_beaufort_upper_bounds(kph, force):
    assert comfort.beaufort(kph) == force


def test_comfort_index_formula():
    assert comfort.comfort_index(24, 45, 10, 3, 0) == 100
    assert comfort.comfort_category(100) == "Ideal"
    # 34 °C, 85 % RH, calm, UV 9, 60 % rain chance
    expected = 100 - 30 - 20 - 0 - 0 - 9 - 18
    assert comfort.comfort_index(34, 85, 10, 9, 60) == expected
    assert comfort.comfort_category(expected) == "Uncomfortable"


def test_uv_categories_who_bands():
    assert comfort.uv_category(1) == "Low"
    assert comfort.uv_category(4) == "Moderate"
    assert comfort.uv_category(7) == "High"
    assert comfort.uv_category(9) == "Very High"
    assert comfort.uv_category(12) == "Extreme"


# ------------------------------------------------------------------ marine


@pytest.mark.parametrize(
    "h,state",
    [(0.05, "Calm"), (0.3, "Smooth"), (1.0, "Slight"), (2.0, "Moderate"),
     (3.0, "Rough"), (5.0, "Very Rough"), (7.0, "High")],
)
def test_douglas_sea_state(h, state):
    assert marine.sea_state(h) == state


def test_swim_safety_and_surf_rating():
    assert marine.safe_for_swimming(1.0, 2.0, set()) is True
    assert marine.safe_for_swimming(1.6, 1.0, set()) is False
    assert marine.safe_for_swimming(1.0, 4.0, set()) is False
    assert marine.safe_for_swimming(1.0, 1.0, {"cyclone"}) is False
    assert marine.surf_rating(1.8, 10.0) == 5
    assert marine.surf_rating(1.2, 8.0) == 4
    assert marine.surf_rating(0.2, 12.0) == 0


def test_water_temperature_categories():
    assert marine.water_category(18) == "Cold"
    assert marine.water_category(22) == "Cool"
    assert marine.water_category(28) == "Pleasant"
    assert marine.water_category(30) == "Warm"


# ------------------------------------------------------------------ visibility


@pytest.mark.parametrize(
    "km,category",
    [(20, "Excellent"), (10, "Excellent"), (5, "Good"), (3, "Moderate"),
     (1.5, "Poor"), (0.7, "Very Poor"), (0.2, "Dense fog")],
)
def test_visibility_categories(km, category):
    assert visibility.category(km) == category


def test_visibility_lists_fog_hours_and_urgency():
    now = datetime(2026, 1, 12, 5, 0, tzinfo=IST)
    hourly = synthetic_day(now, visibility_km=lambda t: 0.3 if t.hour < 9 else 12.0)
    out = visibility.build(visibility_km=0.2, hourly=hourly, now=now)
    assert out["category"] == "Dense fog"
    assert out["urgency"] == 0.8
    assert [h["visibility_km"] for h in out["fog_expected_hours"]] == [0.3] * 4


# ------------------------------------------------------------------ workout


def test_workout_scoring_penalties():
    base = dict(temp_c=24, humidity_pct=50, aqi=50, uv=3, precip_prob_pct=0,
                wind_kph=10, is_day=True)
    assert workout.hour_score(**base) == 100
    assert workout.hour_score(**{**base, "temp_c": 35}) == 85          # −3/°C over 30
    assert workout.hour_score(**{**base, "humidity_pct": 85}) == 90    # −1/% over 75
    assert workout.hour_score(**{**base, "aqi": 300}) == 40            # −0.3/pt over 100
    assert workout.hour_score(**{**base, "uv": 9}) == 84               # −8/pt over 7
    assert workout.hour_score(**{**base, "is_day": False}) == 75       # dark −25


def test_workout_windows_on_a_synthetic_day():
    now = datetime(2026, 3, 10, 5, 0, tzinfo=IST)
    hourly = synthetic_day(
        now,
        temp_c=lambda t: 24.0 if t.hour < 10 or t.hour > 17 else 38.0,
        is_day=lambda t: 6 <= t.hour <= 18,
    )
    out = workout.build(hourly=hourly, now=now)
    assert out["best"] is not None
    assert out["best"]["label"] in ("Great", "Good", "Fair")
    assert len(out["windows"]) <= 3
    assert len(out["hourly_scores"]) == 24
    assert out["no_good_window_reason"] is None
    best_start = datetime.fromisoformat(out["best"]["start"])
    assert best_start.hour < 10 or best_start.hour > 17


def test_workout_reports_why_no_window_exists():
    now = datetime(2026, 5, 20, 6, 0, tzinfo=IST)
    hourly = synthetic_day(now, temp_c=48.0, humidity_pct=90.0, is_day=True)
    out = workout.build(hourly=hourly, now=now)
    assert out["best"] is None
    assert out["no_good_window_reason"]
    assert out["urgency"] == 0.4


# ------------------------------------------------------------------ school run


@pytest.mark.parametrize(
    "kwargs,expected",
    [
        (dict(precip_prob_pct=10, visibility_km=12, feels_like_c=28,
              aqi_category="Moderate", thunderstorm=False, severe_warning=False), "good"),
        (dict(precip_prob_pct=45, visibility_km=12, feels_like_c=28,
              aqi_category="Moderate", thunderstorm=False, severe_warning=False), "caution"),
        (dict(precip_prob_pct=10, visibility_km=12, feels_like_c=28,
              aqi_category="Very Poor", thunderstorm=False, severe_warning=False), "caution"),
        (dict(precip_prob_pct=75, visibility_km=12, feels_like_c=28,
              aqi_category="Moderate", thunderstorm=False, severe_warning=False), "poor"),
        (dict(precip_prob_pct=10, visibility_km=0.8, feels_like_c=28,
              aqi_category="Moderate", thunderstorm=False, severe_warning=False), "poor"),
        (dict(precip_prob_pct=10, visibility_km=12, feels_like_c=43,
              aqi_category="Moderate", thunderstorm=False, severe_warning=False), "poor"),
        (dict(precip_prob_pct=10, visibility_km=12, feels_like_c=28,
              aqi_category="Severe", thunderstorm=False, severe_warning=False), "poor"),
        (dict(precip_prob_pct=10, visibility_km=0.4, feels_like_c=28,
              aqi_category="Good", thunderstorm=False, severe_warning=False), "avoid"),
        (dict(precip_prob_pct=10, visibility_km=12, feels_like_c=28,
              aqi_category="Good", thunderstorm=True, severe_warning=False), "avoid"),
        (dict(precip_prob_pct=10, visibility_km=12, feels_like_c=28,
              aqi_category="Good", thunderstorm=False, severe_warning=True), "avoid"),
    ],
)
def test_school_commute_verdict_table(kwargs, expected):
    verdict, reasons = school_commute.verdict_for(**kwargs)
    assert verdict == expected
    assert reasons


def test_school_commute_windows_are_the_next_occurrence():
    now = datetime(2026, 9, 8, 6, 0, tzinfo=IST)  # a Tuesday
    out = school_commute.build(
        hourly=synthetic_day(now, hours=40), now=now, aqi_category="Good", aqi=42
    )
    labels = [w["label"] for w in out["windows"]]
    assert labels == ["morning_drop", "afternoon_pickup"]
    assert out["windows"][0]["start"].endswith("07:00:00+05:30")
    assert out["windows"][1]["end"].endswith("16:00:00+05:30")
    assert out["is_school_day"] is True
    assert out["overall_verdict"] == "good"


# ------------------------------------------------------------------ commute


@pytest.mark.parametrize(
    "hour,base",
    [(3, 20), (7, 50), (8, 70), (9, 70), (10, 50), (12, 40), (16, 50),
     (17, 70), (19, 70), (20, 50), (22, 20)],
)
def test_traffic_congestion_base_by_hour(hour, base):
    assert commute.congestion_base(hour) == base


def test_traffic_weather_multipliers_and_cap():
    dry = commute.estimate_congestion(hour=8)
    assert dry == {"congestion_pct": 70, "source": "estimated", "weather_factor": None}
    rain = commute.estimate_congestion(hour=12, precip_mm=1.0)
    assert rain["congestion_pct"] == 52  # 40 × 1.3
    storm = commute.estimate_congestion(hour=8, thunderstorm=True)
    assert storm["congestion_pct"] == 100  # 70 × 1.8 capped
    fog = commute.estimate_congestion(hour=12, visibility_km=0.4)
    assert fog["congestion_pct"] == 60  # 40 × 1.5


def test_commute_delay_minutes():
    assert commute.delay_minutes(peak=True, weather=None) == 12
    assert commute.delay_minutes(peak=True, weather="rain") == 16
    assert commute.delay_minutes(peak=True, weather="storm") == 22
    assert commute.delay_minutes(peak=False, weather="fog") == 8


@pytest.mark.parametrize(
    "kwargs,expected",
    [
        (dict(precip_prob_pct=5, visibility_km=15, wind_kph=10,
              thunderstorm=False, severe_warning=False), "low"),
        (dict(precip_prob_pct=50, visibility_km=15, wind_kph=10,
              thunderstorm=False, severe_warning=False), "moderate"),
        (dict(precip_prob_pct=5, visibility_km=15, wind_kph=45,
              thunderstorm=False, severe_warning=False), "moderate"),
        (dict(precip_prob_pct=80, visibility_km=15, wind_kph=10,
              thunderstorm=False, severe_warning=False), "high"),
        (dict(precip_prob_pct=5, visibility_km=0.4, wind_kph=10,
              thunderstorm=False, severe_warning=False), "severe"),
        (dict(precip_prob_pct=5, visibility_km=15, wind_kph=10,
              thunderstorm=False, severe_warning=True), "severe"),
    ],
)
def test_commute_impact_table(kwargs, expected):
    impact, reasons = commute.impact_for(**kwargs)
    assert impact == expected
    assert reasons


def test_commute_windows_and_traffic_block():
    now = datetime(2026, 9, 8, 6, 30, tzinfo=IST)
    out = commute.build(hourly=synthetic_day(now, hours=40), now=now)
    assert [w["label"] for w in out["windows"]] == ["morning", "evening"]
    assert out["windows"][0]["start"].endswith("08:00:00+05:30")
    assert out["windows"][1]["end"].endswith("20:00:00+05:30")
    assert out["traffic"]["source"] == "estimated"
    assert 0 <= out["traffic"]["congestion_pct"] <= 100


# ------------------------------------------------------------------ frost


@pytest.mark.parametrize(
    "tmin,wind,cloud,cold_wave,risk",
    [
        (8, 5, 10, False, "none"),
        (5.5, 5, 10, False, "low"),
        (3.5, 5, 10, False, "moderate"),   # ≤4, calm & clear
        (3.5, 20, 60, False, "low"),       # ≤4, windy/cloudy
        (1.5, 5, 10, False, "high"),       # ≤2, calm & clear
        (1.5, 20, 60, False, "moderate"),  # ≤2, windy/cloudy
        (-1, 20, 90, False, "high"),       # ≤0 always high
        (10, 20, 90, True, "moderate"),    # cold-wave warning floor
    ],
)
def test_frost_risk_table(tmin, wind, cloud, cold_wave, risk):
    assert frost.risk_for(tmin, wind, cloud, cold_wave) == risk


def test_frost_uses_the_coming_night():
    now = datetime(2026, 1, 15, 18, 0, tzinfo=IST)
    hourly = synthetic_day(
        now, hours=24, temp_c=lambda t: -1.0 if t.hour >= 22 or t.hour <= 7 else 12.0,
        wind_kph=4.0, cloud_pct=5.0,
    )
    out = frost.build(hourly=hourly, now=now)
    assert out["risk"] == "high"
    assert out["tmin_c"] == -1.0
    assert out["urgency"] == 0.85
    assert out["advice"]


# ------------------------------------------------------------------ tides


def test_tides_are_deterministic_and_labelled_estimated():
    now = datetime(2026, 9, 7, 6, 0, tzinfo=IST)
    a = tides.build(lat=15.49, lon=73.83, state="Goa", now=now)
    b = tides.build(lat=15.49, lon=73.83, state="Goa", now=now)
    assert a == b
    assert a["source"] == "estimated"
    assert a["disclaimer_key"] == "tides.disclaimer"
    assert a["trend"] in ("rising", "falling")
    assert len(a["events"]) >= 4
    types = [e["type"] for e in a["events"]]
    assert all(x != y for x, y in zip(types, types[1:], strict=False)), "high/low must alternate"


def test_tide_amplitude_follows_the_state_table():
    assert tides.amplitude_for_state("Gujarat") == 3.0
    assert tides.amplitude_for_state("Goa") == 1.1
    assert tides.amplitude_for_state("Kerala") == 0.6
    assert tides.amplitude_for_state("West Bengal") == 2.2
    assert tides.amplitude_for_state("Andaman and Nicobar Islands") == 1.2
    assert tides.amplitude_for_state("Lakshadweep") == 0.8
    assert tides.amplitude_for_state(None) == 1.0

    now = datetime(2026, 9, 7, 6, 0, tzinfo=IST)
    gj = tides.build(lat=21.64, lon=69.61, state="Gujarat", now=now)
    kl = tides.build(lat=8.52, lon=76.94, state="Kerala", now=now)
    assert gj["amplitude_m"] > kl["amplitude_m"]


def test_tide_period_is_about_12_4_hours():
    now = datetime(2026, 9, 7, 0, 0, tzinfo=IST)
    ev = tides.build(lat=15.49, lon=73.83, state="Goa", now=now)["events"]
    highs = [datetime.fromisoformat(e["time"]) for e in ev if e["type"] == "high"]
    gap_h = (highs[1] - highs[0]).total_seconds() / 3600
    assert gap_h == pytest.approx(12.42, abs=0.2)


# ------------------------------------------------------------------ pollen


def test_pollen_falls_back_to_the_estimator_for_india():
    assert pollen.from_open_meteo({"grass_pollen": None, "birch_pollen": None}) is None
    est = pollen.estimate(now=datetime(2026, 3, 15, 9, 0, tzinfo=IST))
    assert est["source"] == "estimated"
    assert est["by_type"] == {"tree": 3, "grass": 3, "weed": 1}
    assert est["index"] == 3 and est["level"] == "High"


def test_pollen_estimator_adjustments():
    march = dict(now=datetime(2026, 3, 15, 9, 0, tzinfo=IST))
    wet = pollen.estimate(**march, rain_last_6h_mm=2.0)
    assert wet["by_type"]["tree"] == 2
    humid = pollen.estimate(**march, humidity_pct=90)
    assert humid["by_type"]["tree"] == 2
    windy_dry = pollen.estimate(**march, wind_kph=30, humidity_pct=40)
    assert windy_dry["by_type"]["tree"] == 4
    assert windy_dry["level"] == "Very High"


def test_pollen_uses_open_meteo_when_values_exist():
    out = pollen.from_open_meteo({"grass_pollen": 45.0, "birch_pollen": 2.0})
    assert out["source"] == "open-meteo"
    assert out["dominant"] == "grass"


# ------------------------------------------------------------------ nowcast


def test_nowcast_derives_thunderstorm_rain_fog_and_quiet():
    now = datetime(2026, 7, 1, 14, 0, tzinfo=IST)
    storm = nowcast.derive(hourly=synthetic_day(now, condition_code=95), now=now)
    assert storm["severity"] == "severe" and storm["text"] == "Thunderstorm likely"

    rain = nowcast.derive(hourly=synthetic_day(now, precip_prob_pct=75), now=now)
    assert rain["severity"] == "moderate" and rain["text"].startswith("Rain likely by ")

    fog = nowcast.derive(hourly=synthetic_day(now, condition_code=45), now=now)
    assert fog["severity"] == "moderate" and "Fog" in fog["text"]

    quiet = nowcast.derive(hourly=synthetic_day(now), now=now)
    assert quiet["severity"] == "none"
    assert quiet["text"] == "No significant weather in next 3 hours"
    assert quiet["source"] == "derived"


# ------------------------------------------------------------------ packing / planting / flight


def test_packing_rules():
    daily = [
        {"date": "2026-01-10", "tmin_c": 4.0, "tmax_c": 16.0, "feels_like_max_c": 39.0,
         "precip_prob_max_pct": 55, "uv_index_max": 9.0, "wind_max_kph": 45.0,
         "precip_sum_mm": 8.0, "condition_code": 71},
        {"date": "2026-01-11", "tmin_c": 6.0, "tmax_c": 18.0, "feels_like_max_c": 20.0,
         "precip_prob_max_pct": 10, "uv_index_max": 4.0, "wind_max_kph": 12.0,
         "precip_sum_mm": 0.0, "condition_code": 0},
    ]
    hourly = [{"humidity_pct": 85.0}]
    items = {i["item"] for i in packing.build(
        daily=daily, hourly=hourly, aqi_category="Very Poor")["items"]}
    assert {"Raincoat / umbrella", "Warm layers", "Heavy jacket", "Sunscreen & hat",
            "Light cotton clothes", "Windbreaker", "N95 mask", "Waterproof boots",
            "Extra water / ORS"} <= items


def test_planting_zone_season_and_soil_tips():
    assert planting.zone_for("Punjab") == "north"
    assert planting.zone_for("Kerala") == "south"
    assert planting.zone_for("Assam") == "northeast"
    assert planting.zone_for("Himachal Pradesh") == "hills"
    assert planting.zone_for("Rajasthan", 2500) == "hills"  # elevation wins
    assert planting.season_for(7) == "kharif"
    assert planting.season_for(12) == "rabi"
    assert planting.season_for(4) == "zaid"

    out = planting.build(now=datetime(2026, 7, 1, 9, 0, tzinfo=IST), state="Punjab",
                         soil_surface=0.05, rain_next_72h_mm=60)
    assert out["zone"] == "north" and out["season"] == "kharif"
    assert 2 <= len(out["crops"]) <= 4
    assert out["soil_status"] == "very_dry"
    assert any("Delay irrigation" in tip for tip in out["tips"])


@pytest.mark.parametrize(
    "hourly_kw,warns,risk",
    [
        ({}, [], "low"),
        ({"visibility_km": 0.5}, [], "high"),
        ({"condition_code": 95}, [], "high"),
        ({"gust_kph": 65.0}, [], "high"),
        ({}, [{"severity": "red", "hazard": "cyclone"}], "high"),
        ({"visibility_km": 2.0}, [], "medium"),
        ({"gust_kph": 50.0}, [], "medium"),
        ({"precip_prob_pct": 80.0}, [], "medium"),
        ({}, [{"severity": "orange", "hazard": "heavy_rain"}], "medium"),
    ],
)
def test_flight_risk_rule(hourly_kw, warns, risk):
    now = datetime(2026, 12, 20, 6, 0, tzinfo=IST)
    out = flight_risk.build(hourly=synthetic_day(now, **hourly_kw), now=now, warnings=warns)
    assert out["risk"] == risk


# ------------------------------------------------------------------ time helpers


@pytest.mark.parametrize(
    "hour,name",
    [(2, "night"), (6, "dawn"), (9, "morning"), (13, "midday"),
     (16, "afternoon"), (19, "evening"), (22, "late")],
)
def test_dayparts(hour, name):
    assert daypart(datetime(2026, 6, 1, hour, tzinfo=IST)) == name


@pytest.mark.parametrize(
    "month,name",
    [(1, "winter"), (2, "winter"), (4, "pre_monsoon"), (7, "monsoon"), (11, "post_monsoon")],
)
def test_seasons(month, name):
    assert season(datetime(2026, month, 1, tzinfo=IST)) == name
