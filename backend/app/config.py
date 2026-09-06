"""Application settings (pydantic-settings). See .env.example for every variable."""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parent  # backend/app
BACKEND_DIR = BASE_DIR.parent  # backend
DATA_DIR = BASE_DIR / "data"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(BACKEND_DIR / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    # --- general -----------------------------------------------------------
    demo_mode: int = 1
    log_level: str = "INFO"
    app_version: str = "0.1.0"

    # --- auth / admin (used from A2/A3) -----------------------------------
    admin_key: str = "mausam-admin"
    jwt_secret: str = "change-me-in-production"
    jwt_expire_days: int = 30

    # --- storage -----------------------------------------------------------
    database_url: str = "sqlite:///./data/mausam.db"
    redis_url: str = ""

    # --- optional upstream keys -------------------------------------------
    data_gov_in_key: str = ""
    tomtom_key: str = ""

    # --- IMD ---------------------------------------------------------------
    imd_base_url: str = "https://mausam.imd.gov.in/api"
    imd_enabled: int = 1

    # --- demo --------------------------------------------------------------
    default_scenario: str = "live"

    # --- http / cors -------------------------------------------------------
    cors_origins: str = "*"
    http_timeout_s: float = 8.0

    # --- cache TTLs (seconds) ---------------------------------------------
    cache_ttl_forecast: int = 600
    cache_ttl_air: int = 900
    cache_ttl_marine: int = 1800
    cache_ttl_geocode: int = 86400
    cache_ttl_radar: int = 300
    cache_ttl_imd: int = 600
    cache_ttl_snapshot: int = 300

    # --- upstream base urls (overridable in tests) ------------------------
    open_meteo_forecast_url: str = "https://api.open-meteo.com/v1/forecast"
    open_meteo_air_url: str = "https://air-quality-api.open-meteo.com/v1/air-quality"
    open_meteo_marine_url: str = "https://marine-api.open-meteo.com/v1/marine"
    open_meteo_geocode_url: str = "https://geocoding-api.open-meteo.com/v1/search"
    bigdatacloud_url: str = "https://api.bigdatacloud.net/data/reverse-geocode-client"
    rainviewer_url: str = "https://api.rainviewer.com/public/weather-maps.json"

    data_dir: Path = Field(default=DATA_DIR)

    @field_validator("cors_origins")
    @classmethod
    def _strip(cls, v: str) -> str:
        return v.strip()

    @property
    def cors_origin_list(self) -> list[str]:
        if self.cors_origins.strip() in ("", "*"):
            return ["*"]
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def imd_on(self) -> bool:
        return bool(self.imd_enabled)


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
