"""i18n completeness (05 §i18n): `hi` must carry every `en` key, and nothing may fall through.

`t()` returns the key itself when a lookup misses, so rendering a full `/home` in every
language and scanning the strings catches a builder that asks for a key nobody wrote.
"""

from __future__ import annotations

import re

import pytest

from app.core import i18n
from app.engine.catalog import CARD_TYPES, PERSONAS
from tests.conftest import DELHI, PANAJI

#: Anything shaped like `a.b.c` with no spaces is an unresolved i18n key leaking into a payload.
KEY_SHAPED = re.compile(r"^[a-z][a-z0-9_]*(\.[a-z0-9_+-]+){1,3}$")

NOW = "2026-09-08T07:30:00+05:30"


def test_hi_has_every_en_key():
    en = i18n.catalog("en")
    hi = i18n.catalog("hi")
    missing = sorted(set(en) - set(hi))
    assert not missing, f"hi.json is missing {len(missing)} keys: {missing[:20]}"


def test_hi_values_are_actually_hindi():
    """Guard against an `hi.json` that was copied from English."""
    en, hi = i18n.catalog("en"), i18n.catalog("hi")
    devanagari = re.compile(r"[ऀ-ॿ]")
    translated = [k for k in en if devanagari.search(hi.get(k, ""))]
    assert len(translated) > 0.85 * len(en), (
        f"only {len(translated)}/{len(en)} hi values contain Devanagari"
    )


def test_every_card_title_exists_in_en_and_hi():
    for card_type in CARD_TYPES:
        key = f"card.{card_type}.title"
        assert i18n.has("en", key), f"en is missing {key}"
        assert i18n.has("hi", key), f"hi is missing {key}"


def test_partial_languages_load_and_fall_back_per_key():
    for lang in ("mr", "ta", "bn"):
        catalog = i18n.catalog(lang)
        assert catalog, f"{lang}.json is empty"
        assert i18n.t(lang, "card.aqi.title") != "card.aqi.title"
        # a key that only `en` has must fall back rather than return the key
        assert i18n.t(lang, "insight.aqi.headline", category="Poor", aqi="210") == i18n.t(
            "en", "insight.aqi.headline", category="Poor", aqi="210"
        )


def test_unknown_language_falls_back_to_english():
    assert i18n.normalize_lang("de") == "en"
    assert i18n.normalize_lang("hi-IN") == "hi"
    assert i18n.t("de", "estimated") == i18n.t("en", "estimated")


def _leaked_keys(node, path="") -> list[str]:
    """Every string in the payload that still looks like an i18n key."""
    out: list[str] = []
    if isinstance(node, dict):
        for k, v in node.items():
            out += _leaked_keys(v, f"{path}.{k}")
    elif isinstance(node, list):
        for i, v in enumerate(node):
            out += _leaked_keys(v, f"{path}[{i}]")
    elif isinstance(node, str) and KEY_SHAPED.match(node):
        out.append(f"{path} = {node}")
    return out


#: Fields that legitimately hold enum-ish dotted-free tokens are skipped by shape, but a few
#: payload fields are free-text ids we must not flag.
ALLOWED_PATHS = (
    ".type", ".instance_id", ".renderer", ".icon", ".source", ".id", ".code", ".scenario",
    ".dominant_pollutant", ".hazard", ".severity", ".label", ".kind", ".status", ".verdict",
    ".impact", ".risk", ".trend", ".level", ".stage", ".season", ".zone", ".daypart",
)


@pytest.mark.parametrize("lang", ["en", "hi"])
@pytest.mark.parametrize("coords", [DELHI, PANAJI], ids=["delhi", "panaji"])
def test_no_i18n_key_leaks_into_a_rendered_home(client, guest, lang, coords):
    res = client.get(
        "/api/v1/home",
        params={
            "lat": coords[0],
            "lon": coords[1],
            "lang": lang,
            "personas": ",".join(PERSONAS[:3]),
            "now_override": NOW,
            "scenario": "clear_pleasant",
        },
        headers=guest["headers"],
    )
    assert res.status_code == 200, res.text
    body = res.json()

    leaks = [
        leak
        for leak in _leaked_keys(body)
        if not any(leak.split(" = ")[0].endswith(p) for p in ALLOWED_PATHS)
    ]
    assert not leaks, f"unresolved i18n keys in {lang}/{coords}: {leaks[:10]}"


def test_hindi_home_returns_hindi_titles(client, guest):
    res = client.get(
        "/api/v1/home",
        params={"lat": DELHI[0], "lon": DELHI[1], "lang": "hi", "now_override": NOW},
        headers=guest["headers"],
    )
    assert res.status_code == 200, res.text
    body = res.json()
    devanagari = re.compile(r"[ऀ-ॿ]")
    assert devanagari.search(body["hero"]["title"])
    assert body["context"]["lang"] == "hi"
    for card in body["cards"]:
        assert devanagari.search(card["title"]), card["type"]
