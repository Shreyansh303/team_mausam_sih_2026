"""Flat-key i18n loader. `t(lang, key, **kw)` with per-key fallback to English (05 §i18n)."""

from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any

from app.config import settings

DEFAULT_LANG = "en"
SUPPORTED = ("en", "hi", "mr", "ta", "bn")


def _dir() -> Path:
    return settings.data_dir / "i18n"


@lru_cache(maxsize=16)
def catalog(lang: str) -> dict[str, str]:
    path = _dir() / f"{lang}.json"
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def available_languages() -> list[str]:
    return sorted(p.stem for p in _dir().glob("*.json"))


def normalize_lang(lang: str | None) -> str:
    if not lang:
        return DEFAULT_LANG
    code = lang.split(",")[0].split("-")[0].strip().lower()
    return code if code in SUPPORTED else DEFAULT_LANG


def t(lang: str | None, key: str, **kw: Any) -> str:
    """Translate `key`; falls back to English, then to the key itself."""
    code = normalize_lang(lang)
    value = catalog(code).get(key)
    if value is None and code != DEFAULT_LANG:
        value = catalog(DEFAULT_LANG).get(key)
    if value is None:
        return key
    if kw:
        try:
            return value.format(**kw)
        except (KeyError, IndexError, ValueError):
            return value
    return value


def has(lang: str, key: str) -> bool:
    return key in catalog(normalize_lang(lang))


def reload() -> None:
    catalog.cache_clear()
