"""Engine inputs: `UserProfile`, `Context` and the `Bundle` the builders read (03 §Inputs).

Nothing in `app/engine/` performs I/O. `api/home.py` fetches the snapshot, radar frames and the
saved-place snapshots, then hands them over as a `Bundle`.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import TYPE_CHECKING, Any

from app.core.timeutil import daypart as daypart_of
from app.core.timeutil import is_weekend as is_weekend_of
from app.core.timeutil import season as season_of

if TYPE_CHECKING:  # pragma: no cover - typing only; keeps engine.ml free of an import cycle
    from app.engine.ml import RankerModel

BASE_PERSONA = "base"


@dataclass
class UserProfile:
    """03 §Inputs → UserProfile. `personas` is `[(id, weight)]`, primary 1.0, others 0.7."""

    personas: list[tuple[str, float]] = field(default_factory=list)
    pins: set[str] = field(default_factory=set)
    hidden: set[str] = field(default_factory=set)
    engagement: dict[str, dict[str, int]] = field(default_factory=dict)
    saved_places: list[dict[str, Any]] = field(default_factory=list)
    language: str = "en"
    units: str = "metric"
    #: Learning v2 (03). `None` — the default and what every v1 caller passes — means the
    #: engine runs the v1 formula unchanged. `api/home.py` attaches a model only when
    #: `ENGINE_ML=1`, so the flag being off is indistinguishable from before it existed.
    ml: "RankerModel | None" = None

    @property
    def persona_ids(self) -> list[str]:
        return [p for p, _ in self.personas]

    def stats(self, card_type: str) -> dict[str, int] | None:
        return self.engagement.get(card_type)


@dataclass
class Context:
    """03 §Inputs → Context."""

    now: datetime
    daypart: str
    is_weekend: bool
    season: str
    location: dict[str, Any]
    active_warnings: list[dict[str, Any]] = field(default_factory=list)
    scenario: str = "live"
    lang: str = "en"
    event_date: str | None = None
    lite: bool = False

    @property
    def is_coastal(self) -> bool:
        return bool(self.location.get("is_coastal"))

    @property
    def hazards(self) -> set[str]:
        return {w.get("hazard", "other") for w in self.active_warnings}

    def has_warning(self, *hazards: str, min_severity: str | None = None) -> bool:
        rank = {"yellow": 1, "orange": 2, "red": 3}
        floor = rank.get(min_severity or "yellow", 1)
        for w in self.active_warnings:
            if hazards and w.get("hazard") not in hazards:
                continue
            if rank.get(w.get("severity", "yellow"), 0) >= floor:
                return True
        return False


@dataclass
class Bundle:
    """Everything the builders may read. `snap` is a `Snapshot.model_dump()`."""

    snap: dict[str, Any]
    extras: dict[str, Any] = field(default_factory=dict)

    @property
    def derived(self) -> dict[str, Any]:
        return self.snap.get("derived") or {}

    def block(self, name: str) -> dict[str, Any]:
        return self.derived.get(name) or {}

    @property
    def current(self) -> dict[str, Any]:
        return self.snap.get("current") or {}

    @property
    def hourly(self) -> list[dict[str, Any]]:
        return self.snap.get("hourly") or []

    @property
    def daily(self) -> list[dict[str, Any]]:
        return self.snap.get("daily") or []

    @property
    def air(self) -> dict[str, Any]:
        return self.snap.get("air_quality") or {}

    @property
    def places(self) -> list[dict[str, Any]]:
        """Resolved saved-place summaries (`api/home.py` fetches them concurrently)."""
        return self.extras.get("places") or []


def build_context(
    *,
    now: datetime,
    location: dict[str, Any],
    active_warnings: list[dict[str, Any]],
    scenario: str = "live",
    lang: str = "en",
    event_date: str | None = None,
    lite: bool = False,
) -> Context:
    """03 §Context derivation — daypart/season/weekend come from the *local* `now`."""
    return Context(
        now=now,
        daypart=daypart_of(now),
        is_weekend=is_weekend_of(now),
        season=season_of(now),
        location=location,
        active_warnings=active_warnings,
        scenario=scenario,
        lang=lang,
        event_date=event_date,
        lite=lite,
    )
