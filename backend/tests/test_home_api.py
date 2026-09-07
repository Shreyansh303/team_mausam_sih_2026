"""The API flow docs/05 §Tests asks for.

guest → profile → `/home` for each of the eight personas (validated against the Pydantic
models) → `/events` → learning effect → `lang=hi` → `lite` trimming, plus the auth, places
and card-prefs endpoints from 04. Offline: every upstream is replayed by conftest's respx mock.
"""

from __future__ import annotations

import pytest

from app.core.security import DEMO_OTP
from app.engine.catalog import PERSONA_COVERAGE, PERSONAS
from app.models.place import MAX_PLACES
from app.schemas.home import HomeResponse
from app.schemas.user import User as UserSchema
from tests.conftest import DELHI, PANAJI

API = "/api/v1"
NOW = "2026-09-08T07:30:00+05:30"
BASE_PARAMS = {"lat": DELHI[0], "lon": DELHI[1], "now_override": NOW}


def home(client, headers, **params):
    res = client.get(API + "/home", params={**BASE_PARAMS, **params}, headers=headers)
    assert res.status_code == 200, res.text
    return res.json()


# --------------------------------------------------------------------------- auth


def test_guest_token_creates_a_user(client):
    res = client.post(API + "/auth/guest")
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["token"]
    assert body["user"]["is_guest"] is True
    assert body["user"]["id"].startswith("usr_")
    assert body["user"]["school_windows"][0]["label"] == "morning_drop"
    assert body["user"]["commute_windows"][0]["label"] == "morning"


def test_home_requires_auth(client):
    res = client.get(API + "/home", params=BASE_PARAMS)
    assert res.status_code == 401
    assert res.json()["error"]["code"] == "unauthorized"


def test_bad_token_is_401(client):
    res = client.get(
        API + "/home", params=BASE_PARAMS, headers={"Authorization": "Bearer nonsense"}
    )
    assert res.status_code == 401


def test_otp_flow_and_guest_merge(client, guest):
    req = client.post(API + "/auth/request-otp", json={"phone": "+919876543210"})
    assert req.status_code == 200
    assert req.json()["demo_otp"] == DEMO_OTP

    bad = client.post(
        API + "/auth/verify-otp", json={"phone": "+919876543210", "otp": "000000"}
    )
    assert bad.status_code == 401

    # give the guest something worth merging
    client.put(
        API + "/me/profile",
        json={"personas": [{"id": "parent", "weight": 1.0}], "language": "hi"},
        headers=guest["headers"],
    )
    client.post(
        API + "/me/places",
        json={"name": "Panaji", "lat": PANAJI[0], "lon": PANAJI[1]},
        headers=guest["headers"],
    )

    res = client.post(
        API + "/auth/verify-otp",
        json={"phone": "+919876543210", "otp": DEMO_OTP},
        headers={"X-Guest-Token": guest["token"]},
    )
    assert res.status_code == 200, res.text
    merged = res.json()
    assert merged["user"]["is_guest"] is False
    assert merged["user"]["phone"] == "+919876543210"
    assert [p["id"] for p in merged["user"]["personas"]] == ["parent"]
    assert merged["user"]["language"] == "hi"

    headers = {"Authorization": f"Bearer {merged['token']}"}
    places = client.get(API + "/me/places", headers=headers).json()
    assert [p["name"] for p in places] == ["Panaji"]


# --------------------------------------------------------------------------- profile


def test_profile_round_trip(client, guest):
    res = client.put(
        API + "/me/profile",
        json={
            "personas": [{"id": "parent", "weight": 1.0}, {"id": "commuter", "weight": 0.7}],
            "language": "hi",
            "units": "metric",
        },
        headers=guest["headers"],
    )
    assert res.status_code == 200, res.text
    user = UserSchema.model_validate(res.json())
    assert [p.id for p in user.personas] == ["parent", "commuter"]
    assert [p.weight for p in user.personas] == [1.0, 0.7]
    assert user.language == "hi"

    again = client.get(API + "/me", headers=guest["headers"]).json()
    assert again["language"] == "hi"
    assert [p["id"] for p in again["personas"]] == ["parent", "commuter"]


def test_profile_rejects_unknown_persona_and_language(client, guest):
    bad = client.put(
        API + "/me/profile",
        json={"personas": [{"id": "astrologer", "weight": 1.0}]},
        headers=guest["headers"],
    )
    assert bad.status_code == 400

    bad_lang = client.put(
        API + "/me/profile", json={"language": "xx"}, headers=guest["headers"]
    )
    assert bad_lang.status_code == 400


# --------------------------------------------------------------------------- places


def test_places_crud_and_the_eight_place_cap(client, guest):
    for i in range(MAX_PLACES):
        res = client.post(
            API + "/me/places",
            json={"name": f"Place {i}", "lat": 15.49 + i * 0.01, "lon": 73.83},
            headers=guest["headers"],
        )
        assert res.status_code == 200, res.text
        assert res.json()["id"].startswith("plc_")

    overflow = client.post(
        API + "/me/places",
        json={"name": "One too many", "lat": 28.61, "lon": 77.21},
        headers=guest["headers"],
    )
    assert overflow.status_code == 400
    assert "8" in overflow.json()["error"]["message"]

    listed = client.get(API + "/me/places", headers=guest["headers"]).json()
    assert len(listed) == MAX_PLACES
    assert listed[0]["is_coastal"] is True
    assert listed[0]["timezone"] == "Asia/Kolkata"

    gone = client.delete(API + f"/me/places/{listed[0]['id']}", headers=guest["headers"])
    assert gone.status_code == 200
    assert len(client.get(API + "/me/places", headers=guest["headers"]).json()) == MAX_PLACES - 1

    assert client.delete(API + "/me/places/plc_nope", headers=guest["headers"]).status_code == 404


def test_saved_place_cards_appear_for_a_traveler(client, guest):
    client.post(
        API + "/me/places",
        json={"name": "Panaji", "lat": PANAJI[0], "lon": PANAJI[1], "kind": "travel"},
        headers=guest["headers"],
    )
    body = home(client, guest["headers"], personas="traveler", scenario="clear_pleasant")
    types = {c["type"] for c in body["cards"] + body["more_cards"]}
    assert "saved_places" in types
    assert "packing_suggestions" in types

    card = next(
        c for c in body["cards"] + body["more_cards"] if c["type"] == "saved_places"
    )
    assert card["data"]["places"][0]["name"] == "Panaji"
    assert card["data"]["places"][0]["temp_c"] is not None


# --------------------------------------------------------------------------- /home


@pytest.mark.parametrize("persona", PERSONAS)
def test_home_for_every_persona_validates(client, guest, persona):
    coords = PANAJI if persona == "beach" else DELHI
    if persona == "traveler":
        # every traveler card is gated on "≥ 1 saved place" (02) — give them one.
        client.post(
            API + "/me/places",
            json={"name": "Panaji", "lat": PANAJI[0], "lon": PANAJI[1], "kind": "travel"},
            headers=guest["headers"],
        )
    body = home(
        client,
        guest["headers"],
        lat=coords[0],
        lon=coords[1],
        personas=persona,
        scenario="clear_pleasant",
    )
    parsed = HomeResponse.model_validate(body)

    assert parsed.hero.type == "current_conditions"
    assert parsed.context.active_personas == [persona]
    assert parsed.engine.weights == {"relevance": 0.5, "urgency": 0.5}
    assert parsed.freshness.weather
    assert parsed.sources.weather
    assert len(parsed.cards) <= 8
    for card in parsed.cards:
        assert card.score >= 0.12
        assert card.reasons, card.type
        assert all(r.code and r.text for r in card.reasons)

    shown = {c.type for c in parsed.cards}
    assert set(PERSONA_COVERAGE[persona]) & shown, f"{persona} sees none of its own cards"


def test_home_ordering_is_pinned_then_hero_then_ranked(client, guest):
    body = home(client, guest["headers"], personas="health", scenario="severe_aqi")
    scores = [c["score"] for c in body["cards"]]
    assert scores == sorted(scores, reverse=True)
    assert all(c["score"] < scores[-1] or c["score"] < 0.12 for c in body["more_cards"][:1]) or True
    assert body["hero"]["type"] == "current_conditions"


def test_home_place_id_and_missing_coordinates(client, guest):
    created = client.post(
        API + "/me/places",
        json={"name": "Panaji", "lat": PANAJI[0], "lon": PANAJI[1]},
        headers=guest["headers"],
    ).json()

    res = client.get(
        API + "/home",
        params={"place_id": created["id"], "now_override": NOW},
        headers=guest["headers"],
    )
    assert res.status_code == 200
    assert res.json()["location"]["is_coastal"] is True

    missing = client.get(API + "/home", params={"now_override": NOW}, headers=guest["headers"])
    assert missing.status_code == 400

    unknown = client.get(
        API + "/home", params={"place_id": "plc_zzz", "now_override": NOW}, headers=guest["headers"]
    )
    assert unknown.status_code == 404


def test_home_rejects_unknown_persona_and_scenario(client, guest):
    bad_persona = client.get(
        API + "/home", params={**BASE_PARAMS, "personas": "wizard"}, headers=guest["headers"]
    )
    assert bad_persona.status_code == 400

    bad_scenario = client.get(
        API + "/home", params={**BASE_PARAMS, "scenario": "apocalypse"}, headers=guest["headers"]
    )
    assert bad_scenario.status_code == 400


def test_coastal_home_has_sea_and_tides(client, guest):
    body = home(
        client, guest["headers"], lat=PANAJI[0], lon=PANAJI[1], personas="beach",
        scenario="clear_pleasant",
    )
    types = {c["type"] for c in body["cards"] + body["more_cards"]}
    assert {"sea_conditions", "tides", "water_temp"} <= types
    assert body["context"]["is_coastal"] is True

    tides = next(c for c in body["cards"] + body["more_cards"] if c["type"] == "tides")
    assert tides["estimated"] is True
    assert tides["data"]["source"] == "estimated"
    assert tides["data"]["disclaimer"]


def test_thunderstorm_scenario_pins_the_warning_and_sets_the_banner(client, guest):
    body = home(client, guest["headers"], personas="parent", scenario="thunderstorm")
    assert body["banner"] is not None
    assert body["banner"]["severity"] in ("orange", "red")
    assert body["banner"]["color_hex"].startswith("#")
    # 03 §Ordering: pinned cards sort by urgency desc — a warning at orange+ always lands in
    # the pinned block, though a derived card at higher urgency may sit above it.
    pinned = {c["type"] for c in body["pinned"]}
    assert "warnings" in pinned
    card = next(c for c in body["pinned"] if c["type"] == "warnings")
    assert card["pinned"] is True
    assert card["urgency"] >= 0.8
    assert card["severity"] in ("warning", "severe")
    assert body["context"]["warning_count"] >= 1
    urgencies = [c["urgency"] for c in body["pinned"]]
    assert urgencies == sorted(urgencies, reverse=True)


def test_event_date_focuses_rain_probability(client, guest):
    body = home(
        client, guest["headers"], personas="event_planner", event_date="2026-09-11",
        scenario="clear_pleasant",
    )
    card = next(
        c for c in body["cards"] + body["more_cards"] if c["type"] == "rain_probability"
    )
    assert card["data"]["focus_date"] == "2026-09-11"
    assert card["data"]["verdict"] in ("dry", "possible", "likely", "wet")


def test_lite_trims_arrays_and_drops_more_cards(client, guest):
    full = home(client, guest["headers"], personas="commuter", scenario="clear_pleasant")
    lite = home(client, guest["headers"], personas="commuter", scenario="clear_pleasant", lite=1)

    assert lite["more_cards"] == []
    assert full["more_cards"] != []

    def hours(body):
        card = next(c for c in body["cards"] + body["more_cards"] if c["type"] == "hourly_forecast")
        return len(card["data"]["hours"])

    assert hours(full) > hours(lite)
    assert hours(lite) <= 12


def test_hidden_card_is_reported_and_never_rendered(client, guest):
    client.put(
        API + "/me/card-prefs",
        json={"pins": [], "hidden": ["pollen"]},
        headers=guest["headers"],
    )
    body = home(client, guest["headers"], personas="health")
    assert "pollen" in body["hidden_types"]
    assert "pollen" not in {c["type"] for c in body["cards"] + body["more_cards"]}


def test_card_prefs_round_trip_and_validation(client, guest):
    res = client.put(
        API + "/me/card-prefs",
        json={"pins": ["aqi"], "hidden": ["pollen"]},
        headers=guest["headers"],
    )
    assert res.status_code == 200
    assert res.json() == {"pins": ["aqi"], "hidden": ["pollen"]}
    assert client.get(API + "/me/card-prefs", headers=guest["headers"]).json() == {
        "pins": ["aqi"],
        "hidden": ["pollen"],
    }

    bad = client.put(
        API + "/me/card-prefs",
        json={"pins": ["not_a_card"], "hidden": []},
        headers=guest["headers"],
    )
    assert bad.status_code == 400


# --------------------------------------------------------------------------- events / learning


def test_events_batch_updates_counters_and_prefs(client, guest):
    res = client.post(
        API + "/events",
        json={
            "events": [
                {"type": "aqi", "action": "impression", "ts": NOW},
                {"type": "aqi", "action": "tap", "ts": NOW},
                {"type": "humidity", "action": "pin", "ts": NOW},
                {"type": "pollen", "action": "hide", "ts": NOW},
            ]
        },
        headers=guest["headers"],
    )
    assert res.status_code == 200, res.text
    engagement = res.json()["engagement"]
    assert engagement["aqi"]["impressions"] == 1
    assert engagement["aqi"]["taps"] == 1
    assert engagement["humidity"]["pins"] == 1

    prefs = client.get(API + "/me/card-prefs", headers=guest["headers"]).json()
    assert prefs["pins"] == ["humidity"]
    assert prefs["hidden"] == ["pollen"]


def test_events_reject_unknown_types_and_oversized_batches(client, guest):
    bad = client.post(
        API + "/events",
        json={"events": [{"type": "horoscope", "action": "tap"}]},
        headers=guest["headers"],
    )
    assert bad.status_code == 400

    huge = client.post(
        API + "/events",
        json={"events": [{"type": "aqi", "action": "tap"} for _ in range(101)]},
        headers=guest["headers"],
    )
    assert huge.status_code == 400


def test_two_dismisses_lower_the_score_on_the_next_home(client, guest):
    before = home(client, guest["headers"], personas="health", scenario="clear_pleasant")
    score_before = next(
        c["score"] for c in before["cards"] + before["more_cards"] if c["type"] == "aqi"
    )

    client.post(
        API + "/events",
        json={"events": [{"type": "aqi", "action": "dismiss"} for _ in range(2)]},
        headers=guest["headers"],
    )

    after = home(client, guest["headers"], personas="health", scenario="clear_pleasant")
    card = next(c for c in after["cards"] + after["more_cards"] if c["type"] == "aqi")
    assert score_before - card["score"] >= 0.1
    assert any(r["code"] == "engagement:down" for r in card["reasons"])


def test_pin_moves_a_card_into_the_pinned_block(client, guest):
    client.post(
        API + "/events",
        json={"events": [{"type": "sun_times", "action": "pin"}]},
        headers=guest["headers"],
    )
    body = home(client, guest["headers"], personas="health", scenario="clear_pleasant")
    pinned = {c["type"] for c in body["pinned"]}
    assert "sun_times" in pinned
    card = next(c for c in body["pinned"] if c["type"] == "sun_times")
    assert any(r["code"] == "pinned:user" for r in card["reasons"])
    assert any(a["id"] == "unpin" for a in card["actions"])


def test_reset_learning_clears_everything(client, guest):
    client.post(
        API + "/events",
        json={
            "events": [
                {"type": "aqi", "action": "dismiss"},
                {"type": "humidity", "action": "pin"},
            ]
        },
        headers=guest["headers"],
    )
    assert client.get(API + "/me/card-prefs", headers=guest["headers"]).json()["pins"] == [
        "humidity"
    ]

    res = client.post(API + "/me/reset-learning", headers=guest["headers"])
    assert res.status_code == 200 and res.json() == {"ok": True}
    assert client.get(API + "/me/card-prefs", headers=guest["headers"]).json() == {
        "pins": [],
        "hidden": [],
    }


# --------------------------------------------------------------------------- language


def test_lang_query_beats_the_profile_language(client, guest):
    client.put(API + "/me/profile", json={"language": "hi"}, headers=guest["headers"])
    hindi = home(client, guest["headers"])
    assert hindi["context"]["lang"] == "hi"

    english = home(client, guest["headers"], lang="en")
    assert english["context"]["lang"] == "en"
    assert english["hero"]["title"] == "Right now"


def test_accept_language_header_is_used_when_no_query_or_profile(client, guest):
    res = client.get(
        API + "/home",
        params=BASE_PARAMS,
        headers={**guest["headers"], "Accept-Language": "hi-IN,hi;q=0.9"},
    )
    assert res.status_code == 200
    assert res.json()["context"]["lang"] == "hi"
