"""GET/POST /me/places · DELETE /me/places/{id} (04). Max 8 places per user."""

from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.core.errors import NotFoundError, ValidationError
from app.core.geo import is_coastal, nearest_city
from app.core.security import current_user, new_place_id
from app.models.place import MAX_PLACES, Place as PlaceModel
from app.models.user import User as UserModel
from app.schemas.user import OkResponse, Place, PlaceCreate
from app.services import users as users_svc

router = APIRouter(prefix="/me/places", tags=["places"])


@router.get("", response_model=list[Place])
async def list_places(
    user: UserModel = Depends(current_user), db: Session = Depends(get_db)
) -> list[Place]:
    return [users_svc.place_to_schema(p) for p in users_svc.places_for(db, user.id)]


@router.post("", response_model=Place)
async def add_place(
    body: PlaceCreate,
    user: UserModel = Depends(current_user),
    db: Session = Depends(get_db),
) -> Place:
    existing = users_svc.places_for(db, user.id)
    if len(existing) >= MAX_PLACES:
        raise ValidationError(f"At most {MAX_PLACES} saved places")

    near, dist = nearest_city(body.lat, body.lon)
    tz = near["tz"] if near and dist <= 150 else "Asia/Kolkata"
    admin1 = body.admin1
    if not admin1 and near and dist <= 60:
        admin1 = near.get("admin1")
    place = PlaceModel(
        id=new_place_id(),
        user_id=user.id,
        name=body.name,
        lat=body.lat,
        lon=body.lon,
        country=body.country,
        country_code=body.country_code,
        admin1=admin1,
        admin2=body.admin2,
        kind=body.kind,
        timezone=tz,
        is_coastal=is_coastal(body.lat, body.lon),
    )
    db.add(place)
    db.flush()
    return users_svc.place_to_schema(place)


@router.delete("/{place_id}", response_model=OkResponse)
async def delete_place(
    place_id: str,
    user: UserModel = Depends(current_user),
    db: Session = Depends(get_db),
) -> OkResponse:
    place = db.get(PlaceModel, place_id)
    if place is None or place.user_id != user.id:
        raise NotFoundError(f"No saved place '{place_id}'")
    db.delete(place)
    db.flush()
    return OkResponse(ok=True)
