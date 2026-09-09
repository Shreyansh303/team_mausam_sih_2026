"""S1 · Learning v2 (docs/03 §"Learning (v2)"), the ML ranker behind `ENGINE_ML=1`.

The two invariants this file exists to defend:

* **v1 is the default and the fallback.** With the flag off `/home` is byte-identical to what
  it was before this phase, and the ML code path is never entered at all. With the flag on but
  nothing learned yet, the payload is byte-identical too (cold start).
* **The learned term is bounded.** It is clamped to ±0.1, it is never added to `urgency`, and
  it is only ever applied to a card that is not pinned — so a maximally favourable model
  cannot outrank an orange or red warning, nor pin a card that urgency did not pin.

Everything runs offline against the recorded fixtures (conftest).
"""

from __future__ import annotations

from datetime import datetime

import pytest
from sqlalchemy import select

from app.config import settings
from app.core import db as dbmod
from app.engine import ml
from app.engine import home as engine_home
from app.engine.catalog import CARD_TYPES, HERO_TYPE
from app.engine.context import Bundle, UserProfile, build_context
from app.engine.explain import LEARNING_MIN
from app.engine.ml import RankerModel
from app.engine.scoring import rank
from app.models.event import Event
from app.models.ranker_weights import RankerWeights
from app.schemas.location import LocationResult
from app.services import snapshot as snapshot_svc
from app.services import users as users_svc
from app.services import warnings as warnings_svc
from tests.conftest import DELHI

API = "/api/v1"
NOW_ISO = "2026-09-08T07:30:00+05:30"
NOW = datetime.fromisoformat(NOW_ISO)
SCENARIO = "clear_pleasant"
BASE_PARAMS = {"lat": DELHI[0], "lon": DELHI[1], "now_override": NOW_ISO, "scenario": SCENARIO}


@pytest.fixture
def ml_on(monkeypatch):
    """`ENGINE_ML=1` for the duration of one test."""
    monkeypatch.setattr(settings, "engine_ml", 1)
    yield


# --------------------------------------------------------------------------- helpers


async def make_bundle(coords=DELHI, *, scenario: str = SCENARIO, now: datetime = NOW):
    snap = await snapshot_svc.build_snapshot(*coords, scenario=scenario, now=now)
    payload = snap.model_dump()
    return Bundle(snap=payload, extras={"radar": None, "places": []}), payload


def make_context(payload, **kw):
    return build_context(
        now=NOW,
        location=payload["location"],
        active_warnings=payload.get("warnings") or [],
        scenario=SCENARIO,
        **kw,
    )


def maximal_model(p_one: bool = True) -> RankerModel:
    """A model that is maximally confident about every card type in the catalog.

    `bias` alone saturates the sigmoid, so `p_tap` is 1.0 (or 0.0) for everything and the
    learned term sits exactly on its bound. `stats` names every card type so the per-type
    cold start never kicks in — this is the strongest input the ranker can ever be handed.
    """
    magnitude = 50.0 if p_one else -50.0
    return RankerModel(
        weights={"bias": magnitude},
        stats={t: {"last_ts": NOW.timestamp()} for t in CARD_TYPES},
        n_events=10_000,
        version=ml.MODEL_VERSION,
    )


def red_warning(location: dict, severity: str = "red") -> dict:
    return warnings_svc.make_warning(
        severity=severity,
        hazard="cyclone",
        title=f"{severity.title()} warning: cyclone",
        description="Severe cyclonic storm approaching the coast.",
        now=NOW,
        district=location.get("admin2"),
        state=location.get("admin1"),
        lat=location.get("lat"),
        lon=location.get("lon"),
        source="scenario",
        valid_hours=6,
    )


def seed_events(db, user_id: str, pairs: list[tuple[str, str]], *, minute0: int = 0) -> None:
    """Write raw events straight into the log, the way `POST /events` would."""
    for i, (card_type, action) in enumerate(pairs):
        minute = (minute0 + i) % 60
        db.add(
            Event(
                user_id=user_id,
                card_type=card_type,
                action=action,
                ts=f"2026-09-08T07:{minute:02d}:00+05:30",
            )
        )
    db.flush()


def counters_after(db, user_id: str) -> dict[str, dict[str, int]]:
    return users_svc.engagement_for(db, user_id)


def p_tap_for(model: RankerModel, card_type: str, counters: dict) -> float:
    features = ml.feature_vector(
        card_type=card_type,
        daypart="dawn",
        season="monsoon",
        is_weekend=False,
        personas=[],
        persona_match=0.5,
        urgency=0.2,
        counters=counters.get(card_type),
        last_ts=model.last_ts(card_type),
        now_ts=NOW.timestamp(),
    )
    return model.predict(card_type, features)


# --------------------------------------------------------------------------- 1. flag off


def test_flag_off_home_is_byte_identical_and_never_reaches_the_ml_path(client, guest, monkeypatch):
    """`ENGINE_ML=0` (the default): the v1 payload, and `engine/ml.py` is not even called."""
    def explode(*a, **kw):  # pragma: no cover - the point is that it never runs
        raise AssertionError("engine.ml was reached with ENGINE_ML=0")

    monkeypatch.setattr(ml, "feature_vector", explode)
    monkeypatch.setattr(ml, "model_for", explode)
    monkeypatch.setattr(ml, "train_user", explode)

    events = {"events": [{"type": "aqi", "action": "tap"} for _ in range(12)]}
    assert client.post(API + "/events", json=events, headers=guest["headers"]).status_code == 200

    first = client.get(API + "/home", params=BASE_PARAMS, headers=guest["headers"])
    second = client.get(API + "/home", params=BASE_PARAMS, headers=guest["headers"])
    assert first.status_code == 200, first.text
    assert first.text == second.text

    for card in first.json()["cards"]:
        assert not any(r["code"].startswith("learning:") for r in card["reasons"])

    with dbmod.session_scope() as db:
        assert db.execute(select(RankerWeights)).scalars().all() == []


# --------------------------------------------------------------------------- 2. cold start


def test_flag_on_with_no_events_is_identical_to_v1(client, guest, monkeypatch):
    """Cold start: `p_tap` is the 0.5 prior, so the learned term is exactly zero."""
    baseline = client.get(API + "/home", params=BASE_PARAMS, headers=guest["headers"])
    assert baseline.status_code == 200, baseline.text

    monkeypatch.setattr(settings, "engine_ml", 1)
    with_ml = client.get(API + "/home", params=BASE_PARAMS, headers=guest["headers"])
    assert with_ml.status_code == 200, with_ml.text
    assert with_ml.text == baseline.text

    # Still identical below `MIN_EVENTS`: a handful of taps trains a row but the model is not
    # `ready`, so the screen is whatever v1 alone (engagement counters included) would render.
    few = {"events": [{"type": "aqi", "action": "tap"} for _ in range(ml.MIN_EVENTS - 1)]}
    assert client.post(API + "/events", json=few, headers=guest["headers"]).status_code == 200
    cold = client.get(API + "/home", params=BASE_PARAMS, headers=guest["headers"])
    monkeypatch.setattr(settings, "engine_ml", 0)
    v1_only = client.get(API + "/home", params=BASE_PARAMS, headers=guest["headers"])
    assert cold.status_code == 200, cold.text
    assert cold.text == v1_only.text
    assert "learning:" not in cold.text

    with dbmod.session_scope() as db:
        row = db.get(RankerWeights, guest["user"]["id"])
        assert row is not None and row.n_events < ml.MIN_EVENTS
        model = ml.model_for(db, guest["user"]["id"])
        assert model is not None and not model.ready
        assert model.p_tap({"bias": 1.0}) == ml.COLD_START_P


def test_an_untrained_card_type_stays_on_the_v1_score(client, guest, ml_on):
    """Per-type cold start: a card the user has never touched gets no learned term."""
    events = {"events": [{"type": "aqi", "action": "tap"} for _ in range(12)]}
    assert client.post(API + "/events", json=events, headers=guest["headers"]).status_code == 200

    with dbmod.session_scope() as db:
        model = ml.model_for(db, guest["user"]["id"])
        counters = counters_after(db, guest["user"]["id"])

    assert model is not None and model.ready
    assert model.seen("aqi") and not model.seen("wind")
    assert p_tap_for(model, "wind", counters) == ml.COLD_START_P
    assert model.adjustment("wind", {"bias": 1.0}) == 0.0


# --------------------------------------------------------------------------- 3. it learns


def test_taps_raise_p_tap_and_dismisses_lower_it(client, guest, ml_on):
    """Synthetic history: the tapped type goes up, the dismissed type goes down."""
    user_id = guest["user"]["id"]
    with dbmod.session_scope() as db:
        seed_events(db, user_id, [("aqi", "tap")] * 10 + [("humidity", "dismiss")] * 6)
        for card_type, action in [("aqi", "tap")] * 10 + [("humidity", "dismiss")] * 6:
            row = users_svc.engagement_row(db, user_id, card_type)
            counter = "taps" if action == "tap" else "dismisses"
            setattr(row, counter, int(getattr(row, counter) or 0) + 1)
        model = ml.train_user(db, user_id)
        counters = counters_after(db, user_id)

    assert model.ready, "16 events is above the cold-start floor"
    tapped = p_tap_for(model, "aqi", counters)
    dismissed = p_tap_for(model, "humidity", counters)
    unseen = p_tap_for(model, "wind", counters)

    assert tapped > 0.6, f"tapped card should be well above the prior, got {tapped}"
    assert dismissed < 0.4, f"dismissed card should be well below the prior, got {dismissed}"
    assert tapped > unseen == ml.COLD_START_P > dismissed


def test_the_learned_reason_reaches_the_home_payload(client, guest, ml_on):
    """The why sheet can show the ML contribution — 03 §Explainability, `learning:up`."""
    events = {"events": [{"type": "aqi", "action": "tap"} for _ in range(12)]}
    assert client.post(API + "/events", json=events, headers=guest["headers"]).status_code == 200

    body = client.get(API + "/home", params=BASE_PARAMS, headers=guest["headers"]).json()
    every = [*body["pinned"], *body["cards"], *body["more_cards"]]
    aqi = next(c for c in every if c["type"] == "aqi")
    learned = [r for r in aqi["reasons"] if r["code"] == "learning:up"]
    assert learned, f"no learning reason on aqi: {aqi['reasons']}"
    assert "+0." in learned[0]["text"], learned[0]["text"]
    assert not learned[0]["text"].startswith("reason."), "i18n key leaked instead of a string"

    # A card the model has never seen carries no learning reason at all.
    untouched = [c for c in every if c["type"] not in ("aqi", HERO_TYPE)]
    assert untouched
    for card in untouched:
        assert not any(r["code"].startswith("learning:") for r in card["reasons"]), card["type"]


def test_the_learned_reason_is_localized_in_hindi(client, guest, ml_on):
    events = {"events": [{"type": "aqi", "action": "tap"} for _ in range(12)]}
    client.post(API + "/events", json=events, headers=guest["headers"])

    body = client.get(
        API + "/home", params={**BASE_PARAMS, "lang": "hi"}, headers=guest["headers"]
    ).json()
    every = [*body["pinned"], *body["cards"], *body["more_cards"]]
    aqi = next(c for c in every if c["type"] == "aqi")
    learned = next(r for r in aqi["reasons"] if r["code"] == "learning:up")
    assert any("ऀ" <= ch <= "ॿ" for ch in learned["text"]), learned["text"]


# --------------------------------------------------------------------------- 4. the bound


async def test_a_maximal_learned_term_cannot_outrank_an_orange_or_red_warning():
    """The invariant docs/08 §Risks rests on: learning cannot bury a warning.

    The model here is the strongest one that can ever exist — `p_tap = 1.0` for every card
    type in the catalog. The warning must still be pinned, still be first, and no card the
    ranker learned to like may join it in the pinned block.
    """
    bundle, payload = await make_bundle()

    for severity in ("orange", "red"):
        ctx = make_context(payload)
        ctx.active_warnings = [red_warning(payload["location"], severity)]

        v1 = rank(bundle, ctx, UserProfile(personas=[("parent", 1.0)]))
        v2 = rank(
            bundle, ctx, UserProfile(personas=[("parent", 1.0)], ml=maximal_model())
        )

        assert v1.pinned and v1.pinned[0].type == "warnings"
        assert v2.pinned and v2.pinned[0].type == "warnings", severity
        # The learned term never changes who is pinned…
        assert {s.type for s in v2.pinned} == {s.type for s in v1.pinned}, severity
        # …and it is never added to a pinned card's score at all.
        for scored in v2.pinned:
            assert scored.ml == 0.0
            assert scored.p_tap is None

        warning = v2.pinned[0]
        assert warning.urgency >= 0.8, severity

        # Every learned card is bounded, and none of them reached the pinned block —
        # 03 §Ordering renders `pinned` before `cards`, so they are structurally below it.
        boosted = [s for s in v2.cards + v2.more_cards if s.ml != 0.0]
        assert boosted, "the maximal model should have moved something"
        for scored in boosted:
            assert scored.ml == pytest.approx(ml.ML_MAX)
            assert not scored.pinned
            assert scored.type not in {p.type for p in v2.pinned}

        # Urgency itself is untouched, so nothing can be pushed past the 0.8 pin threshold.
        v1_urgency = {s.type: s.urgency for s in v1.all_scored()}
        for scored in v2.all_scored():
            assert scored.urgency == v1_urgency[scored.type], severity


async def test_the_learned_term_is_clamped_in_both_directions():
    assert ml.clamp_adjustment(99.0) == ml.ML_MAX
    assert ml.clamp_adjustment(-99.0) == -ml.ML_MAX
    assert ml.ML_MAX == pytest.approx(ml.ML_WEIGHT * 0.5)

    hostile = maximal_model(p_one=False)
    assert hostile.adjustment("aqi", {"bias": 1.0}) == pytest.approx(-ml.ML_MAX)

    bundle, payload = await make_bundle()
    ctx = make_context(payload)
    ctx.active_warnings = [red_warning(payload["location"])]

    # A model that hates everything still cannot un-pin the warning: pinned cards skip the
    # learned term entirely, so the warning's score is the v1 score exactly.
    v1 = rank(bundle, ctx, UserProfile(personas=[("parent", 1.0)]))
    v2 = rank(bundle, ctx, UserProfile(personas=[("parent", 1.0)], ml=hostile))
    assert v2.pinned[0].type == "warnings"
    assert v2.pinned[0].score == v1.pinned[0].score
    for scored in v2.cards + v2.more_cards:
        assert scored.ml >= -ml.ML_MAX


async def test_the_maximal_term_never_reorders_across_the_pinned_block():
    """End to end through `assemble`: the warning card is in `pinned`, the learned ones aren't."""
    bundle, payload = await make_bundle()
    ctx = make_context(payload)
    ctx.active_warnings = [red_warning(payload["location"])]
    profile = UserProfile(personas=[("parent", 1.0)], ml=maximal_model())

    response = engine_home.assemble(
        bundle=bundle,
        ctx=ctx,
        profile=profile,
        location=LocationResult.model_validate(payload["location"]),
    )

    assert response.pinned[0].type == "warnings"
    assert response.pinned[0].pinned is True
    assert "warnings" not in {c.type for c in response.cards + response.more_cards}
    for card in response.pinned:
        assert not any(r.code.startswith("learning:") for r in card.reasons)


# --------------------------------------------------------------------------- 5. reset


def test_reset_learning_clears_the_v2_weights(client, guest, ml_on):
    user_id = guest["user"]["id"]
    events = {"events": [{"type": "aqi", "action": "tap"} for _ in range(12)]}
    assert client.post(API + "/events", json=events, headers=guest["headers"]).status_code == 200

    with dbmod.session_scope() as db:
        assert db.get(RankerWeights, user_id) is not None

    assert client.post(API + "/me/reset-learning", headers=guest["headers"]).status_code == 200

    with dbmod.session_scope() as db:
        assert db.get(RankerWeights, user_id) is None
        assert ml.model_for(db, user_id) is None

    body = client.get(API + "/home", params=BASE_PARAMS, headers=guest["headers"]).json()
    for card in [*body["pinned"], *body["cards"], *body["more_cards"]]:
        assert not any(r["code"].startswith("learning:") for r in card["reasons"])


def test_admin_reset_user_clears_the_v2_weights(client, guest, ml_on):
    user_id = guest["user"]["id"]
    client.post(
        API + "/events",
        json={"events": [{"type": "aqi", "action": "tap"} for _ in range(12)]},
        headers=guest["headers"],
    )
    res = client.post(
        API + "/admin/reset-user",
        json={"user_id": user_id},
        headers={"X-Admin-Key": settings.admin_key},
    )
    assert res.status_code == 200, res.text
    with dbmod.session_scope() as db:
        assert db.get(RankerWeights, user_id) is None


# --------------------------------------------------------------------------- 6. determinism


def test_same_events_produce_the_same_weights(client, ml_on):
    """No RNG anywhere: two identical logs train to the same weight vector."""
    pairs = [("aqi", "tap")] * 6 + [("humidity", "dismiss")] * 4 + [("wind", "impression")] * 5

    trained: list[dict] = []
    for _ in range(2):
        with dbmod.session_scope() as db:
            user = users_svc.create_guest(db)
            seed_events(db, user.id, pairs)
            model = ml.train_user(db, user.id)
            trained.append({"w": model.weights, "n": model.n_events})

    assert trained[0]["n"] == trained[1]["n"]
    assert trained[0]["w"] == trained[1]["w"]
    assert trained[0]["w"], "the model must actually have learned something"

    # And retraining the same user twice is a no-op on the weights.
    with dbmod.session_scope() as db:
        user = users_svc.create_guest(db)
        seed_events(db, user.id, pairs)
        first = ml.train_user(db, user.id).weights
        second = ml.train_user(db, user.id).weights
    assert first == second


def test_training_is_bounded_by_max_events(client, ml_on):
    """`POST /events` must stay cheap: training reads at most `MAX_EVENTS` rows."""
    with dbmod.session_scope() as db:
        user = users_svc.create_guest(db)
        seed_events(db, user.id, [("aqi", "impression")] * (ml.MAX_EVENTS + 40))
        model = ml.train_user(db, user.id)
    assert model.n_events == ml.MAX_EVENTS


# --------------------------------------------------------------------------- 7. reporting


def test_health_and_admin_state_report_the_flag(client, monkeypatch):
    off = client.get(API + "/health").json()
    assert off["engine"] == {"ml": False}

    admin = {"X-Admin-Key": settings.admin_key}
    assert client.get(API + "/admin/state", headers=admin).json()["engine_ml"] is False

    monkeypatch.setattr(settings, "engine_ml", 1)
    assert client.get(API + "/health").json()["engine"] == {"ml": True}
    assert client.get(API + "/admin/state", headers=admin).json()["engine_ml"] is True


def test_explain_threshold_is_below_the_bound():
    """A card sitting on the bound must always clear the why-sheet threshold."""
    assert LEARNING_MIN < ml.ML_MAX
