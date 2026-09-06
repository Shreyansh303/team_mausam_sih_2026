"""Warning (04/02)."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel

Severity = Literal["yellow", "orange", "red"]

HAZARDS = (
    "heavy_rain",
    "very_heavy_rain",
    "thunderstorm",
    "lightning",
    "squall",
    "hail",
    "heatwave",
    "cold_wave",
    "fog",
    "dust_storm",
    "cyclone",
    "strong_wind",
    "snow",
    "flood",
    "other",
)

SEVERITY_COLOR: dict[str, str] = {
    "yellow": "#F5C518",
    "orange": "#F28C28",
    "red": "#D32F2F",
    "green": "#2E7D32",
}

SEVERITY_RANK: dict[str, int] = {"yellow": 1, "orange": 2, "red": 3}


class Warning(BaseModel):
    id: str
    severity: Severity = "yellow"
    hazard: str = "other"
    title: str
    description: str = ""
    issued_at: str
    valid_from: str
    valid_to: str
    district: str | None = None
    state: str | None = None
    lat: float | None = None
    lon: float | None = None
    radius_km: float | None = None
    source: str = "scenario"
    color_hex: str = SEVERITY_COLOR["yellow"]


def color_for(severity: str) -> str:
    return SEVERITY_COLOR.get(severity, SEVERITY_COLOR["yellow"])
