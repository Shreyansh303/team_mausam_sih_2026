"""HomeResponse and its sub-objects (04 §Objects → HomeResponse)."""

from __future__ import annotations

from pydantic import BaseModel, Field

from app.schemas.card import Card
from app.schemas.location import LocationResult


class HomeContext(BaseModel):
    now: str
    daypart: str
    is_weekend: bool
    season: str
    is_coastal: bool
    scenario: str
    active_personas: list[str] = Field(default_factory=list)
    warning_count: int = 0
    lang: str = "en"


class Banner(BaseModel):
    warning_id: str
    severity: str
    title: str
    color_hex: str


class Freshness(BaseModel):
    weather: str
    air: str | None = None
    marine: str | None = None
    warnings: str | None = None


class Sources(BaseModel):
    weather: str = "open-meteo"
    air: str | None = "open-meteo"
    marine: str | None = None
    warnings: str = "none"


class EngineInfo(BaseModel):
    version: str = "1.0"
    weights: dict[str, float] = Field(
        default_factory=lambda: {"relevance": 0.5, "urgency": 0.5}
    )


class HomeResponse(BaseModel):
    generated_at: str
    location: LocationResult
    context: HomeContext
    banner: Banner | None = None
    pinned: list[Card] = Field(default_factory=list)
    hero: Card
    cards: list[Card] = Field(default_factory=list)
    more_cards: list[Card] = Field(default_factory=list)
    hidden_types: list[str] = Field(default_factory=list)
    freshness: Freshness
    sources: Sources
    engine: EngineInfo = Field(default_factory=EngineInfo)
