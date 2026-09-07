"""Card, Reason, Insight, Action (04 §Objects). Field names and enums are normative."""

from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field

Size = Literal["hero", "large", "medium", "small"]
Severity = Literal["info", "advisory", "watch", "warning", "severe"]

#: 02 §Card anatomy — severity from urgency.
SEVERITY_BANDS: tuple[tuple[float, str], ...] = (
    (0.3, "info"),
    (0.5, "advisory"),
    (0.7, "watch"),
    (0.85, "warning"),
)


def severity_for(urgency: float) -> str:
    for upper, name in SEVERITY_BANDS:
        if urgency < upper:
            return name
    return "severe"


class Reason(BaseModel):
    code: str
    text: str


class Insight(BaseModel):
    headline: str
    detail: str = ""
    icon: str = "cloud"


class Action(BaseModel):
    id: str
    label: str


class Card(BaseModel):
    type: str
    instance_id: str
    title: str
    subtitle: str = ""
    size: Size = "medium"
    renderer: str = "generic"
    urgency: float = 0.0
    severity: Severity = "info"
    pinned: bool = False
    score: float = 0.0
    reasons: list[Reason] = Field(default_factory=list)
    insight: Insight
    data: dict[str, Any] = Field(default_factory=dict)
    actions: list[Action] = Field(default_factory=list)
    personas: list[str] = Field(default_factory=list)
    source: str = "open-meteo"
    estimated: bool = False
    updated_at: str
