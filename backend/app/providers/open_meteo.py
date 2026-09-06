"""Open-Meteo: forecast, air quality, marine, geocoding (exact params from 05 §Providers)."""

from __future__ import annotations

from typing import Any

from app.config import settings
from app.core import cache
from app.providers.base import Result, fetch_json

SOURCE = "open-meteo"

CURRENT_FIELDS = (
    "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,"
    "weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,wind_gusts_10m"
)
HOURLY_FIELDS = (
    "temperature_2m,relative_humidity_2m,dew_point_2m,apparent_temperature,"
    "precipitation_probability,precipitation,weather_code,cloud_cover,visibility,"
    "wind_speed_10m,wind_direction_10m,wind_gusts_10m,uv_index,is_day,"
    "soil_temperature_0cm,soil_moisture_0_to_1cm,soil_moisture_9_to_27cm"
)
DAILY_FIELDS = (
    "weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,"
    "sunrise,sunset,daylight_duration,uv_index_max,precipitation_sum,"
    "precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max"
)
AIR_CURRENT_FIELDS = (
    "pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone,"
    "alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen"
)
AIR_HOURLY_FIELDS = "pm10,pm2_5,ozone,nitrogen_dioxide,sulphur_dioxide,carbon_monoxide"
MARINE_CURRENT_FIELDS = (
    "wave_height,wave_direction,wave_period,swell_wave_height,"
    "ocean_current_velocity,sea_surface_temperature"
)


def forecast_params(lat: float, lon: float) -> dict[str, Any]:
    return {
        "latitude": lat,
        "longitude": lon,
        "timezone": "auto",
        "forecast_days": 16,
        "current": CURRENT_FIELDS,
        "hourly": HOURLY_FIELDS,
        "daily": DAILY_FIELDS,
    }


def air_params(lat: float, lon: float) -> dict[str, Any]:
    return {
        "latitude": lat,
        "longitude": lon,
        "timezone": "auto",
        "forecast_days": 2,
        "current": AIR_CURRENT_FIELDS,
        "hourly": AIR_HOURLY_FIELDS,
    }


def marine_params(lat: float, lon: float) -> dict[str, Any]:
    return {
        "latitude": lat,
        "longitude": lon,
        "timezone": "auto",
        "forecast_days": 2,
        "current": MARINE_CURRENT_FIELDS,
        "hourly": "wave_height",
    }


def geocode_params(name: str, count: int = 10) -> dict[str, Any]:
    return {"name": name, "count": count, "language": "en", "format": "json"}


async def fetch_forecast(lat: float, lon: float) -> Result:
    key = cache.key_for("om_forecast", lat, lon)
    return await cache.get_or_fetch(
        "om_forecast",
        key,
        settings.cache_ttl_forecast,
        lambda: fetch_json(
            settings.open_meteo_forecast_url, forecast_params(lat, lon), source=SOURCE
        ),
    )


async def fetch_air(lat: float, lon: float) -> Result:
    key = cache.key_for("om_air", lat, lon)
    return await cache.get_or_fetch(
        "om_air",
        key,
        settings.cache_ttl_air,
        lambda: fetch_json(settings.open_meteo_air_url, air_params(lat, lon), source=SOURCE),
    )


async def fetch_marine(lat: float, lon: float) -> Result:
    """HTTP 400 or a null wave_height means "not marine" (05)."""
    key = cache.key_for("om_marine", lat, lon)

    async def _go() -> Result:
        res = await fetch_json(
            settings.open_meteo_marine_url, marine_params(lat, lon), source=SOURCE
        )
        if not res.ok and res.status == 400:
            return Result(data=None, source=SOURCE, ok=True, error="not_marine", status=400)
        if res.ok and res.data:
            wave = (res.data.get("current") or {}).get("wave_height")
            if wave is None:
                return Result(data=None, source=SOURCE, ok=True, error="not_marine", status=200)
        return res

    return await cache.get_or_fetch("om_marine", key, settings.cache_ttl_marine, _go)


async def geocode(name: str, count: int = 10) -> Result:
    key = cache.key_for("om_geocode", name=name.strip().lower(), count=count)
    return await cache.get_or_fetch(
        "om_geocode",
        key,
        settings.cache_ttl_geocode,
        lambda: fetch_json(
            settings.open_meteo_geocode_url, geocode_params(name, count), source=SOURCE
        ),
    )


def rank_geocode_results(payload: dict[str, Any] | None) -> list[dict[str, Any]]:
    """India first, then the rest — travellers still get foreign hits (05 §Geocode)."""
    items = list((payload or {}).get("results") or [])
    indian = [r for r in items if (r.get("country_code") or "").upper() == "IN"]
    other = [r for r in items if (r.get("country_code") or "").upper() != "IN"]
    return indian + other
