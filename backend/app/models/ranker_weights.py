"""Per-user weights for the v2 ML ranker (03 §Learning v2). One row per user.

The model is a small logistic regression over a sparse, named feature vector, so the weight
vector is stored as a JSON object `{feature_name: float}` rather than a blob — it can be read
straight out of SQLite with `select weights from ranker_weights`, which is what makes the
"how do I inspect what it learned" answer in `backend/README.md` a one-liner.

Nothing here is written unless `ENGINE_ML=1`; with the flag off the table simply stays empty
and `app/engine/scoring.py` runs the v1 formula exactly as before.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import JSON, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base
from app.core.timeutil import UTC


class RankerWeights(Base):
    __tablename__ = "ranker_weights"

    user_id: Mapped[str] = mapped_column(
        String(32), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    #: `{feature_name: weight}`, stored with sorted keys so the blob is stable to diff.
    weights: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict)
    #: Per-card-type state the feature extractor needs at prediction time — today just
    #: `{"<card_type>": {"last_ts": <epoch seconds>}}` for the recency feature.
    stats: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict)
    #: Labelled events the current weights were trained on (cold start below `MIN_EVENTS`).
    n_events: Mapped[int] = mapped_column(Integer, default=0)
    #: Bumped when the feature set changes so an old row is retrained, never mixed.
    version: Mapped[str] = mapped_column(String(16), default="")
    trained_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )
