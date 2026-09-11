"""POST /events (04 §Engagement events). Batch ≤ 100; pin/hide also update card-prefs."""

from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.config import settings
from app.core.db import get_db
from app.core.errors import ValidationError
from app.core.security import current_user
from app.engine import learning
from app.engine import ml as ml_ranker
from app.engine.catalog import CARD_TYPES
from app.models.user import User as UserModel
from app.schemas.events import MAX_BATCH, EventBatch, EventsResponse

router = APIRouter(tags=["events"])


@router.post("/events", response_model=EventsResponse)
async def post_events(
    body: EventBatch,
    user: UserModel = Depends(current_user),
    db: Session = Depends(get_db),
) -> EventsResponse:
    if len(body.events) > MAX_BATCH:
        raise ValidationError(f"At most {MAX_BATCH} events per batch")
    unknown = sorted({e.type for e in body.events if e.type not in CARD_TYPES})
    if unknown:
        raise ValidationError(f"Unknown card type(s): {', '.join(unknown)}")

    engagement = learning.apply_events(
        db, user_id=user.id, events=[e.model_dump() for e in body.events]
    )

    # Learning v2. Retraining is bounded (the last 300 events x 5 epochs of sparse SGD,
    # single-digit milliseconds), so it runs inline here rather than in a background task.
    # Never on the default path: with ENGINE_ML=0 the ranker_weights table stays empty.
    if settings.ml_on:
        ml_ranker.train_user(db, user.id)

    return EventsResponse(ok=True, engagement=engagement)
