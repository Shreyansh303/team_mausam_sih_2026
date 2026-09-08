"""Snapshot (04). Field names and units are normative."""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field

from app.schemas.location import LocationResult
from app.schemas.warning import Warning


class CurrentConditions(BaseModel):
    time: str
    temp_c: float | None = None
    feels_like_c: float | None = None
    humidity_pct: float | None = None
    dew_point_c: float | None = None
    wind_kph: float | None = None
    wind_dir_deg: float | None = None
    gust_kph: float | None = None
    pressure_hpa: float | None = None
    visibility_km: float | None = None
    uv_index: float | None = None
    cloud_pct: float | None = None
    precip_mm: float | None = None
    condition_code: int | None = None
    condition_text: str | None = None
    is_day: bool = True


class HourPoint(BaseModel):
    time: str
    temp_c: float | None = None
    feels_like_c: float | None = None
    humidity_pct: float | None = None
    dew_point_c: float | None = None
    precip_prob_pct: float | None = None
    precip_mm: float | None = None
    wind_kph: float | None = None
    wind_dir_deg: float | None = None
    gust_kph: float | None = None
    uv_index: float | None = None
    visibility_km: float | None = None
    cloud_pct: float | None = None
    condition_code: int | None = None
    is_day: bool = True
    soil_moisture_surface: float | None = None
    soil_moisture_root: float | None = None
    soil_temp_c: float | None = None


class DayPoint(BaseModel):
    date: str
    tmax_c: float | None = None
    tmin_c: float | None = None
    feels_like_max_c: float | None = None
    precip_prob_max_pct: float | None = None
    precip_sum_mm: float | None = None
    uv_index_max: float | None = None
    sunrise: str | None = None
    sunset: str | None = None
    daylight_minutes: float | None = None
    wind_max_kph: float | None = None
    gust_max_kph: float | None = None
    condition_code: int | None = None


class AqiHour(BaseModel):
    time: str
    aqi: int | None = None


class AirQuality(BaseModel):
    time: str | None = None
    aqi: int | None = None
    category: str | None = None
    dominant_pollutant: str | None = None
    pm2_5: float | None = None
    pm10: float | None = None
    o3: float | None = None
    no2: float | None = None
    so2: float | None = None
    co: float | None = None
    hourly: list[AqiHour] = Field(default_factory=list)
    source: str = "open-meteo"


class Pollen(BaseModel):
    index: int = 0
    level: str = "Low"
    dominant: str | None = None
    by_type: dict[str, int] = Field(default_factory=dict)
    source: str = "estimated"


class MarineHour(BaseModel):
    time: str
    wave_height_m: float | None = None


class Marine(BaseModel):
    time: str | None = None
    wave_height_m: float | None = None
    wave_period_s: float | None = None
    wave_direction_deg: float | None = None
    swell_height_m: float | None = None
    current_kph: float | None = None
    sst_c: float | None = None
    sea_state: str | None = None
    hourly: list[MarineHour] = Field(default_factory=list)
    source: str = "open-meteo"


class TideEvent(BaseModel):
    time: str
    type: str  # high | low
    height_m: float


class Tides(BaseModel):
    events: list[TideEvent] = Field(default_factory=list)
    now_height_m: float | None = None
    trend: str | None = None  # rising | falling
    source: str = "estimated"
    disclaimer_key: str = "tides.disclaimer"


class Nowcast(BaseModel):
    issued_at: str
    valid_till: str
    text: str
    #: Deferred translation of `text` (`{"key": …, "params": {…}}`) — the card builder
    #: resolves it with the request language, like `Tides.disclaimer_key`.
    text_token: dict[str, Any] | None = None
    severity: str = "none"  # none | moderate | severe
    hazards: list[str] = Field(default_factory=list)
    source: str = "derived"


class Traffic(BaseModel):
    congestion_pct: int = 0
    source: str = "estimated"


class Snapshot(BaseModel):
    location: LocationResult
    fetched_at: str
    sources: dict[str, Any] = Field(default_factory=dict)
    current: CurrentConditions
    hourly: list[HourPoint] = Field(default_factory=list)
    daily: list[DayPoint] = Field(default_factory=list)
    air_quality: AirQuality | None = None
    pollen: Pollen | None = None
    marine: Marine | None = None
    tides: Tides | None = None
    warnings: list[Warning] = Field(default_factory=list)
    nowcast: Nowcast | None = None
    traffic: Traffic | None = None
    derived: dict[str, Any] = Field(default_factory=dict)
    scenario: str = "live"


class RadarFrame(BaseModel):
    time: str
    path: str


class RadarResponse(BaseModel):
    host: str
    past: list[RadarFrame] = Field(default_factory=list)
    nowcast: list[RadarFrame] = Field(default_factory=list)
    tile_template: str
