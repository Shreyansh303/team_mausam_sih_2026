"""Engagement events (04 §POST /events)."""

from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field

Action = Literal["impression", "tap", "expand", "dismiss", "pin", "unpin", "hide", "unhide"]

MAX_BATCH = 100


class EventIn(BaseModel):
    type: str = Field(min_length=1, max_length=48)
    action: Action
    ts: str | None = None
    meta: dict[str, Any] | None = None


class EventBatch(BaseModel):
    events: list[EventIn] = Field(default_factory=list, max_length=MAX_BATCH)


class EventsResponse(BaseModel):
    ok: bool = True
    engagement: dict[str, dict[str, int]] = Field(default_factory=dict)
