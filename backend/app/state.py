"""Global demo state (scenario + demo clock). The admin console drives it."""

from __future__ import annotations

from dataclasses import dataclass, field

from app.config import settings


@dataclass
class DemoState:
    scenario: str = field(default_factory=lambda: settings.default_scenario)
    now_override: str | None = None

    def reset(self) -> None:
        self.scenario = settings.default_scenario
        self.now_override = None


demo_state = DemoState()
