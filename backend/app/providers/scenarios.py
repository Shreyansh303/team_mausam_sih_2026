"""Scenario overlay loader + deep merger (05 §Scenarios).

A scenario file is `{"name", "description", "overrides": {...}, "warnings": [...], "nowcast": {...}}`.
`overrides` keys: `current`, `hourly_all` (broadcast to every hour), `daily_all`, `air_quality`,
`marine`. Warnings are appended with `source: "scenario"` and take the request location's
district/state. The nowcast, when present, replaces the derived one.
"""

from __future__ import annotations

import json
from functools import lru_cache
from typing import Any

from app.config import settings

LIVE = "live"


def _dir():
    return settings.data_dir / "scenarios"


@lru_cache(maxsize=1)
def available() -> list[str]:
    names = sorted(p.stem for p in _dir().glob("*.json"))
    return names


@lru_cache(maxsize=32)
def load(name: str) -> dict[str, Any] | None:
    """Load a scenario definition; `live` (or unknown) → None (no overlay)."""
    if not name or name == LIVE:
        return None
    path = _dir() / f"{name}.json"
    if not path.exists():
        return None
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def exists(name: str) -> bool:
    return name == LIVE or load(name) is not None


def deep_merge(base: dict[str, Any], patch: dict[str, Any]) -> dict[str, Any]:
    """Recursive dict merge; patch wins. Lists are replaced, not concatenated."""
    out = dict(base)
    for k, v in patch.items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = deep_merge(out[k], v)
        else:
            out[k] = v
    return out


def apply_overrides(payload: dict[str, Any], scenario: dict[str, Any]) -> dict[str, Any]:
    """Apply `overrides` onto a plain Snapshot dict (before derived recomputation)."""
    ov = scenario.get("overrides") or {}
    out = dict(payload)

    if "current" in ov and isinstance(out.get("current"), dict):
        out["current"] = deep_merge(out["current"], ov["current"])

    if "hourly_all" in ov and isinstance(out.get("hourly"), list):
        out["hourly"] = [deep_merge(h, ov["hourly_all"]) for h in out["hourly"]]

    if "daily_all" in ov and isinstance(out.get("daily"), list):
        out["daily"] = [deep_merge(d, ov["daily_all"]) for d in out["daily"]]

    if "air_quality" in ov:
        base = out.get("air_quality") or {}
        out["air_quality"] = deep_merge(base, ov["air_quality"])

    if "marine" in ov and out.get("marine"):
        out["marine"] = deep_merge(out["marine"], ov["marine"])

    return out


def reload() -> None:
    load.cache_clear()
    available.cache_clear()
