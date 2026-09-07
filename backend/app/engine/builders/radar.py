"""02 §6 radar — RainViewer frames plus the 2-hour rain probability."""

from __future__ import annotations

from app.core.i18n import t
from app.engine.builders.base import CardContent, hhmm, num
from app.engine.context import Bundle, Context, UserProfile

ZOOM = 7
LITE_FRAMES = 3


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    radar = bundle.extras.get("radar") or {}
    frames = list(radar.get("frames") or [])
    if ctx.lite:
        frames = frames[-LITE_FRAMES:]
    prob = radar.get("rain_within_2h_prob_pct") or 0

    data = {
        "host": radar.get("host", ""),
        "frames": frames,
        "tile_template": radar.get("tile_template", ""),
        "center": {"lat": ctx.location.get("lat"), "lon": ctx.location.get("lon")},
        "zoom": ZOOM,
        "rain_within_2h_prob_pct": prob,
    }
    last = frames[-1]["time"] if frames else None
    return CardContent(
        data=data,
        subtitle=t(lang, "radar.frames", count=len(frames)),
        headline=t(lang, "insight.radar.headline", prob=num(prob)),
        detail=t(lang, "insight.radar.detail", time=hhmm(last)),
        icon="radar",
        source="rainviewer",
    )
