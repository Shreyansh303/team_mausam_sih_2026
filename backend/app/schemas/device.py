"""Device-registration bodies (04 §Devices — optional)."""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.models.device import TOKEN_MAX_LEN


class DeviceRegister(BaseModel):
    """`POST /me/devices` — the FCM registration token plus where the handset is."""

    token: str = Field(min_length=8, max_length=TOKEN_MAX_LEN)
    platform: Literal["android", "ios", "web"] = "android"
    lat: float | None = Field(default=None, ge=-90, le=90)
    lon: float | None = Field(default=None, ge=-180, le=180)
    #: Defaults to the profile language when omitted.
    lang: str | None = Field(default=None, max_length=8)


class Device(BaseModel):
    """`POST /me/devices` response — the caller's own row (it already has the token)."""

    token: str
    platform: str
    lat: float | None = None
    lon: float | None = None
    lang: str = "en"
    updated_at: datetime


class AdminDevice(BaseModel):
    """`GET /admin/devices` row. The token is a send-capability, so only its tail is shown."""

    token_suffix: str
    user_id: str
    platform: str
    lat: float | None = None
    lon: float | None = None
    lang: str = "en"
    updated_at: datetime


class AdminDevices(BaseModel):
    transport: Literal["noop", "fcm"] = "noop"
    count: int = 0
    devices: list[AdminDevice] = Field(default_factory=list)
