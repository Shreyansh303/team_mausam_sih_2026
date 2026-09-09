"""Admin request/response bodies (04 §/admin/*)."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field, model_validator

from app.models.admin_warning import DEFAULT_RADIUS_KM, DEFAULT_TTL_MINUTES
from app.schemas.warning import HAZARDS, Warning


class ScenarioBody(BaseModel):
    name: str = Field(min_length=1, max_length=40)


class NowOverrideBody(BaseModel):
    now: str | None = None


class ResetUserBody(BaseModel):
    user_id: str = Field(min_length=1, max_length=40)


class WarningCreate(BaseModel):
    """`POST /admin/warnings` body. `radius_km` and `ttl_minutes` default per 04."""

    severity: Literal["yellow", "orange", "red"] = "orange"
    hazard: str = "other"
    title: str = Field(min_length=1, max_length=200)
    description: str = Field(default="", max_length=1000)
    district: str | None = Field(default=None, max_length=120)
    state: str | None = Field(default=None, max_length=120)
    lat: float | None = Field(default=None, ge=-90, le=90)
    lon: float | None = Field(default=None, ge=-180, le=180)
    radius_km: float = Field(default=DEFAULT_RADIUS_KM, gt=0, le=2000)
    ttl_minutes: int = Field(default=DEFAULT_TTL_MINUTES, ge=1, le=10080)

    @model_validator(mode="after")
    def _check(self) -> "WarningCreate":
        if self.hazard not in HAZARDS:
            raise ValueError(f"Unknown hazard '{self.hazard}'; one of: {', '.join(HAZARDS)}")
        if (self.lat is None) != (self.lon is None):
            raise ValueError("Provide both lat and lon, or neither")
        if self.lat is None and not (self.district or self.state):
            raise ValueError("Target the warning with lat/lon, district or state")
        return self


class AdminState(BaseModel):
    """`GET /admin/state` (04)."""

    scenario: str
    now_override: str | None = None
    warnings: list[Warning] = Field(default_factory=list)
    connected_clients: int = 0
    #: S3 — registered push devices and the active transport (`noop` until FCM is configured).
    devices: int = 0
    push_transport: str = "noop"
    #: S1 — is the v2 ML ranker blended into `/home`? (`ENGINE_ML=1`; false is the default.)
    engine_ml: bool = False
