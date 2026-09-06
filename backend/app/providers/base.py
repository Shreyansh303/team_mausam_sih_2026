"""Provider protocol, `Result[source]` wrapper and the shared httpx fetcher.

Every provider call: httpx.AsyncClient, timeout HTTP_TIMEOUT_S, one retry on 5xx/timeouts,
cached by rounded (lat, lon) + kind with the TTLs from 01 (05 §Providers).
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Protocol

import httpx

from app.config import settings
from app.core.timeutil import UTC, iso

log = logging.getLogger("mausam.providers")

RETRY_STATUS = {500, 502, 503, 504, 429}


@dataclass(slots=True)
class Result:
    """A provider payload plus its provenance."""

    data: Any = None
    source: str = "unknown"
    ok: bool = True
    error: str | None = None
    fetched_at: str = field(default_factory=lambda: iso(datetime.now(UTC)))
    status: int | None = None

    @property
    def missing(self) -> bool:
        return self.data is None

    @staticmethod
    def fail(source: str, error: str, status: int | None = None) -> "Result":
        return Result(data=None, source=source, ok=False, error=error, status=status)


class Provider(Protocol):
    """Minimal provider protocol (05 §providers/base.py)."""

    name: str

    async def fetch(self, **kwargs: Any) -> Result:  # pragma: no cover - protocol
        ...


async def fetch_json(
    url: str,
    params: dict[str, Any] | None = None,
    *,
    source: str,
    timeout: float | None = None,
    retries: int = 1,
    headers: dict[str, str] | None = None,
    raise_for_status: bool = True,
) -> Result:
    """GET JSON with one retry on 5xx/timeouts. Never raises — returns a failed Result."""
    timeout = timeout if timeout is not None else settings.http_timeout_s
    attempt = 0
    last_err = "unknown"
    last_status: int | None = None
    while attempt <= retries:
        try:
            async with httpx.AsyncClient(
                timeout=timeout, headers=headers, follow_redirects=True
            ) as client:
                resp = await client.get(url, params=params)
            last_status = resp.status_code
            if resp.status_code in RETRY_STATUS and attempt < retries:
                attempt += 1
                continue
            if raise_for_status and resp.status_code >= 400:
                body = resp.text[:300]
                log.warning("%s %s -> HTTP %s %s", source, url, resp.status_code, body)
                return Result.fail(source, f"http_{resp.status_code}: {body}", resp.status_code)
            return Result(data=resp.json(), source=source, status=resp.status_code)
        except (httpx.TimeoutException, httpx.TransportError) as exc:
            last_err = f"{type(exc).__name__}: {exc}"
            attempt += 1
        except ValueError as exc:  # bad JSON
            return Result.fail(source, f"bad_json: {exc}", last_status)
    log.warning("%s %s failed: %s", source, url, last_err)
    return Result.fail(source, last_err, last_status)


def first_non_none(*values: Any) -> Any:
    for v in values:
        if v is not None:
            return v
    return None
