"""GET /me · PUT /me/profile · /me/card-prefs · POST /me/reset-learning (04)."""

from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.core.errors import ValidationError
from app.core.i18n import SUPPORTED
from app.core.security import current_user
from app.engine.catalog import CARD_TYPES
from app.models.user import User as UserModel
from app.schemas.user import CardPrefs, OkResponse, ProfileUpdate, User
from app.services import users as users_svc

router = APIRouter(prefix="/me", tags=["me"])


@router.get("", response_model=User)
async def me(user: UserModel = Depends(current_user)) -> User:
    return users_svc.to_schema(user)


@router.put("/profile", response_model=User)
async def update_profile(
    body: ProfileUpdate,
    user: UserModel = Depends(current_user),
    db: Session = Depends(get_db),
) -> User:
    data = body.model_dump(exclude_unset=True)

    if "personas" in data and data["personas"] is not None:
        user.personas = users_svc.normalize_personas([p["id"] for p in data["personas"]])
    if data.get("language"):
        lang = str(data["language"]).lower()
        if lang not in SUPPORTED:
            raise ValidationError(f"Unsupported language '{lang}'")
        user.language = lang
    if data.get("units"):
        if data["units"] not in ("metric", "imperial"):
            raise ValidationError("units must be 'metric' or 'imperial'")
        user.units = data["units"]
    if "home_location" in data:
        user.home_location = data["home_location"]
    if data.get("school_windows") is not None:
        user.school_windows = data["school_windows"]
    if data.get("commute_windows") is not None:
        user.commute_windows = data["commute_windows"]

    db.add(user)
    db.flush()
    return users_svc.to_schema(user)


@router.get("/card-prefs", response_model=CardPrefs)
async def get_card_prefs(
    user: UserModel = Depends(current_user), db: Session = Depends(get_db)
) -> CardPrefs:
    pins, hidden = users_svc.prefs_for(db, user.id)
    return CardPrefs(pins=sorted(pins), hidden=sorted(hidden))


@router.put("/card-prefs", response_model=CardPrefs)
async def put_card_prefs(
    body: CardPrefs,
    user: UserModel = Depends(current_user),
    db: Session = Depends(get_db),
) -> CardPrefs:
    unknown = [t for t in (*body.pins, *body.hidden) if t not in CARD_TYPES]
    if unknown:
        raise ValidationError(f"Unknown card type(s): {', '.join(sorted(set(unknown)))}")
    users_svc.set_prefs(db, user.id, pins=body.pins, hidden=body.hidden)
    return CardPrefs(pins=sorted(set(body.pins)), hidden=sorted(set(body.hidden)))


@router.post("/reset-learning", response_model=OkResponse)
async def reset_learning(
    user: UserModel = Depends(current_user), db: Session = Depends(get_db)
) -> OkResponse:
    users_svc.reset_learning(db, user.id)
    return OkResponse(ok=True)
