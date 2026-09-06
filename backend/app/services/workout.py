"""Best workout windows (02 §12).

Hourly score = 100 − penalties: temp >30 (−3/°C), <8 (−3/°C), humidity >75 (−1/%),
AQI >100 (−0.3/pt), UV >7 (−8/pt), rain prob >40 (−1/%), wind >30 (−1/kph), dark (−25).
Windows = runs of ≥ 60 min scoring ≥ 55; label Great ≥80 · Good ≥65 · Fair ≥55.
"""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from app.services.util import next_hours

THRESHOLD = 55
LABELS = ((80, "Great"), (65, "Good"), (55, "Fair"))


def hour_score(
    *,
    temp_c: float | None,
    humidity_pct: float | None,
    aqi: float | None,
    uv: float | None,
    precip_prob_pct: float | None,
    wind_kph: float | None,
    is_day: bool,
) -> int:
    score = 100.0
    if temp_c is not None:
        t = float(temp_c)
        if t > 30:
            score -= 3.0 * (t - 30)
        elif t < 8:
            score -= 3.0 * (8 - t)
    if humidity_pct is not None and float(humidity_pct) > 75:
        score -= 1.0 * (float(humidity_pct) - 75)
    if aqi is not None and float(aqi) > 100:
        score -= 0.3 * (float(aqi) - 100)
    if uv is not None and float(uv) > 7:
        score -= 8.0 * (float(uv) - 7)
    if precip_prob_pct is not None and float(precip_prob_pct) > 40:
        score -= 1.0 * (float(precip_prob_pct) - 40)
    if wind_kph is not None and float(wind_kph) > 30:
        score -= 1.0 * (float(wind_kph) - 30)
    if not is_day:
        score -= 25.0
    return int(round(max(0.0, min(100.0, score))))


def label_for(score: float) -> str | None:
    for threshold, name in LABELS:
        if score >= threshold:
            return name
    return None


def build(
    *,
    hourly: list[dict[str, Any]],
    now: datetime,
    aqi_by_hour: dict[str, float] | None = None,
    horizon_hours: int = 24,
    max_windows: int = 3,
) -> dict[str, Any]:
    aqi_by_hour = aqi_by_hour or {}
    rows = next_hours(hourly, now, horizon_hours)
    scores: list[dict[str, Any]] = []
    for h in rows:
        aqi = aqi_by_hour.get(h["time"])
        scores.append(
            {
                "time": h["time"],
                "score": hour_score(
                    temp_c=h.get("temp_c"),
                    humidity_pct=h.get("humidity_pct"),
                    aqi=aqi,
                    uv=h.get("uv_index"),
                    precip_prob_pct=h.get("precip_prob_pct"),
                    wind_kph=h.get("wind_kph"),
                    is_day=bool(h.get("is_day", True)),
                ),
                "temp_c": h.get("temp_c"),
                "aqi": None if aqi is None else int(round(aqi)),
                "uv": h.get("uv_index"),
                "humidity_pct": h.get("humidity_pct"),
            }
        )

    windows: list[dict[str, Any]] = []
    run: list[dict[str, Any]] = []

    def flush() -> None:
        if not run:
            return
        avg = sum(r["score"] for r in run) / len(run)
        start = run[0]["time"]
        last = datetime.fromisoformat(run[-1]["time"]) + timedelta(hours=1)
        windows.append(
            {
                "start": start,
                "end": last.isoformat(),
                "score": int(round(avg)),
                "temp_c": run[len(run) // 2].get("temp_c"),
                "aqi": run[len(run) // 2].get("aqi"),
                "uv": run[len(run) // 2].get("uv"),
                "humidity_pct": run[len(run) // 2].get("humidity_pct"),
                "label": label_for(avg) or "Fair",
            }
        )

    for row in scores:
        if row["score"] >= THRESHOLD:
            run.append(row)
        else:
            flush()
            run = []
    flush()

    windows.sort(key=lambda w: (-w["score"], w["start"]))
    top = windows[:max_windows]
    top_by_time = sorted(top, key=lambda w: w["start"])
    best = top[0] if top else None

    reason = None
    if not top:
        worst = max(scores, key=lambda s: s["score"], default=None)
        reason = (
            "No hour in the next 24 h scores above 55 — heat, humidity or air quality "
            "is limiting outdoor exercise."
            if worst
            else "Not enough forecast data to score workout windows."
        )

    return {
        "windows": top_by_time,
        "best": best,
        "hourly_scores": [{"time": s["time"], "score": s["score"]} for s in scores],
        "no_good_window_reason": reason,
        "urgency": 0.2 if best else 0.4,
    }
