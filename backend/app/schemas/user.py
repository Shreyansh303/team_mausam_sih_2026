"""User, Place, auth and card-preference schemas (04 §Objects)."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field, field_validator

from app.schemas.location import LocationResult

PERSONA_IDS = (
    "health",
    "fitness",
    "beach",
    "traveler",
    "parent",
    "agriculture",
    "commuter",
    "event_planner",
)
MAX_PERSONAS = 3
PLACE_KINDS = ("home", "work", "school", "travel", "other")


class PersonaRef(BaseModel):
    id: str
    weight: float = 1.0

    @field_validator("id")
    @classmethod
    def _known(cls, v: str) -> str:
        if v not in PERSONA_IDS:
            raise ValueError(f"unknown persona '{v}'")
        return v


class DayWindow(BaseModel):
    label: str
    start: str
    end: str


class User(BaseModel):
    id: str
    phone: str | None = None
    is_guest: bool = True
    language: str = "en"
    units: str = "metric"
    personas: list[PersonaRef] = Field(default_factory=list)
    home_location: LocationResult | None = None
    school_windows: list[DayWindow] = Field(default_factory=list)
    commute_windows: list[DayWindow] = Field(default_factory=list)
    created_at: str


class TokenResponse(BaseModel):
    token: str
    user: User


class OtpRequest(BaseModel):
    phone: str = Field(min_length=6, max_length=20)


class OtpRequestResponse(BaseModel):
    ok: bool = True
    demo_otp: str | None = None


class OtpVerify(BaseModel):
    phone: str = Field(min_length=6, max_length=20)
    otp: str = Field(min_length=4, max_length=8)


class ProfileUpdate(BaseModel):
    """Partial `User` (04 §PUT /me/profile). Only the fields present are applied."""

    personas: list[PersonaRef] | None = None
    language: str | None = None
    units: str | None = None
    home_location: LocationResult | None = None
    school_windows: list[DayWindow] | None = None
    commute_windows: list[DayWindow] | None = None

    @field_validator("personas")
    @classmethod
    def _max_three(cls, v: list[PersonaRef] | None) -> list[PersonaRef] | None:
        if v is not None and len(v) > MAX_PERSONAS:
            raise ValueError(f"at most {MAX_PERSONAS} personas")
        return v


class CardPrefs(BaseModel):
    pins: list[str] = Field(default_factory=list)
    hidden: list[str] = Field(default_factory=list)


class Place(BaseModel):
    id: str
    name: str
    lat: float
    lon: float
    country: str | None = "India"
    country_code: str | None = "IN"
    admin1: str | None = None
    admin2: str | None = None
    kind: Literal["home", "work", "school", "travel", "other"] = "travel"
    timezone: str = "Asia/Kolkata"
    is_coastal: bool = False
    created_at: str


class PlaceCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    lat: float = Field(ge=-90, le=90)
    lon: float = Field(ge=-180, le=180)
    country: str | None = "India"
    country_code: str | None = "IN"
    admin1: str | None = None
    admin2: str | None = None
    kind: Literal["home", "work", "school", "travel", "other"] = "travel"


class OkResponse(BaseModel):
    ok: bool = True
