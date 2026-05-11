# Module de Suivi & Réajustement du Plan
# Garmin Connect + Strava → Analyse → Ajustement automatique

## Vue d'ensemble

Ce module est déclenché **chaque semaine** (idéalement le dimanche soir ou lundi matin).
Il exécute 4 étapes en séquence :

1. **Collecte** — récupère les séances réalisées via Garmin Connect et/ou Strava
2. **Comparaison** — compare prévu vs réalisé (allure, FC, durée, complétion)
3. **Analyse fatigue** — lit les signaux de récupération Garmin (Body Battery, FC repos, sommeil)
4. **Réajustement** — adapte les semaines suivantes du plan selon 3 décisions possibles

---

## Dépendances

```bash
pip install garminconnect requests pandas --break-system-packages
```

---

## Étape 1 — Collecte des données

### 1A — Garmin Connect (prioritaire)

```python
import os
from garminconnect import Garmin
from datetime import date, timedelta

def connect_garmin(email: str, password: str) -> Garmin:
    """Connect and return authenticated Garmin client. Tokens cached in ~/.garminconnect/"""
    client = Garmin(email, password)
    client.login()
    return client

def get_week_activities_garmin(client: Garmin, week_start: date) -> list[dict]:
    """
    Fetch all running activities for a given week.
    Returns list of dicts with normalized fields.
    """
    week_end = week_start + timedelta(days=6)
    
    raw_activities = client.get_activities_by_date(
        week_start.isoformat(),
        week_end.isoformat(),
        activitytype="running"
    )
    
    activities = []
    for act in raw_activities:
        duration_min = round(act.get("duration", 0) / 60, 1)
        distance_km = round(act.get("distance", 0) / 1000, 2)
        avg_speed_ms = act.get("averageSpeed", 0)
        avg_pace_sec = round(1000 / avg_speed_ms) if avg_speed_ms > 0 else 0
        avg_pace_str = f"{avg_pace_sec // 60}:{avg_pace_sec % 60:02d}" if avg_pace_sec else "N/A"
        
        activities.append({
            "source": "garmin",
            "activity_id": act.get("activityId"),
            "date": act.get("startTimeLocal", "")[:10],
            "name": act.get("activityName", ""),
            "duration_min": duration_min,
            "distance_km": distance_km,
            "avg_pace": avg_pace_str,
            "avg_hr": act.get("averageHR"),
            "max_hr": act.get("maxHR"),
            "avg_cadence": act.get("averageRunningCadenceInStepsPerMinute"),
            "training_load": act.get("activityTrainingLoad"),
            "aerobic_te": act.get("aerobicTrainingEffect"),    # 0-5 scale
            "anaerobic_te": act.get("anaerobicTrainingEffect"), # 0-5 scale
        })
    
    return activities

def get_recovery_data_garmin(client: Garmin, week_start: date) -> dict:
    """
    Fetch recovery/wellness signals for the week.
    These are the key inputs for fatigue analysis.
    """
    recovery = {
        "resting_hr_by_day": {},
        "body_battery_by_day": {},
        "sleep_score_by_day": {},
        "stress_by_day": {},
        "training_readiness_by_day": {},
    }
    
    for i in range(7):
        day = week_start + timedelta(days=i)
        day_str = day.isoformat()
        
        try:
            # Resting heart rate
            hr_data = client.get_rhr_day(day_str)
            if hr_data:
                recovery["resting_hr_by_day"][day_str] = hr_data.get("allMetrics", {}).get(
                    "metricsMap", {}).get("WELLNESS_RESTING_HEART_RATE", [{}]
                )[0].get("value")
        except Exception:
            pass
        
        try:
            # Body Battery (start and end of day)
            bb_data = client.get_body_battery(day_str)
            if bb_data and len(bb_data) > 0:
                values = [x.get("charged", 0) for x in bb_data[0].get("bodyBatteryValuesArray", [])]
                recovery["body_battery_by_day"][day_str] = {
                    "morning": values[0] if values else None,
                    "evening": values[-1] if values else None,
                    "min": min(values) if values else None,
                }
        except Exception:
            pass
        
        try:
            # Sleep score
            sleep_data = client.get_sleep_data(day_str)
            if sleep_data:
                recovery["sleep_score_by_day"][day_str] = sleep_data.get(
                    "dailySleepDTO", {}).get("sleepScores", {}).get("overall", {}).get("value")
        except Exception:
            pass
        
        try:
            # Training readiness (0-100)
            readiness = client.get_training_readiness(day_str)
            if readiness and len(readiness) > 0:
                recovery["training_readiness_by_day"][day_str] = readiness[0].get("score")
        except Exception:
            pass
    
    return recovery


### 1B — Strava (complément ou alternative)

def get_week_activities_strava(access_token: str, week_start: date) -> list[dict]:
    """
    Fetch running activities for a given week from Strava API v3.
    
    How to get your access_token:
    1. Create an app at https://www.strava.com/settings/api
    2. Get client_id + client_secret
    3. Exchange for refresh_token via OAuth2 (one-time setup)
    4. Use refresh_token to get fresh access_token before each call (see below)
    """
    import requests
    
    week_end = week_start + timedelta(days=6)

    # Use epoch timestamps for filtering
    import datetime as dt
    after_ts = int(dt.datetime.combine(week_start, dt.time.min).timestamp())
    before_ts = int(dt.datetime.combine(week_end, dt.time.max).timestamp())
    
    url = "https://www.strava.com/api/v3/athlete/activities"
    headers = {"Authorization": f"Bearer {access_token}"}
    params = {"after": after_ts, "before": before_ts, "per_page": 50}
    
    response = requests.get(url, headers=headers, params=params)
    response.raise_for_status()
    
    activities = []
    for act in response.json():
        if act.get("type") not in ("Run", "VirtualRun", "TrailRun"):
            continue
        
        moving_time_s = act.get("moving_time", 0)
        avg_speed_ms = act.get("average_speed", 0)
        avg_pace_sec = round(1000 / avg_speed_ms) if avg_speed_ms > 0 else 0
        avg_pace_str = f"{avg_pace_sec // 60}:{avg_pace_sec % 60:02d}" if avg_pace_sec else "N/A"
        
        activities.append({
            "source": "strava",
            "activity_id": act.get("id"),
            "date": act.get("start_date_local", "")[:10],
            "name": act.get("name", ""),
            "duration_min": round(moving_time_s / 60, 1),
            "distance_km": round(act.get("distance", 0) / 1000, 2),
            "avg_pace": avg_pace_str,
            "avg_hr": act.get("average_heartrate"),
            "max_hr": act.get("max_heartrate"),
            "avg_cadence": act.get("average_cadence"),
            "suffer_score": act.get("suffer_score"),       # Strava-specific
            "pr_count": act.get("pr_count", 0),
        })
    
    return activities


def refresh_strava_token(client_id: str, client_secret: str, refresh_token: str) -> str:
    """Exchange refresh_token for a fresh access_token. Call before each Strava session."""
    import requests
    response = requests.post(
        "https://www.strava.com/oauth/token",
        data={
            "client_id": client_id,
            "client_secret": client_secret,
            "refresh_token": refresh_token,
            "grant_type": "refresh_token",
        }
    )
    response.raise_for_status()
    return response.json()["access_token"]
```

---

## Étape 2 — Comparaison Prévu vs Réalisé

```python
def pace_str_to_sec(pace_str: str) -> int:
    """'5:30' → 330 seconds"""
    if not pace_str or pace_str == "N/A":
        return 0
    parts = pace_str.split(":")
    return int(parts[0]) * 60 + int(parts[1])

def compare_week(planned_sessions: list[dict], actual_activities: list[dict]) -> list[dict]:
    """
    Match planned sessions to actual activities by date (±1 day tolerance).
    Returns a list of comparison dicts.
    
    planned_sessions: from the training plan (same format as in SKILL.md Step 4)
    actual_activities: from get_week_activities_garmin() or get_week_activities_strava()
    """
    comparisons = []
    
    running_planned = [s for s in planned_sessions if s.get("session_type") in
                       ("easy", "tempo", "intervals", "long_run")]
    
    for planned in running_planned:
        planned_date = planned["date"]
        
        # Find matching actual (same date ±1 day)
        match = None
        for act in actual_activities:
            act_date = act["date"]
            delta = abs((
                date.fromisoformat(act_date) - date.fromisoformat(str(planned_date))
            ).days)
            if delta <= 1:
                match = act
                break
        
        if match is None:
            comparisons.append({
                "planned": planned,
                "actual": None,
                "status": "missed",
                "pace_delta_sec": None,
                "duration_delta_pct": None,
                "hr_vs_zone": None,
            })
            continue
        
        # Compare pace
        planned_pace_str = planned.get("pace_target", "").split("-")[0].strip()
        planned_pace_sec = pace_str_to_sec(planned_pace_str)
        actual_pace_sec = pace_str_to_sec(match.get("avg_pace", ""))
        pace_delta = actual_pace_sec - planned_pace_sec  # positive = slower than target
        
        # Compare duration
        planned_dur = planned.get("duration_min", 0)
        actual_dur = match.get("duration_min", 0)
        duration_delta_pct = round((actual_dur - planned_dur) / planned_dur * 100, 1) if planned_dur else 0
        
        # HR vs zone (rough check)
        actual_hr = match.get("avg_hr")
        hr_zone = planned.get("hr_zone", "")
        hr_status = "unknown"
        if actual_hr and hr_zone:
            # Parse "XXX-XXX bpm" format if present
            import re
            m = re.search(r'(\d+)-(\d+)', hr_zone)
            if m:
                hr_low, hr_high = int(m.group(1)), int(m.group(2))
                if actual_hr < hr_low - 5:
                    hr_status = "too_low"
                elif actual_hr > hr_high + 5:
                    hr_status = "too_high"
                else:
                    hr_status = "on_target"
        
        comparisons.append({
            "planned": planned,
            "actual": match,
            "status": "completed",
            "pace_delta_sec": pace_delta,      # negative = faster, positive = slower
            "duration_delta_pct": duration_delta_pct,
            "hr_vs_zone": hr_status,
        })
    
    return comparisons
```

---

## Étape 3 — Analyse de la Fatigue

```python
def analyze_fatigue(
    comparisons: list[dict],
    recovery_data: dict,
    hr_max: int
) -> dict:
    """
    Synthesize all signals into a fatigue score and readjustment recommendation.
    
    Returns:
    {
        "fatigue_level": "low" | "moderate" | "high" | "overreached",
        "score": 0-100 (100 = fully recovered, 0 = overreached),
        "signals": [...],
        "recommendation": "increase" | "maintain" | "reduce" | "recovery_week",
        "zone_recalibration": None | {"direction": "faster"|"slower", "delta_sec": int}
    }
    """
    signals = []
    penalty = 0   # accumulates fatigue indicators (higher = more fatigued)
    bonus = 0     # accumulates recovery/positive indicators

    # ── Signal 1: Missed sessions ──────────────────────────────────────────────
    missed = sum(1 for c in comparisons if c["status"] == "missed")
    total = len(comparisons)
    completion_rate = (total - missed) / total if total > 0 else 1.0
    
    if completion_rate < 0.5:
        penalty += 30
        signals.append({"signal": "completion_rate", "value": completion_rate, "flag": "⚠️ Moins de 50% des séances réalisées"})
    elif completion_rate < 0.75:
        penalty += 15
        signals.append({"signal": "completion_rate", "value": completion_rate, "flag": "⚡ Quelques séances manquées"})
    else:
        bonus += 10
        signals.append({"signal": "completion_rate", "value": completion_rate, "flag": "✅ Bonne assiduité"})

    # ── Signal 2: Pace vs target ───────────────────────────────────────────────
    completed = [c for c in comparisons if c["status"] == "completed" and c["pace_delta_sec"] is not None]
    if completed:
        avg_pace_delta = sum(c["pace_delta_sec"] for c in completed) / len(completed)
        
        if avg_pace_delta > 20:  # consistently >20s/km slower than target
            penalty += 25
            signals.append({"signal": "pace", "value": avg_pace_delta, "flag": f"⚠️ Allure moyenne {avg_pace_delta:.0f}s/km plus lente que cible — possible fatigue ou zones mal calibrées"})
        elif avg_pace_delta > 10:
            penalty += 10
            signals.append({"signal": "pace", "value": avg_pace_delta, "flag": f"⚡ Allure légèrement en dessous de la cible (+{avg_pace_delta:.0f}s/km)"})
        elif avg_pace_delta < -15:  # consistently faster than target
            bonus += 15
            signals.append({"signal": "pace", "value": avg_pace_delta, "flag": f"🚀 Allures au-dessus des cibles ({abs(avg_pace_delta):.0f}s/km plus rapide) — zones peut-être à recalibrer"})
        else:
            bonus += 10
            signals.append({"signal": "pace", "value": avg_pace_delta, "flag": "✅ Allures dans les cibles"})
    
    # ── Signal 3: HR vs zones ──────────────────────────────────────────────────
    hr_high_count = sum(1 for c in completed if c.get("hr_vs_zone") == "too_high")
    if hr_high_count >= 2:
        penalty += 20
        signals.append({"signal": "hr_zones", "flag": f"⚠️ FC trop élevée sur {hr_high_count} séances — signe de fatigue accumulée ou zones sous-estimées"})
    
    # ── Signal 4: Resting HR trend (Garmin) ───────────────────────────────────
    rhr_values = [v for v in recovery_data.get("resting_hr_by_day", {}).values() if v]
    if len(rhr_values) >= 3:
        rhr_trend = rhr_values[-1] - rhr_values[0]  # positive = increasing over week
        if rhr_trend >= 5:
            penalty += 20
            signals.append({"signal": "resting_hr", "value": rhr_trend, "flag": f"⚠️ FC repos en hausse de {rhr_trend:.0f} bpm sur la semaine — signe de surmenage"})
        elif rhr_trend <= -3:
            bonus += 10
            signals.append({"signal": "resting_hr", "value": rhr_trend, "flag": f"✅ FC repos en baisse ({abs(rhr_trend):.0f} bpm) — bonne récupération"})
    
    # ── Signal 5: Body Battery (Garmin) ───────────────────────────────────────
    bb_mornings = [v["morning"] for v in recovery_data.get("body_battery_by_day", {}).values()
                   if v and v.get("morning")]
    if bb_mornings:
        avg_bb = sum(bb_mornings) / len(bb_mornings)
        if avg_bb < 40:
            penalty += 25
            signals.append({"signal": "body_battery", "value": avg_bb, "flag": f"⚠️ Body Battery moyen au réveil : {avg_bb:.0f}/100 — récupération insuffisante"})
        elif avg_bb < 60:
            penalty += 10
            signals.append({"signal": "body_battery", "value": avg_bb, "flag": f"⚡ Body Battery moyen : {avg_bb:.0f}/100 — récupération partielle"})
        else:
            bonus += 15
            signals.append({"signal": "body_battery", "value": avg_bb, "flag": f"✅ Body Battery moyen : {avg_bb:.0f}/100 — bien récupéré"})
    
    # ── Signal 6: Sleep score (Garmin) ────────────────────────────────────────
    sleep_scores = [v for v in recovery_data.get("sleep_score_by_day", {}).values() if v]
    if sleep_scores:
        avg_sleep = sum(sleep_scores) / len(sleep_scores)
        if avg_sleep < 60:
            penalty += 15
            signals.append({"signal": "sleep", "value": avg_sleep, "flag": f"⚠️ Score de sommeil moyen : {avg_sleep:.0f}/100 — sommeil insuffisant"})
        elif avg_sleep >= 80:
            bonus += 10
            signals.append({"signal": "sleep", "value": avg_sleep, "flag": f"✅ Bon sommeil : {avg_sleep:.0f}/100"})
    
    # ── Training readiness (Garmin) ───────────────────────────────────────────
    readiness_scores = [v for v in recovery_data.get("training_readiness_by_day", {}).values() if v]
    if readiness_scores:
        avg_readiness = sum(readiness_scores) / len(readiness_scores)
        if avg_readiness < 40:
            penalty += 20
            signals.append({"signal": "training_readiness", "value": avg_readiness, "flag": f"⚠️ Training Readiness Garmin faible : {avg_readiness:.0f}/100"})
        elif avg_readiness >= 70:
            bonus += 15
            signals.append({"signal": "training_readiness", "value": avg_readiness, "flag": f"✅ Training Readiness : {avg_readiness:.0f}/100 — prêt à charger"})
    
    # ── Final score ───────────────────────────────────────────────────────────
    score = max(0, min(100, 50 - penalty + bonus))
    
    if score >= 75:
        fatigue_level = "low"
        recommendation = "increase"
    elif score >= 50:
        fatigue_level = "moderate"
        recommendation = "maintain"
    elif score >= 30:
        fatigue_level = "high"
        recommendation = "reduce"
    else:
        fatigue_level = "overreached"
        recommendation = "recovery_week"
    
    # Zone recalibration suggestion
    zone_recalibration = None
    pace_deltas = [c["pace_delta_sec"] for c in completed if c.get("pace_delta_sec") is not None]
    if len(pace_deltas) >= 3:
        avg_delta = sum(pace_deltas) / len(pace_deltas)
        if avg_delta > 15:  # consistently slower → zones too ambitious
            zone_recalibration = {"direction": "slower", "delta_sec": round(avg_delta)}
        elif avg_delta < -15:  # consistently faster → zones too conservative
            zone_recalibration = {"direction": "faster", "delta_sec": round(abs(avg_delta))}
    
    return {
        "fatigue_level": fatigue_level,
        "score": score,
        "signals": signals,
        "recommendation": recommendation,
        "zone_recalibration": zone_recalibration,
        "completion_rate": completion_rate,
    }
```

---

## Étape 4 — Réajustement du Plan

```python
def readjust_plan(
    remaining_weeks: list[list[dict]],  # list of weekly session lists
    fatigue_analysis: dict,
    current_week_number: int,
    total_weeks: int,
) -> list[list[dict]]:
    """
    Modify the remaining weeks of the plan based on fatigue analysis.
    Returns modified remaining_weeks.
    
    Decisions:
    - "increase": add volume/intensity to next week (+10%)
    - "maintain": keep plan as-is
    - "reduce": reduce next week's volume by 20%, remove one quality session
    - "recovery_week": insert a full recovery week (replace next week)
    """
    recommendation = fatigue_analysis["recommendation"]
    zone_recal = fatigue_analysis.get("zone_recalibration")
    
    if not remaining_weeks:
        return remaining_weeks
    
    next_week = remaining_weeks[0]
    
    if recommendation == "increase":
        # Add 10% to easy/long run durations
        for session in next_week:
            if session.get("session_type") in ("easy", "long_run"):
                session["duration_min"] = round(session["duration_min"] * 1.10)
                session["distance_km"] = round(session.get("distance_km", 0) * 1.10, 1)
                session["notes"] = (session.get("notes", "") + 
                                    " [+10% volume: bonne progression cette semaine]").strip()
    
    elif recommendation == "reduce":
        # Reduce easy runs by 20%, downgrade one quality session to easy
        quality_sessions = [s for s in next_week if s.get("session_type") in ("tempo", "intervals")]
        if quality_sessions:
            # Downgrade the last quality session of the week to easy
            last_quality = quality_sessions[-1]
            last_quality["session_type"] = "easy"
            last_quality["duration_min"] = min(last_quality["duration_min"], 40)
            last_quality["distance_km"] = round(last_quality["duration_min"] / 6, 1)
            last_quality["title"] = "Sortie facile (récupération)"
            last_quality["zones"] = "Z1-Z2"
            last_quality["notes"] = "⚠️ Séance allégée cette semaine — signaux de fatigue détectés. Priorité à la récupération."
        
        for session in next_week:
            if session.get("session_type") == "easy":
                session["duration_min"] = round(session["duration_min"] * 0.80)
                session["distance_km"] = round(session.get("distance_km", 0) * 0.80, 1)
    
    elif recommendation == "recovery_week":
        # Replace all quality sessions with easy runs, reduce volume by 40%
        for session in next_week:
            if session.get("session_type") in ("tempo", "intervals"):
                session["session_type"] = "easy"
                session["duration_min"] = 30
                session["distance_km"] = 5.0
                session["title"] = "Sortie légère (semaine de récup)"
                session["zones"] = "Z1"
                session["notes"] = "🔴 SEMAINE DE RÉCUPÉRATION — Signaux de surmenage détectés. Sortie très facile, RPE max 4/10."
            elif session.get("session_type") in ("easy", "long_run"):
                session["duration_min"] = round(session["duration_min"] * 0.60)
                session["distance_km"] = round(session.get("distance_km", 0) * 0.60, 1)
                session["notes"] = "Allure très facile. Ne pas forcer."
    
    # Apply zone recalibration to all remaining weeks if needed
    if zone_recal:
        delta = zone_recal["delta_sec"]
        direction = zone_recal["direction"]
        sign = 1 if direction == "slower" else -1
        
        for week in remaining_weeks:
            for session in week:
                current_pace = session.get("pace_target", "")
                if current_pace and "-" in current_pace:
                    parts = current_pace.split("/km")[0].strip().split("-")
                    try:
                        new_parts = []
                        for p in parts:
                            p_sec = pace_str_to_sec(p.strip())
                            new_sec = p_sec + (sign * delta // 2)  # apply half the delta
                            new_parts.append(f"{new_sec//60}:{new_sec%60:02d}")
                        session["pace_target"] = " - ".join(new_parts) + " /km"
                    except Exception:
                        pass
    
    return remaining_weeks
```

---

## Étape 5 — Rapport Hebdomadaire

```python
def generate_weekly_report(
    week_number: int,
    comparisons: list[dict],
    fatigue_analysis: dict,
    next_week_sessions: list[dict],
) -> str:
    """Generate a clear, coach-style weekly report to present to the user."""
    
    fa = fatigue_analysis
    level_emoji = {"low": "🟢", "moderate": "🟡", "high": "🟠", "overreached": "🔴"}
    reco_text = {
        "increase": "📈 Semaine prochaine : on monte en charge (+10% volume)",
        "maintain": "➡️ Semaine prochaine : on maintient le plan initial",
        "reduce": "📉 Semaine prochaine : charge réduite — une séance qualité convertie en facile",
        "recovery_week": "🛑 Semaine prochaine : SEMAINE DE RÉCUPÉRATION COMPLÈTE",
    }
    
    lines = [
        f"═══════════════════════════════════════",
        f"📊 BILAN SEMAINE {week_number}",
        f"═══════════════════════════════════════",
        f"",
        f"🏃 SÉANCES RÉALISÉES",
    ]
    
    for c in comparisons:
        p = c["planned"]
        if c["status"] == "missed":
            lines.append(f"  ❌ {p.get('date')} — {p.get('title','?')} — NON RÉALISÉE")
        else:
            a = c["actual"]
            pace_info = ""
            if c["pace_delta_sec"] is not None:
                delta = c["pace_delta_sec"]
                pace_info = f" | Allure : {a.get('avg_pace','?')}/km"
                if abs(delta) > 10:
                    pace_info += f" ({'⬆️ +' if delta > 0 else '⬇️ '}{abs(delta)}s vs cible)"
            lines.append(f"  ✅ {p.get('date')} — {p.get('title','?')}"
                         f" | {a.get('duration_min','?')}min{pace_info}"
                         f" | FC moy: {a.get('avg_hr','?')} bpm")
    
    lines += [
        f"",
        f"📈 ANALYSE DE FORME",
        f"  Niveau de fatigue : {level_emoji.get(fa['fatigue_level'], '?')} {fa['fatigue_level'].upper()}",
        f"  Score récupération : {fa['score']}/100",
        f"",
        f"  Signaux détectés :",
    ]
    
    for sig in fa["signals"]:
        lines.append(f"  {sig['flag']}")
    
    if fa.get("zone_recalibration"):
        zr = fa["zone_recalibration"]
        lines.append(f"")
        lines.append(f"  🎯 Recalibration des zones suggérée : allures {zr['direction']} de ~{zr['delta_sec']}s/km")
    
    lines += [
        f"",
        f"🗓 DÉCISION POUR LA SEMAINE PROCHAINE",
        f"  {reco_text.get(fa['recommendation'], '')}",
        f"",
        f"  Sessions ajustées :",
    ]
    
    for s in next_week_sessions:
        if s.get("session_type") not in ("rest",):
            lines.append(f"  • {s.get('date','')} — {s.get('title','?')} — {s.get('duration_min','?')}min — {s.get('zones','?')}")
    
    lines.append(f"═══════════════════════════════════════")
    
    return "\n".join(lines)
```

---

## Orchestrateur principal (script hebdomadaire complet)

```python
def run_weekly_review(
    plan_sessions: list[dict],           # full plan session list
    current_week_number: int,
    garmin_email: str = None,
    garmin_password: str = None,
    strava_client_id: str = None,
    strava_client_secret: str = None,
    strava_refresh_token: str = None,
    hr_max: int = 185,
) -> dict:
    """
    Full weekly review pipeline.
    Call this every Sunday evening or Monday morning.
    
    Returns dict with:
    - report: str (formatted text report)
    - adjusted_remaining_plan: list of remaining weekly session lists
    - fatigue_analysis: full analysis dict
    """
    from datetime import date, timedelta
    
    # Find the start (Monday) of the week just completed
    # If today is Sunday (weekday=6), the completed week started last Monday (6 days ago)
    # If today is Monday (weekday=0), the completed week started 7 days ago
    today = date.today()
    days_since_monday = today.weekday()  # Monday=0, Sunday=6
    if days_since_monday == 0:
        # It's Monday — review the week that ended yesterday (Sunday)
        week_start = today - timedelta(days=7)
    else:
        # Any other day — review the week starting from last Monday
        week_start = today - timedelta(days=days_since_monday)
    
    # Get planned sessions for completed week
    planned_this_week = [
        s for s in plan_sessions
        if week_start <= date.fromisoformat(str(s["date"])) <= week_start + timedelta(days=6)
    ]
    
    # Get remaining weeks (future)
    all_future = [s for s in plan_sessions if date.fromisoformat(str(s["date"])) > today]
    # Group by week
    from itertools import groupby
    def week_key(s):
        d = date.fromisoformat(str(s["date"]))
        return d - timedelta(days=d.weekday())
    remaining_weeks = [list(g) for _, g in groupby(sorted(all_future, key=lambda s: s["date"]), key=week_key)]
    
    # Collect actual activities
    actual_activities = []
    recovery_data = {"resting_hr_by_day": {}, "body_battery_by_day": {}, 
                     "sleep_score_by_day": {}, "training_readiness_by_day": {}}
    
    if garmin_email and garmin_password:
        try:
            garmin_client = connect_garmin(garmin_email, garmin_password)
            actual_activities += get_week_activities_garmin(garmin_client, week_start)
            recovery_data = get_recovery_data_garmin(garmin_client, week_start)
        except Exception as e:
            print(f"⚠️ Garmin Connect error: {e}")
    
    if strava_refresh_token:
        try:
            token = refresh_strava_token(strava_client_id, strava_client_secret, strava_refresh_token)
            strava_acts = get_week_activities_strava(token, week_start)
            # Merge: keep Garmin if same date, otherwise add Strava
            garmin_dates = {a["date"] for a in actual_activities}
            actual_activities += [a for a in strava_acts if a["date"] not in garmin_dates]
        except Exception as e:
            print(f"⚠️ Strava error: {e}")
    
    # Compare
    comparisons = compare_week(planned_this_week, actual_activities)
    
    # Analyze fatigue
    fatigue = analyze_fatigue(comparisons, recovery_data, hr_max)
    
    # Readjust remaining plan
    adjusted_remaining = readjust_plan(remaining_weeks, fatigue, current_week_number, 
                                       len(set(s.get("week") for s in plan_sessions)))
    
    # Flatten adjusted plan back
    adjusted_sessions = [s for week in adjusted_remaining for s in week]
    
    # Generate report
    next_week = adjusted_remaining[0] if adjusted_remaining else []
    report = generate_weekly_report(current_week_number, comparisons, fatigue, next_week)
    
    return {
        "report": report,
        "adjusted_remaining_sessions": adjusted_sessions,
        "fatigue_analysis": fatigue,
        "comparisons": comparisons,
    }
```

---

## CSV de suivi (sauvegarde persistante)

```python
import csv

TRACKING_CSV_COLUMNS = [
    "week", "date", "planned_type", "planned_duration_min", "planned_pace_target",
    "planned_zones", "status", "actual_duration_min", "actual_distance_km",
    "actual_avg_pace", "actual_avg_hr", "pace_delta_sec", "hr_vs_zone",
    "body_battery_morning", "resting_hr", "sleep_score", "training_readiness",
    "fatigue_level", "fatigue_score", "recommendation", "notes"
]

def append_week_to_csv(csv_path: str, week_number: int, comparisons: list[dict],
                       fatigue_analysis: dict, recovery_data: dict):
    """Append completed week data to the tracking CSV."""
    import os
    write_header = not os.path.exists(csv_path)
    
    with open(csv_path, "a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=TRACKING_CSV_COLUMNS, extrasaction="ignore")
        if write_header:
            writer.writeheader()
        
        for c in comparisons:
            p = c["planned"]
            a = c.get("actual") or {}
            day_str = str(p.get("date", ""))
            
            bb = recovery_data.get("body_battery_by_day", {}).get(day_str, {})
            
            writer.writerow({
                "week": week_number,
                "date": day_str,
                "planned_type": p.get("session_type"),
                "planned_duration_min": p.get("duration_min"),
                "planned_pace_target": p.get("pace_target"),
                "planned_zones": p.get("zones"),
                "status": c["status"],
                "actual_duration_min": a.get("duration_min"),
                "actual_distance_km": a.get("distance_km"),
                "actual_avg_pace": a.get("avg_pace"),
                "actual_avg_hr": a.get("avg_hr"),
                "pace_delta_sec": c.get("pace_delta_sec"),
                "hr_vs_zone": c.get("hr_vs_zone"),
                "body_battery_morning": bb.get("morning") if bb else None,
                "resting_hr": recovery_data.get("resting_hr_by_day", {}).get(day_str),
                "sleep_score": recovery_data.get("sleep_score_by_day", {}).get(day_str),
                "training_readiness": recovery_data.get("training_readiness_by_day", {}).get(day_str),
                "fatigue_level": fatigue_analysis.get("fatigue_level"),
                "fatigue_score": fatigue_analysis.get("score"),
                "recommendation": fatigue_analysis.get("recommendation"),
            })
    
    print(f"✅ Week {week_number} appended to {csv_path}")
```

---

## Credentials setup (one-time, à faire communiquer à l'utilisateur)

### Garmin Connect
```
Aucune configuration préalable — juste email + mot de passe Garmin Connect.
Les tokens sont mis en cache automatiquement dans ~/.garminconnect/
```

### Strava (one-time OAuth2 setup)
```
1. Aller sur https://www.strava.com/settings/api
2. Créer une application (nom, site web quelconque)
3. Récupérer : client_id + client_secret
4. Ouvrir dans le navigateur :
   https://www.strava.com/oauth/authorize?client_id=YOUR_ID&redirect_uri=http://localhost&response_type=code&scope=activity:read_all
5. Après autorisation, copier le 'code' dans l'URL de redirection
6. Échanger contre un refresh_token :
   curl -X POST https://www.strava.com/oauth/token \
     -d client_id=YOUR_ID \
     -d client_secret=YOUR_SECRET \
     -d code=YOUR_CODE \
     -d grant_type=authorization_code
7. Sauvegarder le refresh_token retourné (permanent)
```
