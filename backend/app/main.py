"""FastAPI application factory (05 §Layout).

Routers are mounted twice: under `/api/v1` (the 04 contract base) and at the root, so the
verification URLs in 07 (`GET /weather/snapshot?...`) work with a bare curl too.
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app import __version__
from app.api import (
    admin,
    auth,
    devices,
    events,
    health,
    home,
    locations,
    me,
    places,
    weather,
    ws,
)
from app.config import BASE_DIR, settings
from app.core import cache
from app.core.db import init_db
from app.core.errors import install_error_handlers

API_PREFIX = "/api/v1"


def _configure_logging() -> None:
    logging.basicConfig(
        level=getattr(logging, settings.log_level.upper(), logging.INFO),
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )


@asynccontextmanager
async def lifespan(app: FastAPI):
    _configure_logging()
    init_db()
    logging.getLogger("mausam").info(
        "Mausam backend %s starting (demo_mode=%s, scenario=%s)",
        __version__, settings.demo_mode, settings.default_scenario,
    )
    yield
    cache.clear_all()


def create_app() -> FastAPI:
    app = FastAPI(
        title="Mausam Personalized — backend",
        version=__version__,
        description=(
            "Team Mausam prototype for SIH 2026 PS 26076. Not an official IMD service."
        ),
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    install_error_handlers(app)

    routers = (
        health.router,
        locations.router,
        weather.router,
        auth.router,
        me.router,
        places.router,
        devices.router,
        home.router,
        events.router,
        admin.router,
        ws.router,
    )
    for router in routers:
        app.include_router(router, prefix=API_PREFIX)
        app.include_router(router, include_in_schema=False)

    # 05 §Layout — the single-file demo console. `/admin/console` serves index.html; the mount
    # is here so any asset dropped next to it is reachable too.
    static_dir = BASE_DIR / "static"
    if static_dir.is_dir():
        app.mount("/static", StaticFiles(directory=static_dir), name="static")

    @app.get("/", include_in_schema=False)
    async def root() -> dict[str, str]:
        return {
            "name": "Mausam Personalized (Team Mausam prototype)",
            "version": __version__,
            "docs": "/docs",
            "api": API_PREFIX,
            "admin_console": "/admin/console",
            "ws": "/ws/alerts",
        }

    return app


app = create_app()
