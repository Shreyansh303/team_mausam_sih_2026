"""Assemble the 04 `HomeResponse` from a Snapshot + the ranked catalog.

Pure: `api/home.py` does the I/O (snapshot, radar, saved-place snapshots) and hands the result
here as a `Bundle`. Everything below is deterministic for a given (bundle, context, profile).
"""

from __future__ import annotations

import logging
from typing import Any

from app.core.i18n import t
from app.core.timeutil import iso
from app.engine import ENGINE_VERSION
from app.engine.builders import BUILDERS
from app.engine.builders.base import CardContent
from app.engine.catalog import CardDef
from app.engine.context import Bundle, Context, UserProfile
from app.engine.explain import reasons_for
from app.engine.scoring import Ranking, Scored, rank
from app.schemas.card import Card, Insight, severity_for
from app.schemas.card import Action as CardAction
from app.schemas.home import Banner, EngineInfo, Freshness, HomeContext, HomeResponse, Sources
from app.schemas.location import LocationResult
from app.schemas.warning import SEVERITY_RANK, color_for

log = logging.getLogger("mausam.engine.home")

#: 04 §HomeResponse.banner — the highest active warning at orange or above.
BANNER_MIN_SEVERITY = 2


def _actions(definition: CardDef, scored: Scored, lang: str) -> list[CardAction]:
    ids = list(definition.actions)
    if scored.pinned_by_user:
        ids = ["unpin" if a == "pin" else a for a in ids]
    return [CardAction(id=a, label=t(lang, f"action.{a}")) for a in ids]


def _fallback_content(card_type: str, lang: str, exc: Exception) -> CardContent:
    log.warning("builder %s failed: %s", card_type, exc)
    return CardContent(
        data={},
        subtitle="",
        headline=t(lang, "card." + card_type + ".title"),
        detail="",
        icon="cloud",
        source="none",
    )


def build_card(
    scored: Scored, bundle: Bundle, ctx: Context, profile: UserProfile
) -> Card:
    definition = scored.card
    lang = ctx.lang
    builder = BUILDERS[definition.type]
    try:
        content = builder(bundle, ctx, profile)
    except Exception as exc:  # pragma: no cover - a broken builder must not 500 the home screen
        content = _fallback_content(definition.type, lang, exc)

    return Card(
        type=definition.type,
        instance_id=definition.type,
        title=t(lang, f"card.{definition.type}.title"),
        subtitle=content.subtitle,
        size=definition.size,  # type: ignore[arg-type]
        renderer=definition.renderer,
        urgency=round(scored.urgency, 3),
        severity=severity_for(scored.urgency),  # type: ignore[arg-type]
        pinned=scored.pinned,
        score=round(scored.score, 4),
        reasons=reasons_for(scored, ctx, profile),
        insight=Insight(
            headline=content.headline, detail=content.detail, icon=content.icon
        ),
        data=content.data,
        actions=_actions(definition, scored, lang),
        personas=list(definition.personas),
        source=content.source,
        estimated=content.estimated,
        updated_at=bundle.snap.get("fetched_at") or iso(ctx.now),
    )


def banner_for(ctx: Context) -> Banner | None:
    """04 — the highest active warning of orange severity or above, else `null`."""
    best: dict[str, Any] | None = None
    best_rank = 0
    for warning in ctx.active_warnings:
        r = SEVERITY_RANK.get(warning.get("severity", "yellow"), 0)
        if r >= BANNER_MIN_SEVERITY and r > best_rank:
            best, best_rank = warning, r
    if not best:
        return None
    return Banner(
        warning_id=str(best.get("id", "")),
        severity=str(best.get("severity", "orange")),
        title=str(best.get("title", "")),
        color_hex=str(best.get("color_hex") or color_for(str(best.get("severity", "orange")))),
    )


def _freshness(snap: dict[str, Any], ctx: Context) -> Freshness:
    fetched = snap.get("fetched_at") or iso(ctx.now)
    air = snap.get("air_quality") or {}
    marine = snap.get("marine") or {}
    warnings = ctx.active_warnings
    return Freshness(
        weather=fetched,
        air=air.get("time") or (fetched if air else None),
        marine=(marine.get("time") or fetched) if snap.get("marine") else None,
        warnings=(warnings[0].get("issued_at") if warnings else fetched),
    )


def _sources(snap: dict[str, Any]) -> Sources:
    src = snap.get("sources") or {}
    return Sources(
        weather=str(src.get("weather") or "open-meteo"),
        air=src.get("air"),
        marine=src.get("marine"),
        warnings=str(src.get("warnings") or "none"),
    )


def assemble(
    *,
    bundle: Bundle,
    ctx: Context,
    profile: UserProfile,
    location: LocationResult,
    ranking: Ranking | None = None,
) -> HomeResponse:
    """Rank the catalog, build every surviving card and wrap it in the 04 envelope."""
    ranked = ranking if ranking is not None else rank(bundle, ctx, profile)
    snap = bundle.snap

    def cards_of(items: list[Scored]) -> list[Card]:
        return [build_card(s, bundle, ctx, profile) for s in items]

    hero_scored = ranked.hero
    if hero_scored is None:  # pragma: no cover - current_conditions is never gated
        raise RuntimeError("current_conditions must always be present")

    home_context = HomeContext(
        now=iso(ctx.now),
        daypart=ctx.daypart,
        is_weekend=ctx.is_weekend,
        season=ctx.season,
        is_coastal=bool(location.is_coastal),
        scenario=ctx.scenario,
        active_personas=profile.persona_ids,
        warning_count=len(ctx.active_warnings),
        lang=ctx.lang,
    )

    return HomeResponse(
        generated_at=iso(ctx.now),
        location=location,
        context=home_context,
        banner=banner_for(ctx),
        pinned=cards_of(ranked.pinned),
        hero=build_card(hero_scored, bundle, ctx, profile),
        cards=cards_of(ranked.cards),
        more_cards=[] if ctx.lite else cards_of(ranked.more_cards),
        hidden_types=sorted(ranked.hidden_types),
        freshness=_freshness(snap, ctx),
        sources=_sources(snap),
        engine=EngineInfo(
            version=ENGINE_VERSION, weights={"relevance": 0.5, "urgency": 0.5}
        ),
    )
