"""The 33 card builders (02 §Per-card specification), one module per card `type`.

`BUILDERS[type](bundle, ctx, profile) -> CardContent`. The registry is built from the catalog
order so a missing module fails loudly at import time rather than silently dropping a card.
"""

from __future__ import annotations

import importlib

from app.engine.builders.base import Builder, CardContent

#: Every card type in docs/02, in catalog order. Module name == card type.
BUILDER_MODULES: tuple[str, ...] = (
    "current_conditions",
    "warnings",
    "nowcast",
    "hourly_forecast",
    "daily_forecast",
    "radar",
    "aqi",
    "pollen",
    "uv_index",
    "humidity",
    "health_advisory",
    "best_workout_window",
    "sun_times",
    "wind",
    "heat_alert",
    "sea_conditions",
    "tides",
    "water_temp",
    "saved_places",
    "travel_alerts",
    "packing_suggestions",
    "school_commute",
    "rain_alert",
    "soil_moisture",
    "rainfall_outlook",
    "frost_alert",
    "planting_guidance",
    "commute_conditions",
    "visibility",
    "storm_fog_alert",
    "extended_forecast",
    "rain_probability",
    "comfort_index",
)

BUILDERS: dict[str, Builder] = {
    name: importlib.import_module(f"app.engine.builders.{name}").build
    for name in BUILDER_MODULES
}

__all__ = ["BUILDERS", "BUILDER_MODULES", "Builder", "CardContent"]
