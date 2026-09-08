"""02 §3 nowcast — IMD nowcast when available, else derived from the next 3 hours."""

from __future__ import annotations

from app.core.i18n import resolve, t
from app.engine.builders.base import CardContent, hhmm
from app.engine.context import Bundle, Context, UserProfile

ICON = {"none": "cloud", "moderate": "rain", "severe": "thunderstorm"}


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    nc = bundle.snap.get("nowcast") or {}
    severity = nc.get("severity", "none")
    hazards = list(nc.get("hazards") or [])

    # `text_token` is the localizable form (05 §i18n); IMD text arrives already written.
    text = resolve(lang, nc.get("text_token")) if nc.get("text_token") else nc.get("text", "")

    data = {
        "issued_at": nc.get("issued_at"),
        "valid_till": nc.get("valid_till"),
        "text": text,
        "severity": severity,
        "hazards": hazards,
        "source": nc.get("source", "derived"),
    }
    hazard_text = ", ".join(t(lang, "hazard." + h) for h in hazards) if hazards else ""
    return CardContent(
        data=data,
        subtitle=hazard_text or t(lang, "nowcast.severity." + severity),
        headline=text,
        detail=t(lang, "insight.nowcast.detail", time=hhmm(nc.get("valid_till"))),
        icon=ICON.get(severity, "cloud"),
        source=nc.get("source", "derived"),
    )
