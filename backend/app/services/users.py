"""User/profile persistence helpers shared by the auth, me, places and home routers."""

from __future__ import annotations

from typing import Any

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.core.security import new_user_id
from app.core.timeutil import iso
from app.models.card_pref import CardPref
from app.models.engagement import Engagement
from app.models.event import Event
from app.models.place import Place
from app.models.ranker_weights import RankerWeights
from app.models.user import (
    DEFAULT_COMMUTE_WINDOWS,
    DEFAULT_SCHOOL_WINDOWS,
    User,
)
from app.schemas.user import Place as PlaceSchema
from app.schemas.user import User as UserSchema

#: Weights from 03 §Inputs — primary persona 1.0, the rest 0.7.
PRIMARY_WEIGHT = 1.0
SECONDARY_WEIGHT = 0.7


def normalize_personas(ids: list[str]) -> list[dict[str, Any]]:
    """`["parent","commuter"]` → `[{id:parent,weight:1.0},{id:commuter,weight:0.7}]` (max 3)."""
    out: list[dict[str, Any]] = []
    seen: set[str] = set()
    for pid in ids:
        pid = pid.strip()
        if not pid or pid in seen:
            continue
        seen.add(pid)
        out.append({"id": pid, "weight": PRIMARY_WEIGHT if not out else SECONDARY_WEIGHT})
        if len(out) >= 3:
            break
    return out


def create_guest(db: Session, *, language: str | None = None) -> User:
    user = User(
        id=new_user_id(),
        phone=None,
        is_guest=True,
        language=language,
        units="metric",
        personas=[],
        home_location=None,
        school_windows=list(DEFAULT_SCHOOL_WINDOWS),
        commute_windows=list(DEFAULT_COMMUTE_WINDOWS),
    )
    db.add(user)
    db.flush()
    return user


def by_phone(db: Session, phone: str) -> User | None:
    return db.execute(select(User).where(User.phone == phone)).scalar_one_or_none()


def to_schema(user: User) -> UserSchema:
    return UserSchema.model_validate(
        {
            "id": user.id,
            "phone": user.phone,
            "is_guest": bool(user.is_guest),
            "language": user.language or "en",
            "units": user.units or "metric",
            "personas": user.personas or [],
            "home_location": user.home_location,
            "school_windows": user.school_windows or list(DEFAULT_SCHOOL_WINDOWS),
            "commute_windows": user.commute_windows or list(DEFAULT_COMMUTE_WINDOWS),
            "created_at": iso(user.created_at),
        }
    )


def place_to_schema(place: Place) -> PlaceSchema:
    return PlaceSchema.model_validate(
        {
            "id": place.id,
            "name": place.name,
            "lat": place.lat,
            "lon": place.lon,
            "country": place.country,
            "country_code": place.country_code,
            "admin1": place.admin1,
            "admin2": place.admin2,
            "kind": place.kind,
            "timezone": place.timezone,
            "is_coastal": bool(place.is_coastal),
            "created_at": iso(place.created_at),
        }
    )


def places_for(db: Session, user_id: str) -> list[Place]:
    return list(
        db.execute(
            select(Place).where(Place.user_id == user_id).order_by(Place.created_at)
        ).scalars()
    )


def prefs_for(db: Session, user_id: str) -> tuple[set[str], set[str]]:
    """(pins, hidden) for a user."""
    rows = db.execute(select(CardPref).where(CardPref.user_id == user_id)).scalars()
    pins: set[str] = set()
    hidden: set[str] = set()
    for row in rows:
        if row.pinned:
            pins.add(row.card_type)
        if row.hidden:
            hidden.add(row.card_type)
    return pins, hidden


def set_prefs(db: Session, user_id: str, *, pins: list[str], hidden: list[str]) -> None:
    db.execute(delete(CardPref).where(CardPref.user_id == user_id))
    types = {*pins, *hidden}
    for card_type in sorted(types):
        db.add(
            CardPref(
                user_id=user_id,
                card_type=card_type,
                pinned=card_type in set(pins),
                hidden=card_type in set(hidden),
            )
        )
    db.flush()


def pref_row(db: Session, user_id: str, card_type: str) -> CardPref:
    row = db.get(CardPref, {"user_id": user_id, "card_type": card_type})
    if row is None:
        row = CardPref(user_id=user_id, card_type=card_type, pinned=False, hidden=False)
        db.add(row)
        db.flush()
    return row


def engagement_row(db: Session, user_id: str, card_type: str) -> Engagement:
    row = db.get(Engagement, {"user_id": user_id, "card_type": card_type})
    if row is None:
        row = Engagement(user_id=user_id, card_type=card_type)
        db.add(row)
        db.flush()
    return row


def engagement_for(db: Session, user_id: str) -> dict[str, dict[str, int]]:
    rows = db.execute(select(Engagement).where(Engagement.user_id == user_id)).scalars()
    return {row.card_type: row.as_dict() for row in rows}


def reset_learning(db: Session, user_id: str) -> None:
    """04 §POST /me/reset-learning — clears engagement, prefs, events and the v2 weights.

    The ML row has to go with the rest: leaving it behind would let a "forget what you know
    about me" tap keep silently re-ranking the feed from weights trained on the deleted log.
    """
    db.execute(delete(Engagement).where(Engagement.user_id == user_id))
    db.execute(delete(CardPref).where(CardPref.user_id == user_id))
    db.execute(delete(Event).where(Event.user_id == user_id))
    db.execute(delete(RankerWeights).where(RankerWeights.user_id == user_id))
    db.flush()


def merge_guest(db: Session, *, guest_id: str, target_id: str) -> None:
    """Move a guest's places, prefs, engagement and profile choices onto a phone account."""
    if guest_id == target_id:
        return
    guest = db.get(User, guest_id)
    target = db.get(User, target_id)
    if guest is None or target is None:
        return

    if not target.personas and guest.personas:
        target.personas = guest.personas
    if guest.home_location and not target.home_location:
        target.home_location = guest.home_location
    if guest.language and not target.language:
        target.language = guest.language
    if guest.school_windows:
        target.school_windows = guest.school_windows
    if guest.commute_windows:
        target.commute_windows = guest.commute_windows

    existing = {(p.lat, p.lon) for p in places_for(db, target_id)}
    for place in places_for(db, guest_id):
        if (place.lat, place.lon) in existing:
            db.delete(place)
            continue
        place.user_id = target_id

    for pref in db.execute(select(CardPref).where(CardPref.user_id == guest_id)).scalars():
        row = pref_row(db, target_id, pref.card_type)
        row.pinned = row.pinned or pref.pinned
        row.hidden = row.hidden or pref.hidden
        db.delete(pref)

    for eng in db.execute(select(Engagement).where(Engagement.user_id == guest_id)).scalars():
        row = engagement_row(db, target_id, eng.card_type)
        row.impressions += eng.impressions
        row.taps += eng.taps
        row.expands += eng.expands
        row.dismisses += eng.dismisses
        row.pins += eng.pins
        db.delete(eng)

    for ev in db.execute(select(Event).where(Event.user_id == guest_id)).scalars():
        ev.user_id = target_id

    # The guest's v2 weights are dropped rather than merged: they were fitted on the guest's
    # events alone, and those events have just moved onto the target account, so the next
    # `POST /events` retrains from the union anyway.
    db.execute(delete(RankerWeights).where(RankerWeights.user_id == guest_id))

    db.flush()
    db.delete(guest)
    db.flush()
