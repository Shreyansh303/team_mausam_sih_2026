"""The card catalog: the full 02 affinity matrix, gates, multipliers and urgency rules.

One `CardDef` per card type, in the order of docs/02 — that order is also the deterministic
tie-breaker used by `scoring.rank` (03 §Algorithm: "ties broken by catalog order").
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field
from typing import Any

from app.engine.context import Bundle, Context, UserProfile

#: Column order of the 02 affinity matrix.
PERSONAS: tuple[str, ...] = (
    "health",
    "fitness",
    "beach",
    "traveler",
    "parent",
    "agriculture",
    "commuter",
    "event_planner",
)

Gate = Callable[[Bundle, Context, UserProfile], bool]
Multiplier = Callable[[Context], float]
Urgency = Callable[[Bundle, Context], float]


# --------------------------------------------------------------------------- affinity
#: 02 §Affinity matrix — `base | health | fitness | beach | traveler | parent | agriculture |
#: commuter | event_planner`. `current_conditions` is the always-first hero, so it carries a
#: full base affinity and is lifted out of the ranking by `scoring.rank`.
AFFINITY: dict[str, tuple[float, ...]] = {
    "current_conditions": (1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0),
    "warnings":           (0.6, 0.6, 0.6, 0.7, 0.7, 1.0, 0.7, 0.7, 0.6),
    "nowcast":            (0.5, 0.4, 0.5, 0.5, 0.4, 0.6, 0.5, 0.7, 0.4),
    "hourly_forecast":    (0.5, 0.3, 0.5, 0.4, 0.4, 0.5, 0.4, 0.6, 0.5),
    "daily_forecast":     (0.5, 0.3, 0.4, 0.4, 0.6, 0.5, 0.5, 0.3, 0.6),
    "radar":              (0.3, 0.2, 0.3, 0.4, 0.3, 0.4, 0.4, 0.5, 0.3),
    "aqi":                (0.2, 1.0, 0.6, 0.2, 0.2, 0.5, 0.1, 0.4, 0.2),
    "pollen":             (0.0, 0.9, 0.2, 0.0, 0.0, 0.2, 0.2, 0.0, 0.0),
    "uv_index":           (0.2, 0.8, 0.7, 0.8, 0.2, 0.3, 0.3, 0.1, 0.3),
    "humidity":           (0.1, 0.8, 0.3, 0.2, 0.1, 0.1, 0.3, 0.1, 0.3),
    "health_advisory":    (0.0, 1.0, 0.3, 0.0, 0.0, 0.3, 0.0, 0.0, 0.0),
    "best_workout_window": (0.0, 0.4, 1.0, 0.2, 0.0, 0.0, 0.0, 0.0, 0.0),
    "sun_times":          (0.2, 0.1, 0.8, 0.5, 0.2, 0.1, 0.4, 0.1, 0.3),
    "wind":               (0.1, 0.1, 0.7, 0.7, 0.2, 0.1, 0.4, 0.2, 0.3),
    "heat_alert":         (0.3, 0.5, 0.9, 0.4, 0.3, 0.6, 0.5, 0.3, 0.4),
    "sea_conditions":     (0.0, 0.0, 0.1, 1.0, 0.2, 0.1, 0.0, 0.0, 0.1),
    "tides":              (0.0, 0.0, 0.0, 1.0, 0.1, 0.0, 0.0, 0.0, 0.0),
    "water_temp":         (0.0, 0.0, 0.1, 0.7, 0.0, 0.0, 0.0, 0.0, 0.0),
    "saved_places":       (0.3, 0.1, 0.1, 0.1, 1.0, 0.2, 0.1, 0.2, 0.2),
    "travel_alerts":      (0.0, 0.0, 0.0, 0.0, 1.0, 0.1, 0.0, 0.2, 0.1),
    "packing_suggestions": (0.0, 0.0, 0.0, 0.2, 0.9, 0.1, 0.0, 0.0, 0.0),
    "school_commute":     (0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.2, 0.0),
    "rain_alert":         (0.3, 0.2, 0.4, 0.3, 0.3, 0.9, 0.5, 0.8, 0.5),
    "soil_moisture":      (0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0),
    "rainfall_outlook":   (0.0, 0.0, 0.0, 0.0, 0.0, 0.1, 1.0, 0.0, 0.4),
    "frost_alert":        (0.0, 0.1, 0.1, 0.0, 0.0, 0.2, 1.0, 0.1, 0.1),
    "planting_guidance":  (0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.8, 0.0, 0.0),
    "commute_conditions": (0.0, 0.0, 0.0, 0.0, 0.1, 0.4, 0.0, 1.0, 0.0),
    "visibility":         (0.1, 0.0, 0.1, 0.1, 0.5, 0.2, 0.1, 0.9, 0.1),
    "storm_fog_alert":    (0.2, 0.1, 0.2, 0.3, 0.6, 0.5, 0.3, 1.0, 0.3),
    "extended_forecast":  (0.0, 0.0, 0.0, 0.1, 0.5, 0.1, 0.4, 0.0, 1.0),
    "rain_probability":   (0.1, 0.0, 0.1, 0.2, 0.2, 0.3, 0.2, 0.2, 1.0),
    "comfort_index":      (0.0, 0.4, 0.3, 0.3, 0.2, 0.2, 0.0, 0.0, 1.0),
}


def affinity_map(card_type: str) -> dict[str, float]:
    row = AFFINITY[card_type]
    return {"base": row[0], **{p: row[i + 1] for i, p in enumerate(PERSONAS)}}


# --------------------------------------------------------------------------- multipliers


def _mult(
    *,
    dayparts: dict[str, float] | None = None,
    seasons: dict[str, float] | None = None,
    weekday_dayparts: dict[str, float] | None = None,
    weekend: float | None = None,
    weekend_bonus: float | None = None,
) -> tuple[Multiplier, Multiplier]:
    """Build (time_mult, season_mult) from the exception tables in 02."""

    def time_mult(ctx: Context) -> float:
        if weekend is not None and ctx.is_weekend:
            return weekend
        if weekend_bonus is not None and ctx.is_weekend:
            return weekend_bonus
        if weekday_dayparts and not ctx.is_weekend:
            return weekday_dayparts.get(ctx.daypart, 1.0)
        if dayparts:
            return dayparts.get(ctx.daypart, 1.0)
        return 1.0

    def season_mult(ctx: Context) -> float:
        return (seasons or {}).get(ctx.season, 1.0)

    return time_mult, season_mult


ONE: Multiplier = lambda ctx: 1.0  # noqa: E731


# --------------------------------------------------------------------------- gates


def gate_always(bundle: Bundle, ctx: Context, profile: UserProfile) -> bool:
    return True


def gate_warnings(bundle: Bundle, ctx: Context, profile: UserProfile) -> bool:
    return bool(ctx.active_warnings)


def gate_coastal(bundle: Bundle, ctx: Context, profile: UserProfile) -> bool:
    return bool(bundle.derived.get("sea")) and bool(bundle.snap.get("marine"))


def gate_tides(bundle: Bundle, ctx: Context, profile: UserProfile) -> bool:
    return bool(bundle.snap.get("tides"))


def gate_places(bundle: Bundle, ctx: Context, profile: UserProfile) -> bool:
    return bool(bundle.places)


def gate_travel_alerts(bundle: Bundle, ctx: Context, profile: UserProfile) -> bool:
    """02 §20: the card is omitted when every saved place is low risk."""
    return any((p.get("flight_risk") or {}).get("risk") in ("medium", "high") for p in bundle.places)


def gate_heat(bundle: Bundle, ctx: Context, profile: UserProfile) -> bool:
    """02 §15 gate: feels_like ≥ 35 or a heatwave warning."""
    feels = bundle.current.get("feels_like_c")
    if feels is not None and float(feels) >= 35:
        return True
    return "heatwave" in ctx.hazards


def gate_rain(bundle: Bundle, ctx: Context, profile: UserProfile) -> bool:
    """02 §23 gate: precip prob ≥ 40 % within 12 h, or a rain warning."""
    rain = bundle.block("rain")
    if (rain.get("peak_prob_pct") or 0) >= 40:
        return True
    return bool({"heavy_rain", "very_heavy_rain", "flood"} & ctx.hazards)


def gate_frost(bundle: Bundle, ctx: Context, profile: UserProfile) -> bool:
    """02 §26 gate: frost risk ≥ low, or a cold-wave warning."""
    risk = bundle.block("frost").get("risk")
    return risk in ("low", "moderate", "high") or "cold_wave" in ctx.hazards


def gate_storm_fog(bundle: Bundle, ctx: Context, profile: UserProfile) -> bool:
    """02 §30 gate: `derived["storm_fog"]` is None when there is no hazard."""
    return bool(bundle.derived.get("storm_fog"))


def gate_health_advisory(bundle: Bundle, ctx: Context, profile: UserProfile) -> bool:
    """02 §11: only built when at least one item is above `info`."""
    from app.engine.builders import health_advisory

    return any(item["level"] != "info" for item in health_advisory.items_for(bundle, ctx))


def gate_radar(bundle: Bundle, ctx: Context, profile: UserProfile) -> bool:
    return bool(bundle.extras.get("radar"))


def gate_pollen(bundle: Bundle, ctx: Context, profile: UserProfile) -> bool:
    return bundle.snap.get("pollen") is not None


def gate_air(bundle: Bundle, ctx: Context, profile: UserProfile) -> bool:
    return bool(bundle.air)


# --------------------------------------------------------------------------- urgency


def _block_urgency(name: str) -> Urgency:
    def fn(bundle: Bundle, ctx: Context) -> float:
        return float(bundle.block(name).get("urgency") or 0.0)

    return fn


def zero(bundle: Bundle, ctx: Context) -> float:
    return 0.0


WARNING_URGENCY = {"yellow": 0.5, "orange": 0.8, "red": 1.0}


def urgency_warnings(bundle: Bundle, ctx: Context) -> float:
    return max(
        (WARNING_URGENCY.get(w.get("severity", "yellow"), 0.5) for w in ctx.active_warnings),
        default=0.0,
    )


def urgency_nowcast(bundle: Bundle, ctx: Context) -> float:
    severity = (bundle.snap.get("nowcast") or {}).get("severity", "none")
    return {"none": 0.0, "moderate": 0.5, "severe": 0.75}.get(severity, 0.0)


def urgency_radar(bundle: Bundle, ctx: Context) -> float:
    prob = (bundle.extras.get("radar") or {}).get("rain_within_2h_prob_pct") or 0
    return 0.4 if prob >= 60 else 0.0


AQI_URGENCY = {
    "Good": 0.0,
    "Satisfactory": 0.0,
    "Moderate": 0.3,
    "Poor": 0.55,
    "Very Poor": 0.75,
    "Severe": 0.95,
}


def urgency_aqi(bundle: Bundle, ctx: Context) -> float:
    return AQI_URGENCY.get(bundle.air.get("category") or "", 0.0)


def urgency_pollen(bundle: Bundle, ctx: Context) -> float:
    level = (bundle.snap.get("pollen") or {}).get("level")
    if level == "High":
        return 0.4
    if level in ("Very High", "Extreme"):
        return 0.6
    return 0.0


def urgency_health_advisory(bundle: Bundle, ctx: Context) -> float:
    """02 §11 — max of the contributing card urgencies."""
    return max(
        [
            urgency_aqi(bundle, ctx),
            _block_urgency("uv")(bundle, ctx),
            _block_urgency("humidity")(bundle, ctx),
            _block_urgency("heat")(bundle, ctx),
            urgency_pollen(bundle, ctx),
        ]
        or [0.0]
    )


def urgency_places(bundle: Bundle, ctx: Context) -> float:
    """02 §19 — max warning severity across the saved places."""
    best = 0.0
    for place in bundle.places:
        sev = place.get("highest_severity")
        if sev == "red":
            best = max(best, 0.8)
        elif sev == "orange":
            best = max(best, 0.6)
    return best


def urgency_travel_alerts(bundle: Bundle, ctx: Context) -> float:
    risks = {(p.get("flight_risk") or {}).get("risk") for p in bundle.places}
    if "high" in risks:
        return 0.8
    if "medium" in risks:
        return 0.4
    return 0.0


def urgency_packing(bundle: Bundle, ctx: Context) -> float:
    return 0.1


def urgency_sea(bundle: Bundle, ctx: Context) -> float:
    return float(bundle.block("sea").get("urgency") or 0.0)


def urgency_storm_fog(bundle: Bundle, ctx: Context) -> float:
    return float((bundle.derived.get("storm_fog") or {}).get("urgency") or 0.0)


# --------------------------------------------------------------------------- card defs


@dataclass(frozen=True)
class CardDef:
    type: str
    size: str
    renderer: str
    affinity: dict[str, float]
    gate: Gate = gate_always
    time_mult: Multiplier = ONE
    season_mult: Multiplier = ONE
    urgency: Urgency = zero
    actions: tuple[str, ...] = ("details", "pin", "dismiss", "hide")
    order: int = 0
    #: personas surfaced on the card (04 `Card.personas`) — affinity ≥ 0.5.
    personas: tuple[str, ...] = field(default_factory=tuple)


def _def(
    card_type: str,
    size: str,
    renderer: str,
    *,
    gate: Gate = gate_always,
    time_mult: Multiplier = ONE,
    season_mult: Multiplier = ONE,
    urgency: Urgency = zero,
    actions: tuple[str, ...] = ("details", "pin", "dismiss", "hide"),
) -> CardDef:
    aff = affinity_map(card_type)
    personas = tuple(
        p for p in PERSONAS if aff[p] >= 0.5
    )
    return CardDef(
        type=card_type,
        size=size,
        renderer=renderer,
        affinity=aff,
        gate=gate,
        time_mult=time_mult,
        season_mult=season_mult,
        urgency=urgency,
        actions=actions,
        personas=personas,
    )


_nowcast_t, _nowcast_s = _mult(dayparts={"late": 0.7, "night": 0.7})
_daily_t, _daily_s = _mult(dayparts={"evening": 1.2})
_aqi_t, _aqi_s = _mult(
    dayparts={"dawn": 1.2, "evening": 1.2}, seasons={"winter": 1.2, "post_monsoon": 1.2}
)
_pollen_t, _pollen_s = _mult(seasons={"pre_monsoon": 1.3, "monsoon": 0.6})
_uv_t, _uv_s = _mult(dayparts={"morning": 1.3, "midday": 1.3, "night": 0.3, "late": 0.3})
_hum_t, _hum_s = _mult(seasons={"monsoon": 1.2})
_workout_t, _workout_s = _mult(dayparts={"dawn": 1.4, "evening": 1.4, "late": 0.5})
_sun_t, _sun_s = _mult(dayparts={"dawn": 1.2, "evening": 1.2})
_heat_t, _heat_s = _mult(dayparts={"midday": 1.3, "afternoon": 1.3}, seasons={"pre_monsoon": 1.3})
_school_t, _school_s = _mult(
    weekday_dayparts={
        "dawn": 1.5, "morning": 1.5, "midday": 1.3, "afternoon": 1.3, "late": 0.5, "night": 0.5
    },
    weekend=0.4,
)
_rain_t, _rain_s = _mult(seasons={"monsoon": 1.3})
_soil_t, _soil_s = _mult(dayparts={"dawn": 1.2})
_frost_t, _frost_s = _mult(dayparts={"evening": 1.3}, seasons={"winter": 1.3})
_commute_t, _commute_s = _mult(
    weekday_dayparts={"dawn": 1.4, "morning": 1.4, "afternoon": 1.4, "evening": 1.4},
    weekend=0.5,
)
_vis_t, _vis_s = _mult(dayparts={"dawn": 1.3}, seasons={"winter": 1.3})
_ext_t, _ext_s = _mult(weekend_bonus=1.2)
_comfort_t, _comfort_s = _mult(dayparts={"evening": 1.2})


CARDS: tuple[CardDef, ...] = tuple(
    CardDef(**{**c.__dict__, "order": i})
    for i, c in enumerate(
        (
            _def("current_conditions", "hero", "hero", actions=("details", "share", "open_map")),
            _def("warnings", "large", "warnings", gate=gate_warnings, urgency=urgency_warnings,
                 actions=("details", "share", "open_map")),
            _def("nowcast", "medium", "nowcast", time_mult=_nowcast_t, season_mult=_nowcast_s,
                 urgency=urgency_nowcast),
            _def("hourly_forecast", "large", "hourly"),
            _def("daily_forecast", "large", "daily", time_mult=_daily_t, season_mult=_daily_s),
            _def("radar", "medium", "radar", gate=gate_radar, urgency=urgency_radar,
                 actions=("open_map", "details", "pin", "hide")),
            _def("aqi", "medium", "gauge", gate=gate_air, time_mult=_aqi_t, season_mult=_aqi_s,
                 urgency=urgency_aqi),
            _def("pollen", "small", "metric", gate=gate_pollen, time_mult=_pollen_t,
                 season_mult=_pollen_s, urgency=urgency_pollen),
            _def("uv_index", "small", "metric", time_mult=_uv_t, season_mult=_uv_s,
                 urgency=_block_urgency("uv")),
            _def("humidity", "small", "metric", time_mult=_hum_t, season_mult=_hum_s,
                 urgency=_block_urgency("humidity")),
            _def("health_advisory", "medium", "advice_list", gate=gate_health_advisory,
                 urgency=urgency_health_advisory),
            _def("best_workout_window", "medium", "timeline", time_mult=_workout_t,
                 season_mult=_workout_s, urgency=_block_urgency("workout")),
            _def("sun_times", "small", "metric", time_mult=_sun_t, season_mult=_sun_s),
            _def("wind", "small", "metric", urgency=_block_urgency("wind")),
            _def("heat_alert", "medium", "alert", gate=gate_heat, time_mult=_heat_t,
                 season_mult=_heat_s, urgency=_block_urgency("heat")),
            _def("sea_conditions", "large", "sea", gate=gate_coastal, urgency=urgency_sea),
            _def("tides", "medium", "tides", gate=gate_tides),
            _def("water_temp", "small", "metric", gate=gate_coastal),
            _def("saved_places", "large", "places", gate=gate_places, urgency=urgency_places,
                 actions=("open_places", "details", "pin", "hide")),
            _def("travel_alerts", "medium", "advice_list", gate=gate_travel_alerts,
                 urgency=urgency_travel_alerts),
            _def("packing_suggestions", "medium", "advice_list", gate=gate_places,
                 urgency=urgency_packing),
            _def("school_commute", "medium", "timeline", time_mult=_school_t,
                 season_mult=_school_s, urgency=_block_urgency("school_commute")),
            _def("rain_alert", "medium", "alert", gate=gate_rain, time_mult=_rain_t,
                 season_mult=_rain_s, urgency=_block_urgency("rain")),
            _def("soil_moisture", "medium", "gauge", time_mult=_soil_t, season_mult=_soil_s,
                 urgency=_block_urgency("soil")),
            _def("rainfall_outlook", "medium", "bar_chart",
                 urgency=_block_urgency("rainfall_outlook")),
            _def("frost_alert", "medium", "alert", gate=gate_frost, time_mult=_frost_t,
                 season_mult=_frost_s, urgency=_block_urgency("frost")),
            _def("planting_guidance", "medium", "advice_list"),
            _def("commute_conditions", "medium", "timeline", time_mult=_commute_t,
                 season_mult=_commute_s, urgency=_block_urgency("commute")),
            _def("visibility", "small", "metric", time_mult=_vis_t, season_mult=_vis_s,
                 urgency=_block_urgency("visibility")),
            _def("storm_fog_alert", "medium", "alert", gate=gate_storm_fog,
                 urgency=urgency_storm_fog),
            _def("extended_forecast", "large", "daily", time_mult=_ext_t, season_mult=_ext_s),
            _def("rain_probability", "medium", "bar_chart"),
            _def("comfort_index", "medium", "gauge", time_mult=_comfort_t,
                 season_mult=_comfort_s),
        )
    )
)

BY_TYPE: dict[str, CardDef] = {c.type: c for c in CARDS}
CARD_TYPES: tuple[str, ...] = tuple(c.type for c in CARDS)
HERO_TYPE = "current_conditions"

#: 02 §Coverage check — the cards each persona must be able to see.
PERSONA_COVERAGE: dict[str, tuple[str, ...]] = {
    "health": ("aqi", "pollen", "uv_index", "humidity", "health_advisory"),
    "fitness": ("sun_times", "best_workout_window", "wind", "heat_alert"),
    "beach": ("sea_conditions", "tides", "water_temp"),
    "traveler": ("saved_places", "travel_alerts", "packing_suggestions"),
    "parent": ("school_commute", "rain_alert", "warnings"),
    "agriculture": ("soil_moisture", "rainfall_outlook", "frost_alert", "planting_guidance"),
    "commuter": ("commute_conditions", "visibility", "storm_fog_alert"),
    "event_planner": ("extended_forecast", "rain_probability", "comfort_index"),
}


def get(card_type: str) -> CardDef:
    return BY_TYPE[card_type]


def order_of(card_type: str) -> int:
    definition = BY_TYPE.get(card_type)
    return definition.order if definition else len(CARDS)


def as_dict() -> dict[str, Any]:  # pragma: no cover - debugging helper
    return {
        c.type: {"size": c.size, "renderer": c.renderer, "affinity": c.affinity} for c in CARDS
    }
