"""Snapshot assembly: providers → normalized Snapshot → derived → scenario overlay (05 §Snapshot).

Order (05):
1. resolve location (curated hit within 3 km, else reverse geocode)
2. fetch forecast / air / marine (coastal candidates only) / IMD concurrently
3. normalize into the 04 Snapshot shape; fill current uv_index + visibility_km from hourly
4. compute derived services; attach `sources` and `fetched_at`
5. apply the scenario overlay and recompute derived
6. cache the assembled snapshot for CACHE_TTL_SNAPSHOT keyed by (lat2dp, lon2dp, scenario)
"""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timedelta
from typing import Any

from app.config import settings
from app.core import cache
from app.core.geo import compass, is_coastal
from app.core.timeutil import UTC, iso, parse_local, tz_for
from app.providers import imd as imd_provider
from app.providers import open_meteo, scenarios, tomtom
from app.schemas.snapshot import Snapshot
from app.services import (
    aqi_cpcb,
    comfort,
    commute,
    flight_risk,
    frost,
    locations,
    marine as marine_svc,
    nowcast as nowcast_svc,
    packing,
    planting,
    pollen as pollen_svc,
    school_commute,
    tides as tides_svc,
    visibility as visibility_svc,
    warnings as warnings_svc,
    workout,
)
from app.services.util import next_hours, vals, vmax

log = logging.getLogger("mausam.snapshot")

HOURLY_COUNT = 48
DAILY_COUNT = 16

WMO_TEXT: dict[int, str] = {
    0: "Clear sky",
    1: "Mainly clear",
    2: "Partly cloudy",
    3: "Overcast",
    45: "Fog",
    48: "Depositing rime fog",
    51: "Light drizzle",
    53: "Moderate drizzle",
    55: "Dense drizzle",
    56: "Light freezing drizzle",
    57: "Dense freezing drizzle",
    61: "Slight rain",
    63: "Moderate rain",
    65: "Heavy rain",
    66: "Light freezing rain",
    67: "Heavy freezing rain",
    71: "Slight snowfall",
    73: "Moderate snowfall",
    75: "Heavy snowfall",
    77: "Snow grains",
    80: "Slight rain showers",
    81: "Moderate rain showers",
    82: "Violent rain showers",
    85: "Slight snow showers",
    86: "Heavy snow showers",
    95: "Thunderstorm",
    96: "Thunderstorm with slight hail",
    99: "Thunderstorm with heavy hail",
}


def condition_text(code: int | None) -> str:
    if code is None:
        return "—"
    return WMO_TEXT.get(int(code), "Unsettled")


def condition_key(code: int | None) -> str:
    return f"condition.{int(code)}" if code is not None else "condition.unknown"


# --------------------------------------------------------------------- normalize


def _series(block: dict[str, Any] | None, key: str) -> list[Any]:
    return list((block or {}).get(key) or [])


def _at(series: list[Any], i: int) -> Any:
    return series[i] if 0 <= i < len(series) else None


def _km(metres: Any) -> float | None:
    return None if metres is None else round(float(metres) / 1000.0, 3)


def normalize_forecast(payload: dict[str, Any], tzinfo: Any) -> dict[str, Any]:
    """Open-Meteo forecast payload → Snapshot `current` / `hourly` / `daily`."""
    cur = payload.get("current") or {}
    hourly_block = payload.get("hourly") or {}
    daily_block = payload.get("daily") or {}

    times = _series(hourly_block, "time")
    hours: list[dict[str, Any]] = []
    for i, t in enumerate(times):
        dt = parse_local(t, tzinfo)
        code = _at(_series(hourly_block, "weather_code"), i)
        hours.append(
            {
                "time": iso(dt),
                "_dt": dt,
                "temp_c": _at(_series(hourly_block, "temperature_2m"), i),
                "feels_like_c": _at(_series(hourly_block, "apparent_temperature"), i),
                "humidity_pct": _at(_series(hourly_block, "relative_humidity_2m"), i),
                "dew_point_c": _at(_series(hourly_block, "dew_point_2m"), i),
                "precip_prob_pct": _at(_series(hourly_block, "precipitation_probability"), i),
                "precip_mm": _at(_series(hourly_block, "precipitation"), i),
                "wind_kph": _at(_series(hourly_block, "wind_speed_10m"), i),
                "wind_dir_deg": _at(_series(hourly_block, "wind_direction_10m"), i),
                "gust_kph": _at(_series(hourly_block, "wind_gusts_10m"), i),
                "uv_index": _at(_series(hourly_block, "uv_index"), i),
                "visibility_km": _km(_at(_series(hourly_block, "visibility"), i)),
                "cloud_pct": _at(_series(hourly_block, "cloud_cover"), i),
                "condition_code": None if code is None else int(code),
                "is_day": bool(_at(_series(hourly_block, "is_day"), i) or 0),
                "soil_moisture_surface": _at(_series(hourly_block, "soil_moisture_0_to_1cm"), i),
                "soil_moisture_root": _at(_series(hourly_block, "soil_moisture_9_to_27cm"), i),
                "soil_temp_c": _at(_series(hourly_block, "soil_temperature_0cm"), i),
            }
        )

    cur_time = cur.get("time")
    cur_dt = parse_local(cur_time, tzinfo) if cur_time else datetime.now(UTC).astimezone(tzinfo)
    hour_key = cur_dt.replace(minute=0, second=0, microsecond=0)
    idx = next((i for i, h in enumerate(hours) if h["_dt"] == hour_key), None)
    if idx is None:
        idx = next((i for i, h in enumerate(hours) if h["_dt"] >= hour_key), 0)
    match = hours[idx] if hours else {}

    code = cur.get("weather_code")
    current = {
        "time": iso(cur_dt),
        "temp_c": cur.get("temperature_2m"),
        "feels_like_c": cur.get("apparent_temperature"),
        "humidity_pct": cur.get("relative_humidity_2m"),
        "dew_point_c": comfort.dew_point_c(
            cur.get("temperature_2m"), cur.get("relative_humidity_2m")
        ),
        "wind_kph": cur.get("wind_speed_10m"),
        "wind_dir_deg": cur.get("wind_direction_10m"),
        "gust_kph": cur.get("wind_gusts_10m"),
        "pressure_hpa": cur.get("pressure_msl"),
        # 05: current-hour uv_index / visibility come from the matching hourly row
        "visibility_km": match.get("visibility_km"),
        "uv_index": match.get("uv_index"),
        "cloud_pct": cur.get("cloud_cover"),
        "precip_mm": cur.get("precipitation"),
        "condition_code": None if code is None else int(code),
        "condition_text": condition_text(code),
        "is_day": bool(cur.get("is_day", 1)),
    }

    dtimes = _series(daily_block, "time")
    days: list[dict[str, Any]] = []
    for i, d in enumerate(dtimes[:DAILY_COUNT]):
        dcode = _at(_series(daily_block, "weather_code"), i)
        daylight = _at(_series(daily_block, "daylight_duration"), i)
        sunrise = _at(_series(daily_block, "sunrise"), i)
        sunset = _at(_series(daily_block, "sunset"), i)
        days.append(
            {
                "date": d,
                "tmax_c": _at(_series(daily_block, "temperature_2m_max"), i),
                "tmin_c": _at(_series(daily_block, "temperature_2m_min"), i),
                "feels_like_max_c": _at(_series(daily_block, "apparent_temperature_max"), i),
                "precip_prob_max_pct": _at(
                    _series(daily_block, "precipitation_probability_max"), i
                ),
                "precip_sum_mm": _at(_series(daily_block, "precipitation_sum"), i),
                "uv_index_max": _at(_series(daily_block, "uv_index_max"), i),
                "sunrise": iso(parse_local(sunrise, tzinfo)) if sunrise else None,
                "sunset": iso(parse_local(sunset, tzinfo)) if sunset else None,
                "daylight_minutes": None if daylight is None else round(float(daylight) / 60.0, 1),
                "wind_max_kph": _at(_series(daily_block, "wind_speed_10m_max"), i),
                "gust_max_kph": _at(_series(daily_block, "wind_gusts_10m_max"), i),
                "condition_code": None if dcode is None else int(dcode),
            }
        )

    window = hours[idx : idx + HOURLY_COUNT]
    for h in window:
        h.pop("_dt", None)
    for h in hours:
        h.pop("_dt", None)

    return {"current": current, "hourly": window, "daily": days, "now": cur_dt}


def normalize_air(payload: dict[str, Any] | None, tzinfo: Any, now: datetime) -> dict[str, Any] | None:
    if not payload:
        return None
    cur = payload.get("current") or {}
    co_mg = aqi_cpcb.co_ugm3_to_mgm3(cur.get("carbon_monoxide"))
    computed = aqi_cpcb.compute(
        pm2_5=cur.get("pm2_5"),
        pm10=cur.get("pm10"),
        no2=cur.get("nitrogen_dioxide"),
        o3=cur.get("ozone"),
        so2=cur.get("sulphur_dioxide"),
        co_mg=co_mg,
    )

    hourly_block = payload.get("hourly") or {}
    times = _series(hourly_block, "time")
    hourly: list[dict[str, Any]] = []
    for i, t in enumerate(times):
        dt = parse_local(t, tzinfo)
        if dt < now.replace(minute=0, second=0, microsecond=0):
            continue
        sub = aqi_cpcb.compute(
            pm2_5=_at(_series(hourly_block, "pm2_5"), i),
            pm10=_at(_series(hourly_block, "pm10"), i),
            no2=_at(_series(hourly_block, "nitrogen_dioxide"), i),
            o3=_at(_series(hourly_block, "ozone"), i),
            so2=_at(_series(hourly_block, "sulphur_dioxide"), i),
            co_mg=aqi_cpcb.co_ugm3_to_mgm3(_at(_series(hourly_block, "carbon_monoxide"), i)),
        )
        hourly.append({"time": iso(dt), "aqi": sub["aqi"]})
        if len(hourly) >= 24:
            break

    return {
        "time": iso(parse_local(cur["time"], tzinfo)) if cur.get("time") else iso(now),
        "aqi": computed["aqi"],
        "category": computed["category"],
        "dominant_pollutant": computed["dominant_pollutant"],
        "pm2_5": cur.get("pm2_5"),
        "pm10": cur.get("pm10"),
        "o3": cur.get("ozone"),
        "no2": cur.get("nitrogen_dioxide"),
        "so2": cur.get("sulphur_dioxide"),
        "co": co_mg,
        "hourly": hourly,
        "source": "open-meteo",
    }


def normalize_marine(payload: dict[str, Any] | None, tzinfo: Any) -> dict[str, Any] | None:
    if not payload:
        return None
    cur = payload.get("current") or {}
    if cur.get("wave_height") is None:
        return None
    hourly_block = payload.get("hourly") or {}
    times = _series(hourly_block, "time")
    heights = _series(hourly_block, "wave_height")
    hourly = [
        {"time": iso(parse_local(t, tzinfo)), "wave_height_m": _at(heights, i)}
        for i, t in enumerate(times[:48])
    ]
    return {
        "time": iso(parse_local(cur["time"], tzinfo)) if cur.get("time") else None,
        "wave_height_m": cur.get("wave_height"),
        "wave_period_s": cur.get("wave_period"),
        "wave_direction_deg": cur.get("wave_direction"),
        "swell_height_m": cur.get("swell_wave_height"),
        "current_kph": cur.get("ocean_current_velocity"),
        "sst_c": cur.get("sea_surface_temperature"),
        "sea_state": marine_svc.sea_state(cur.get("wave_height")),
        "hourly": hourly,
        "source": "open-meteo",
    }


# --------------------------------------------------------------------- derived


def compute_derived(
    payload: dict[str, Any],
    *,
    now: datetime,
    location: dict[str, Any],
    active_warnings: list[dict[str, Any]],
    tomtom_congestion: int | None = None,
) -> dict[str, Any]:
    """Every derived block. Shapes match the `data` keys of the cards in docs/02."""
    current = payload.get("current") or {}
    hourly: list[dict[str, Any]] = payload.get("hourly") or []
    daily: list[dict[str, Any]] = payload.get("daily") or []
    air = payload.get("air_quality") or {}
    marine_block = payload.get("marine")

    hazards = warnings_svc.hazard_set(active_warnings)
    severe = warnings_svc.has_severe(active_warnings, "orange")
    cold_wave = "cold_wave" in hazards
    aqi_category = air.get("category")
    aqi_value = air.get("aqi")

    temp = current.get("temp_c")
    rh = current.get("humidity_pct")
    dew = current.get("dew_point_c") or comfort.dew_point_c(temp, rh)
    hi_c = comfort.heat_index_c(temp, rh)
    next12 = next_hours(hourly, now, 12)
    next24 = next_hours(hourly, now, 24)
    next72 = next_hours(hourly, now, 72)

    # --- comfort (02 §33) + humidity (02 §10)
    idx = comfort.comfort_index(
        current.get("feels_like_c"),
        rh,
        current.get("wind_kph"),
        current.get("uv_index"),
        (next12[0].get("precip_prob_pct") if next12 else 0),
    )
    best_hours: list[dict[str, Any]] = []
    hour_indices = [
        (
            h["time"],
            comfort.comfort_index(
                h.get("feels_like_c"),
                h.get("humidity_pct"),
                h.get("wind_kph"),
                h.get("uv_index"),
                h.get("precip_prob_pct"),
            ),
        )
        for h in next24
    ]
    for t, v in sorted(hour_indices, key=lambda p: -p[1])[:2]:
        best_hours.append({"start": t, "end": t, "index": v})
    daily_comfort = [
        {
            "date": d["date"],
            "index": comfort.comfort_index(
                d.get("feels_like_max_c"), rh, d.get("wind_max_kph"),
                d.get("uv_index_max"), d.get("precip_prob_max_pct"),
            ),
        }
        for d in daily[:7]
    ]

    derived: dict[str, Any] = {}

    derived["comfort"] = {
        "index": idx,
        "category": comfort.comfort_category(idx),
        "feels_like_c": current.get("feels_like_c"),
        "humidity_pct": rh,
        "wind_kph": current.get("wind_kph"),
        "uv": current.get("uv_index"),
        "best_hours_today": sorted(best_hours, key=lambda h: h["start"]),
        "daily": daily_comfort,
        "advice": _comfort_advice(comfort.comfort_category(idx)),
        "urgency": 0.0,
    }

    derived["humidity"] = {
        "humidity_pct": rh,
        "dew_point_c": dew,
        "category": comfort.humidity_category(dew, rh),
        "trend": comfort.trend_of([h.get("humidity_pct") for h in next12[:6]]),
        "advice": _humidity_advice(comfort.humidity_category(dew, rh)),
        "urgency": 0.3 if (rh is not None and (rh >= 85 or rh <= 20)) else 0.0,
    }

    # --- heat (02 §15)
    level = comfort.heat_level(hi_c)
    peak = max(next24, key=lambda h: (h.get("feels_like_c") or -99), default=None)
    heatwave_red = any(
        w.get("hazard") == "heatwave" and w.get("severity") == "red" for w in active_warnings
    )
    derived["heat"] = {
        "feels_like_c": current.get("feels_like_c"),
        "temp_c": temp,
        "heat_index_c": hi_c,
        "level": level,
        "peak_time": peak["time"] if peak else None,
        "warning": any(w.get("hazard") == "heatwave" for w in active_warnings),
        "advice": _heat_advice(level),
        "urgency": 1.0 if heatwave_red else comfort.HEAT_URGENCY.get(level or "", 0.0),
    }

    # --- workout (02 §12)
    aqi_by_hour = {row["time"]: row["aqi"] for row in (air.get("hourly") or []) if row.get("aqi")}
    derived["workout"] = workout.build(hourly=hourly, now=now, aqi_by_hour=aqi_by_hour)

    # --- school commute (02 §22) + commute (02 §28)
    derived["school_commute"] = school_commute.build(
        hourly=hourly, now=now, aqi_category=aqi_category, aqi=aqi_value, severe_warning=severe
    )
    derived["commute"] = commute.build(
        hourly=hourly, now=now, severe_warning=severe, tomtom_congestion=tomtom_congestion
    )

    # --- frost (02 §26)
    derived["frost"] = frost.build(hourly=hourly, now=now, cold_wave_warning=cold_wave)

    # --- visibility (02 §29)
    derived["visibility"] = visibility_svc.build(
        visibility_km=current.get("visibility_km"), hourly=hourly, now=now
    )

    # --- travel / flight risk (02 §20)
    derived["flight_risk"] = flight_risk.build(hourly=hourly, now=now, warnings=active_warnings)

    # --- packing (02 §21)
    derived["packing"] = packing.build(
        daily=daily, hourly=hourly, aqi_category=aqi_category, days=3
    )

    # --- planting (02 §27)
    rain72 = sum(vals(next72, "precip_mm")) if next72 else None
    derived["planting"] = planting.build(
        now=now,
        state=location.get("admin1"),
        elevation_m=location.get("elevation_m"),
        soil_surface=(hourly[0].get("soil_moisture_surface") if hourly else None),
        rain_next_72h_mm=rain72,
    )

    # --- extras used directly by A2 builders -------------------------------
    derived["sun"] = _sun_block(daily)
    derived["uv"] = _uv_block(current, next24, daily)
    derived["wind"] = _wind_block(current, next24, hazards)
    derived["rain"] = _rain_block(next12, hazards)
    derived["soil"] = _soil_block(hourly, daily, now)
    derived["rainfall_outlook"] = _rainfall_outlook(next24, next72, daily)
    derived["storm_fog"] = _storm_fog(next12, active_warnings, now)
    if marine_block:
        derived["sea"] = marine_svc.build(marine_block, hazards)
    return derived


def _comfort_advice(category: str) -> str:
    return {
        "Ideal": "Perfect conditions — plan anything outdoors.",
        "Comfortable": "Pleasant outside; light clothing is enough.",
        "Fair": "Bearable but not ideal — pick shaded or breezy spots.",
        "Uncomfortable": "Keep outdoor plans short and hydrate often.",
    }[category]


def _humidity_advice(category: str) -> str:
    return {
        "Dry": "Dry air — moisturise and drink water; asthma may flare.",
        "Comfortable": "Humidity is comfortable.",
        "Humid": "Sticky air — sweat evaporates slowly, pace yourself.",
        "Oppressive": "Oppressive humidity — limit exertion, watch for heat cramps.",
    }[category]


def _heat_advice(level: str | None) -> list[str]:
    if not level:
        return []
    base = ["Drink water every 30 minutes, even without thirst."]
    if level in ("extreme_caution", "danger", "extreme_danger"):
        base.append("Avoid direct sun between 12:00 and 16:00.")
        base.append("Wear loose cotton and use ORS if you are working outdoors.")
    if level in ("danger", "extreme_danger"):
        base.append("Heat stroke risk — stop outdoor work and stay indoors.")
    return base


def _sun_block(daily: list[dict[str, Any]]) -> dict[str, Any]:
    today = daily[0] if daily else {}
    sunrise, sunset = today.get("sunrise"), today.get("sunset")
    out: dict[str, Any] = {
        "sunrise": sunrise,
        "sunset": sunset,
        "daylight_minutes": today.get("daylight_minutes"),
        "golden_hour_morning": None,
        "golden_hour_evening": None,
        "civil_twilight_end": None,
    }
    try:
        if sunrise:
            sr = datetime.fromisoformat(sunrise)
            out["golden_hour_morning"] = {"start": iso(sr), "end": iso(sr + timedelta(minutes=60))}
        if sunset:
            ss = datetime.fromisoformat(sunset)
            out["golden_hour_evening"] = {
                "start": iso(ss - timedelta(minutes=60)),
                "end": iso(ss),
            }
            out["civil_twilight_end"] = iso(ss + timedelta(minutes=25))
    except ValueError:  # pragma: no cover - defensive
        pass
    return out


def _uv_block(
    current: dict[str, Any], next24: list[dict[str, Any]], daily: list[dict[str, Any]]
) -> dict[str, Any]:
    uv_now = current.get("uv_index")
    peak = max(next24, key=lambda h: (h.get("uv_index") or -1), default=None)
    uv_max = (daily[0].get("uv_index_max") if daily else None) or (
        peak.get("uv_index") if peak else None
    )
    return {
        "uv_now": uv_now,
        "uv_max_today": uv_max,
        "uv_max_time": peak["time"] if peak else None,
        "category": comfort.uv_category(uv_now),
        "safe_exposure_min": comfort.safe_exposure_min(uv_now),
        "hourly": [{"time": h["time"], "uv": h.get("uv_index")} for h in next24],
        "urgency": 0.7 if (uv_now or 0) >= 11 else (0.5 if (uv_now or 0) >= 8 else 0.0),
    }


def _wind_block(
    current: dict[str, Any], next24: list[dict[str, Any]], hazards: set[str]
) -> dict[str, Any]:
    speed = current.get("wind_kph")
    force = comfort.beaufort(speed)
    urgency = 0.0
    if "strong_wind" in hazards:
        urgency = 0.8
    elif (speed or 0) >= 60:
        urgency = 0.7
    elif (speed or 0) >= 40:
        urgency = 0.4
    return {
        "speed_kph": speed,
        "gust_kph": current.get("gust_kph"),
        "direction_deg": current.get("wind_dir_deg"),
        "direction_text": compass(current.get("wind_dir_deg")),
        "beaufort": force,
        "beaufort_text": comfort.beaufort_text(force),
        "hourly": [{"time": h["time"], "speed_kph": h.get("wind_kph")} for h in next24],
        "advice": comfort.beaufort_text(force),
        "urgency": urgency,
    }


def _rain_block(next12: list[dict[str, Any]], hazards: set[str]) -> dict[str, Any]:
    start = end = None
    for h in next12:
        wet = (h.get("precip_prob_pct") or 0) >= 40 or (h.get("precip_mm") or 0) > 0.1
        if wet and start is None:
            start = h["time"]
        if start and not wet and end is None:
            end = h["time"]
    peak = max(next12, key=lambda h: (h.get("precip_prob_pct") or 0), default=None)
    mm_max = vmax(next12, "precip_mm") or 0.0
    total_mm = sum(vals(next12, "precip_mm"))
    if mm_max < 2.5:
        intensity = "light"
    elif mm_max < 7.6:
        intensity = "moderate"
    elif mm_max < 15:
        intensity = "heavy"
    else:
        intensity = "very_heavy"
    peak_prob = (peak.get("precip_prob_pct") if peak else 0) or 0
    rain_warning = bool({"heavy_rain", "very_heavy_rain", "flood"} & hazards)
    prob3 = max([h.get("precip_prob_pct") or 0 for h in next12[:3]] or [0])
    urgency = 0.0
    if intensity in ("heavy", "very_heavy") or rain_warning:
        urgency = 0.8
    elif prob3 >= 70:
        urgency = 0.6
    return {
        "next_rain_start": start,
        "next_rain_end": end,
        "peak_prob_pct": peak_prob,
        "peak_time": peak["time"] if peak else None,
        "expected_mm": round(total_mm, 1),
        "intensity": intensity,
        "hourly": [
            {
                "time": h["time"],
                "precip_prob_pct": h.get("precip_prob_pct"),
                "precip_mm": h.get("precip_mm"),
            }
            for h in next12
        ],
        "warning": rain_warning,
        "urgency": urgency,
    }


def _soil_block(
    hourly: list[dict[str, Any]], daily: list[dict[str, Any]], now: datetime
) -> dict[str, Any]:
    cur = hourly[0] if hourly else {}
    surface = cur.get("soil_moisture_surface")
    status = planting.soil_status(surface)
    days_since_rain = None
    for i, d in enumerate(daily):
        if (d.get("precip_sum_mm") or 0) >= 1.0:
            days_since_rain = i
            break
    return {
        "surface_m3m3": surface,
        "root_zone_m3m3": cur.get("soil_moisture_root"),
        "status": status,
        "soil_temp_c": cur.get("soil_temp_c"),
        "days_since_rain": days_since_rain,
        "advice": {
            "very_dry": "Soil is very dry — irrigate now.",
            "dry": "Soil is drying — plan irrigation within a day or two.",
            "adequate": "Soil moisture is adequate.",
            "wet": "Soil is wet — skip irrigation.",
            "saturated": "Soil is saturated — check drainage to avoid root rot.",
        }.get(status or "", "Soil moisture data unavailable."),
        "urgency": 0.4 if status == "very_dry" else (0.3 if status == "saturated" else 0.0),
    }


def _rainfall_outlook(
    next24: list[dict[str, Any]], next72: list[dict[str, Any]], daily: list[dict[str, Any]]
) -> dict[str, Any]:
    mm24 = round(sum(vals(next24, "precip_mm")), 1)
    mm72 = round(sum(vals(next72, "precip_mm")), 1)
    week = daily[:7]
    mm7 = round(sum(vals(week, "precip_sum_mm")), 1)
    rain_days = sum(1 for d in week if (d.get("precip_sum_mm") or 0) >= 2.5)
    urgency = 0.7 if mm72 >= 115 else (0.5 if mm72 >= 50 else 0.0)
    return {
        "next_24h_mm": mm24,
        "next_72h_mm": mm72,
        "next_7d_mm": mm7,
        "daily": [
            {
                "date": d["date"],
                "mm": d.get("precip_sum_mm"),
                "prob_pct": d.get("precip_prob_max_pct"),
            }
            for d in week
        ],
        "rain_days": rain_days,
        "advice": (
            f"{mm72:.0f} mm expected over the next 3 days — hold irrigation."
            if mm72 >= 35
            else "Little rain in the next 3 days — plan irrigation as usual."
        ),
        "urgency": urgency,
    }


def _storm_fog(
    next12: list[dict[str, Any]], active_warnings: list[dict[str, Any]], now: datetime
) -> dict[str, Any] | None:
    from app.services.util import FOG_CODES, THUNDER_CODES

    hazard = None
    window_start = window_end = None
    for h in next12:
        code = h.get("condition_code")
        if code is not None and int(code) in THUNDER_CODES:
            hazard = "thunderstorm"
        elif code is not None and int(code) in FOG_CODES and hazard is None:
            hazard = "fog"
        if hazard and window_start is None:
            window_start = h["time"]
            window_end = h["time"]
        elif hazard:
            window_end = h["time"]
    gust = vmax(next12, "gust_kph") or 0
    warn = next(
        (
            w
            for w in active_warnings
            if w.get("hazard") in ("thunderstorm", "fog", "squall", "dust_storm", "hail")
        ),
        None,
    )
    if warn:
        hazard = warn["hazard"]
    elif gust >= 60 and hazard is None:
        hazard = "squall"
    if not hazard:
        return None
    if warn and warn.get("severity") == "red":
        level = "severe"
    elif warn:
        level = "warning"
    else:
        level = "watch"
    return {
        "hazard": hazard,
        "level": level,
        "window": {"start": window_start or iso(now), "end": window_end or iso(now)},
        "detail": (warn or {}).get("description")
        or f"{hazard.replace('_', ' ').title()} signalled in the next 12 hours.",
        "warning": bool(warn),
        "advice": _storm_advice(hazard),
        "urgency": {"watch": 0.5, "warning": 0.7, "severe": 0.9}[level],
    }


def _storm_advice(hazard: str) -> list[str]:
    return {
        "thunderstorm": [
            "Move indoors when you hear thunder; avoid trees and open fields.",
            "Unplug sensitive appliances.",
        ],
        "fog": ["Use low beams and fog lamps.", "Allow extra time; avoid overtaking."],
        "squall": ["Secure loose objects on balconies and rooftops."],
        "dust_storm": ["Close windows, wear a mask and glasses outdoors."],
        "hail": ["Park vehicles under cover; protect standing crops if you can."],
    }.get(hazard, [])


# --------------------------------------------------------------------- assembly


async def build_snapshot(
    lat: float,
    lon: float,
    *,
    scenario: str = "live",
    now: datetime | None = None,
    admin_warnings: list[dict[str, Any]] | None = None,
) -> Snapshot:
    """Assemble a Snapshot (uncached). Use `get_snapshot` for the cached path."""
    location = await locations.reverse(lat, lon)
    coastal_candidate = location.is_coastal or is_coastal(lat, lon)

    tasks: dict[str, Any] = {
        "forecast": open_meteo.fetch_forecast(lat, lon),
        "air": open_meteo.fetch_air(lat, lon),
    }
    if coastal_candidate:
        tasks["marine"] = open_meteo.fetch_marine(lat, lon)
    if imd_provider.is_available():
        tasks["imd_nowcast"] = imd_provider.nowcast(lat, lon)
        tasks["imd_warnings"] = imd_provider.warnings(lat, lon)
    if tomtom.enabled():
        tasks["tomtom"] = tomtom.congestion_pct(lat, lon)

    keys = list(tasks)
    results = await asyncio.gather(*(tasks[k] for k in keys), return_exceptions=True)
    got = dict(zip(keys, results, strict=True))

    forecast_res = got.get("forecast")
    if isinstance(forecast_res, BaseException) or forecast_res is None or not forecast_res.ok:
        from app.core.errors import NoDataError

        raise NoDataError("Weather provider unavailable for this location")

    payload = forecast_res.data or {}
    tzname = payload.get("timezone") or location.timezone
    tzinfo = tz_for(tzname, payload.get("utc_offset_seconds"))
    location = location.model_copy(
        update={
            "timezone": tzname,
            "elevation_m": location.elevation_m
            if location.elevation_m is not None
            else payload.get("elevation"),
            "is_coastal": coastal_candidate,
        }
    )

    norm = normalize_forecast(payload, tzinfo)
    ref_now = (now.astimezone(tzinfo) if now else norm["now"]).replace(microsecond=0)

    air_res = got.get("air")
    air = (
        normalize_air(air_res.data, tzinfo, ref_now)
        if air_res is not None and not isinstance(air_res, BaseException) and air_res.ok
        else None
    )

    marine_res = got.get("marine")
    marine = (
        normalize_marine(marine_res.data, tzinfo)
        if marine_res is not None and not isinstance(marine_res, BaseException) and marine_res.ok
        else None
    )

    tomtom_congestion = got.get("tomtom")
    if isinstance(tomtom_congestion, BaseException):
        tomtom_congestion = None

    snap: dict[str, Any] = {
        "location": location.model_dump(),
        # 04: every time carries the *location's* offset. Under a demo clock (`now_override`)
        # this is the reference time, which also makes `docs/fixtures/*.json` reproducible.
        "fetched_at": iso(ref_now if now else datetime.now(UTC).astimezone(tzinfo)),
        "current": norm["current"],
        "hourly": norm["hourly"],
        "daily": norm["daily"],
        "air_quality": air,
        "marine": marine,
        "scenario": scenario,
    }

    # --- warnings -----------------------------------------------------------
    scen = scenarios.load(scenario)
    imd_warn_raw = got.get("imd_warnings")
    imd_warnings: list[dict[str, Any]] = []
    if imd_warn_raw and not isinstance(imd_warn_raw, BaseException):
        for parsed in imd_provider.parse_warnings(imd_warn_raw):
            imd_warnings.append(
                warnings_svc.make_warning(
                    severity=parsed["severity"],
                    hazard="other",
                    title=parsed["title"],
                    description=parsed["description"],
                    now=ref_now,
                    district=parsed.get("district") or location.admin2,
                    state=parsed.get("state") or location.admin1,
                    lat=lat,
                    lon=lon,
                    source="imd",
                )
            )
    scenario_warnings = warnings_svc.from_scenario(
        scen, now=ref_now, district=location.admin2, state=location.admin1, lat=lat, lon=lon
    )
    active = warnings_svc.merge(
        now=ref_now,
        lat=lat,
        lon=lon,
        district=location.admin2,
        state=location.admin1,
        imd=imd_warnings,
        admin=admin_warnings or [],
        scenario=scenario_warnings,
    )
    snap["warnings"] = active

    # --- scenario overlay (05 §5) ------------------------------------------
    if scen:
        snap = scenarios.apply_overrides(snap, scen)
        snap["current"]["condition_text"] = condition_text(snap["current"].get("condition_code"))
        if "air_quality" in (scen.get("overrides") or {}) and snap.get("air_quality"):
            aq = snap["air_quality"]
            recomputed = aqi_cpcb.compute(
                pm2_5=aq.get("pm2_5"), pm10=aq.get("pm10"), no2=aq.get("no2"),
                o3=aq.get("o3"), so2=aq.get("so2"), co_mg=aq.get("co"),
            )
            aq.update(
                aqi=recomputed["aqi"],
                category=recomputed["category"],
                dominant_pollutant=recomputed["dominant_pollutant"],
                source="scenario",
            )
            aq["hourly"] = [{"time": h["time"], "aqi": recomputed["aqi"]} for h in aq.get("hourly", [])]
        if snap.get("marine"):
            snap["marine"]["sea_state"] = marine_svc.sea_state(snap["marine"].get("wave_height_m"))

    # --- pollen -------------------------------------------------------------
    om_pollen = pollen_svc.from_open_meteo((air_res.data or {}).get("current") if air_res and not isinstance(air_res, BaseException) and air_res.ok else None)
    if om_pollen is None:
        rain6 = sum(vals(next_hours(snap["hourly"], ref_now, 6), "precip_mm"))
        om_pollen = pollen_svc.estimate(
            now=ref_now,
            rain_last_6h_mm=rain6,
            humidity_pct=snap["current"].get("humidity_pct"),
            wind_kph=snap["current"].get("wind_kph"),
        )
    snap["pollen"] = om_pollen

    # --- tides (estimated, coastal only) ------------------------------------
    if snap.get("marine"):
        snap["tides"] = tides_svc.build(
            lat=lat, lon=lon, state=location.admin1, now=ref_now
        )
    else:
        snap["tides"] = None

    # --- nowcast ------------------------------------------------------------
    imd_now_raw = got.get("imd_nowcast")
    imd_nowcast = (
        imd_provider.parse_nowcast(imd_now_raw)
        if imd_now_raw and not isinstance(imd_now_raw, BaseException)
        else None
    )
    nc = nowcast_svc.from_imd(imd_nowcast, now=ref_now)
    if nc is None:
        nc = nowcast_svc.derive(hourly=snap["hourly"], now=ref_now)
    if scen and scen.get("nowcast"):
        nc = {**nc, **scen["nowcast"], "source": "scenario"}
        nc.setdefault("issued_at", iso(ref_now))
        nc.setdefault("valid_till", iso(ref_now + timedelta(hours=3)))
    snap["nowcast"] = nc

    # --- derived (recomputed after the overlay) -----------------------------
    snap["derived"] = compute_derived(
        snap,
        now=ref_now,
        location=snap["location"],
        active_warnings=snap["warnings"],
        tomtom_congestion=tomtom_congestion,
    )
    snap["traffic"] = snap["derived"]["commute"]["traffic"]

    snap["sources"] = {
        "weather": "scenario" if scen else "open-meteo",
        "air": ("scenario" if scen and "air_quality" in (scen.get("overrides") or {}) else
                ("open-meteo" if air else "none")),
        "marine": (None if not snap.get("marine") else ("scenario" if scen else "open-meteo")),
        "warnings": (active[0]["source"] if active else "none"),
        "nowcast": nc.get("source", "derived"),
        "pollen": snap["pollen"]["source"],
        "tides": "estimated" if snap.get("tides") else None,
        "traffic": snap["traffic"]["source"],
        "imd": imd_provider.status(),
    }

    return Snapshot.model_validate(snap)


async def get_snapshot(
    lat: float,
    lon: float,
    *,
    scenario: str = "live",
    now: datetime | None = None,
    admin_warnings: list[dict[str, Any]] | None = None,
) -> Snapshot:
    """Cached snapshot, keyed by (lat 2 dp, lon 2 dp, scenario) — 05 §6."""
    if now is not None or admin_warnings:
        # A demo clock or injected warnings must not poison the shared cache.
        return await build_snapshot(
            lat, lon, scenario=scenario, now=now, admin_warnings=admin_warnings
        )
    key = cache.key_for("snapshot", lat, lon, scenario=scenario)
    return await cache.get_or_fetch(
        "snapshot",
        key,
        settings.cache_ttl_snapshot,
        lambda: build_snapshot(lat, lon, scenario=scenario),
    )
