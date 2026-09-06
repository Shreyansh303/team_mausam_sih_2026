"""LocationResult (04)."""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class LocationResult(BaseModel):
    id: str
    name: str
    admin1: str | None = None
    admin2: str | None = None
    country: str | None = "India"
    country_code: str | None = "IN"
    lat: float
    lon: float
    timezone: str = "Asia/Kolkata"
    is_coastal: bool = False
    elevation_m: float | None = None
    population: int | None = None

    @staticmethod
    def from_city(city: dict[str, Any]) -> "LocationResult":
        return LocationResult(
            id=city["id"],
            name=city["name"],
            admin1=city.get("admin1"),
            admin2=city.get("admin2"),
            country=city.get("country", "India"),
            country_code=city.get("country_code", "IN"),
            lat=city["lat"],
            lon=city["lon"],
            timezone=city.get("tz", "Asia/Kolkata"),
            is_coastal=bool(city.get("is_coastal", False)),
            elevation_m=city.get("elevation_m"),
            population=city.get("population"),
        )


class LocationList(BaseModel):
    results: list[LocationResult] = Field(default_factory=list)
