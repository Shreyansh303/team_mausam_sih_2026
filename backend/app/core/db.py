"""SQLAlchemy 2 engine, session factory and FastAPI dependency (05 §Layout).

Default store is SQLite at `backend/data/mausam.db`; `DATABASE_URL` overrides it. The engine is
built lazily so tests (and `scripts/gen_fixtures.py`) can point the app at a throwaway database
before the first query — call `configure(url)` / `reset_engine()` then `init_db()`.
"""

from __future__ import annotations

import logging
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

from sqlalchemy import create_engine, inspect
from sqlalchemy.engine import Engine, make_url
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.config import BACKEND_DIR, settings

log = logging.getLogger("mausam.db")


class Base(DeclarativeBase):
    """Declarative base for every model in `app/models/`."""


_engine: Engine | None = None
_session_factory: sessionmaker[Session] | None = None
_url_override: str | None = None


def current_url() -> str:
    return _url_override or settings.database_url


def resolve_url(url: str) -> str:
    """Make a relative SQLite path absolute against `backend/` so the CWD does not matter."""
    if not url.startswith("sqlite"):
        return url
    parsed = make_url(url)
    if not parsed.database or parsed.database == ":memory:":
        return url
    path = Path(parsed.database)
    if not path.is_absolute():
        path = (BACKEND_DIR / path).resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    return str(parsed.set(database=str(path)))


def configure(url: str | None) -> None:
    """Point the app at another database (tests, fixture generation). `None` restores config."""
    global _url_override
    _url_override = url
    reset_engine()


def reset_engine() -> None:
    global _engine, _session_factory
    if _engine is not None:
        _engine.dispose()
    _engine = None
    _session_factory = None


def get_engine() -> Engine:
    global _engine, _session_factory
    if _engine is None:
        url = resolve_url(current_url())
        kwargs: dict[str, object] = {"future": True, "echo": False}
        if url.startswith("sqlite"):
            kwargs["connect_args"] = {"check_same_thread": False}
            if ":memory:" in url or url.endswith("sqlite://"):
                kwargs["poolclass"] = StaticPool
        _engine = create_engine(url, **kwargs)  # type: ignore[arg-type]
        _session_factory = sessionmaker(bind=_engine, autoflush=False, expire_on_commit=False)
        log.debug("database engine created for %s", url)
    return _engine


def get_session_factory() -> sessionmaker[Session]:
    get_engine()
    assert _session_factory is not None
    return _session_factory


def _stale_tables(engine: Engine) -> list[str]:
    """Tables whose live columns no longer match the models (name set or nullability).

    There is no migration tool in this prototype: `create_all` leaves an existing table alone,
    so a database written by an older build silently keeps the old constraints and the next
    INSERT fails with a confusing 500. Detect that and say so.
    """
    inspector = inspect(engine)
    live = set(inspector.get_table_names())
    stale: list[str] = []
    for name, table in Base.metadata.tables.items():
        if name not in live:
            continue
        actual = {c["name"]: bool(c["nullable"]) for c in inspector.get_columns(name)}
        expected = {c.name: bool(c.nullable) for c in table.columns}
        if actual != expected:
            stale.append(name)
    return stale


def init_db(*, rebuild_stale: bool = True) -> None:
    """Create every table. Imports the model package so the metadata is populated.

    A table left over from an older schema is dropped and recreated (`rebuild_stale`). The
    store only holds demo/guest state, and a stale file is otherwise a hard 500 on first write.
    """
    import app.models  # noqa: F401  (registers the mappers)

    engine = get_engine()
    stale = _stale_tables(engine)
    if stale and rebuild_stale:
        log.warning(
            "schema changed since this database was written; recreating %s (demo data is lost)",
            ", ".join(sorted(stale)),
        )
        Base.metadata.drop_all(bind=engine, tables=[Base.metadata.tables[t] for t in stale])
    elif stale:
        raise RuntimeError(f"stale tables in {current_url()}: {', '.join(sorted(stale))}")

    Base.metadata.create_all(bind=engine)


def get_db() -> Iterator[Session]:
    """FastAPI dependency (sync generator → runs in the threadpool)."""
    session = get_session_factory()()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@contextmanager
def session_scope() -> Iterator[Session]:
    session = get_session_factory()()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()
