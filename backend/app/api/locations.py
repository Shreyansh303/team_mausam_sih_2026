"""GET /locations/search · /locations/reverse · /locations/popular (04)."""

from __future__ import annotations

from fastapi import APIRouter, Query

from app.schemas.location import LocationResult
from app.services import locations as loc_svc

router = APIRouter(prefix="/locations", tags=["locations"])


@router.get("/search", response_model=list[LocationResult])
async def search(
    q: str = Query(..., min_length=1, max_length=80),
    limit: int = Query(8, ge=1, le=25),
) -> list[LocationResult]:
    return await loc_svc.search(q, limit)


@router.get("/popular", response_model=list[LocationResult])
async def popular(limit: int = Query(48, ge=1, le=200)) -> list[LocationResult]:
    return loc_svc.popular(limit)


@router.get("/reverse", response_model=LocationResult)
async def reverse(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
) -> LocationResult:
    return await loc_svc.reverse(lat, lon)
