---
name: training-tracker
description: Weekly review of a running training plan. Collects past-week activities from Garmin Connect (and optionally Strava), compares planned vs actual sessions, analyzes fatigue signals (Body Battery, resting HR, sleep score, Training Readiness), and proposes adjustments to upcoming weeks. ONLY trigger when the user explicitly asks for a weekly review with phrases like "bilan de la semaine", "weekly review", "comment s'est passée ma semaine", "ajuste mon plan", or "analyse mes données Garmin de la semaine". DO NOT trigger for creating new training plans (use training-planner), designing individual workouts (use workout-builder), race-day pacing (use race-strategy), or race-week nutrition (use race-week).
---

# Training Tracker

## Purpose

Run a structured weekly review of the user's training: pull last week's data from Garmin Connect, compare it to the planned sessions, assess accumulated fatigue, and propose evidence-based adjustments to the coming weeks of the plan. Always conclude with a visual recap (widget preferred, text fallback acceptable).

## When to use this skill

**Trigger only for:**
- "bilan de la semaine" / "weekly review"
- "comment s'est passée ma semaine"
- "ajuste mon plan"
- "analyse mes données Garmin de la semaine"
- "make a weekly recap"

**Do NOT trigger for:**
- New plan creation → use `training-planner`
- Single workout creation/modification → use `workout-builder`
- Race-week protocol → use `race-week`
- Race pacing strategy → use `race-strategy`

## Execution context detection

**Before producing the final recap**, detect the execution context:
- **If `show_widget` tool is available** (Claude.ai web) → use visual widget format
- **If `show_widget` is unavailable** (Claude Code CLI, API) → use structured markdown fallback

Both formats present the same information; only the rendering differs.

## Inputs needed

Before starting, confirm with the user:

1. **Current plan context** — which plan are we reviewing? (e.g. `#10km-plan-2026`, current week number, total weeks). If a plan tag exists in their Google Calendar, use it.
2. **Week to review** — default is the past 7 days ending today. Confirm if ambiguous.
3. **Garmin access** — verify Garmin MCP is available. If not, ask the user to provide activity data manually or skip Stage 1 fetching.

Do NOT proceed without explicit week boundaries.

## Workflow — 4 stages, in order

### Stage 1 — Data collection

Fetch from Garmin (primary source):

- **Activities of the week** (running only): date, duration, distance, average pace, average HR, max HR, training load, aerobic/anaerobic effect, cadence
- **Recovery signals day by day**: resting HR, Body Battery (morning/evening/min), sleep score, stress, Training Readiness score
- **Weekly summary**: total km, total time, total training load

If Strava sync is enabled, cross-check completion (activities present in Strava but missing in Garmin = upload issue, not missed session).

Implementation details: see `references/tracking-module.md` for the full Python code (functions `connect_garmin`, `get_week_activities_garmin`, `get_recovery_data_garmin`).

### Stage 2 — Compare planned vs actual

For each planned session in the week:

| Status | Definition |
|---|---|
| ✅ Completed as planned | Activity found, duration and pace within ±10% of target |
| 🟡 Completed with deviation | Activity found, but pace > 15s/km off target OR HR consistently above target zone |
| ⚠️ Modified | Activity found but session type differs (e.g. planned intervals → did easy run instead) |
| ❌ Missed | No activity found for that date |

Compute for each session:
- `pace_delta_sec` — average pace difference vs target (seconds/km)
- `hr_vs_zone` — was average HR in the prescribed zone?
- Completion rate for the week (% of sessions completed)

### Stage 3 — Fatigue analysis

Score the week's recovery on 0–100 scale, starting from a 50 baseline. Apply penalties and bonuses based on signals:

**Penalties:**
- Resting HR rising > 5 bpm over the week vs baseline → −15
- Body Battery morning consistently below 50 → −15
- Average sleep score below 60 → −15
- Training Readiness average below 40 → −20

**Bonuses:**
- Sleep score average ≥ 80 → +10
- Training Readiness average ≥ 70 → +15

Map the final score to a fatigue level and recommendation:

| Score | Level | Emoji | Recommendation |
|---|---|---|---|
| ≥75 | low | 🟢 | `increase` — add 10% volume to next week's easy/long runs |
| 50–74 | moderate | 🟡 | `maintain` — keep plan as-is |
| 30–49 | high | 🟠 | `reduce` — cut easy volume by 20%, downgrade one quality session |
| <30 | overreached | 🔴 | `recovery_week` — replace next week with a full recovery week |

**Zone recalibration check.** If average pace_delta_sec is consistently > 15s slower than target across 3+ sessions, zones may be too ambitious. If consistently > 15s faster, zones may be too conservative. Suggest a recalibration of pace targets accordingly.

Reference: full scoring logic in `references/tracking-module.md` (function `analyze_fatigue`).

### Stage 4 — Readjustment proposal

Based on the recommendation from Stage 3, propose modifications to upcoming weeks. Always **propose**, never auto-apply — the user validates explicitly before any calendar/Garmin update.

- **increase**: +10% volume on easy and long runs of next week
- **maintain**: no changes
- **reduce**: −20% on easy runs; downgrade the last quality session of next week to easy
- **recovery_week**: replace all quality sessions with easy runs, cut total volume 40%

If zone recalibration is needed, apply half the detected delta to all remaining weeks' pace targets.

Reference: full readjustment logic in `references/tracking-module.md` (function `readjust_plan`).

## Output: visual recap (widget OR text fallback)

### Path A — Visual widget (when `show_widget` available)

Always conclude the review with a visual widget via the `visualize:show_widget` tool. The widget must contain, in this order:

1. **Header** — week number, phase name, plan tag (e.g. "Semaine 5 — Peak — #10km-plan-2026")

2. **Metric cards** (top row, 4 cards):
   - 🏃 **Distance totale** (km)
   - ⏱ **Temps total** (h:mm)
   - 🔥 **Charge totale** (sum of training load values)
   - 😴 **Sommeil moyen** (avg sleep score)

3. **Session list** with one row per planned session:
   - Color-coded dot (🟢 completed / 🟡 deviation / ⚠️ modified / ❌ missed)
   - Date + session title
   - Duration, distance, avg pace, avg HR
   - Training load value (charge)

4. **Mini bar charts** (bottom):
   - Resting HR day by day (highlight any rise > baseline + 5 bpm in red)
   - Sleep score day by day (color scale: <60 red, 60–80 yellow, >80 green)

5. **Fatigue level banner** — large colored band with emoji, score, level, and headline recommendation in one phrase ("On garde le plan", "On réduit la semaine", etc.)

6. **Proposed adjustments** — bullet list of concrete changes to next week's sessions.

Refer to `visualize:read_me` with module `chart` and `data_viz` before building the widget to load the styling tokens.

### Path B — Structured markdown fallback (when `show_widget` unavailable)

If the widget tool is not available, produce the recap in this exact markdown format:

```
## Bilan Semaine [N] — [Phase] — [Plan tag]

### Métriques de la semaine
| Métrique | Valeur |
|---|---|
| 🏃 Distance totale | [N] km |
| ⏱ Temps total | [h:mm] |
| 🔥 Charge totale | [N] |
| 😴 Sommeil moyen | [score]/100 |

### Séances de la semaine
| Date | Statut | Séance | Durée | Distance | Allure moy | FC moy | Charge |
|---|---|---|---|---|---|---|---|
| Lun 13 | 😴 Repos | — | — | — | — | — | — |
| Mar 14 | 🟢 OK | 🔴 FR 5×1000m | 1h05 | 11.2 km | 4:15/km | 168 bpm | 145 |
| Mer 15 | 🟢 OK | 🟢 EF 45min | 45min | 8.5 km | 5:18/km | 142 bpm | 65 |
| ... | ... | ... | ... | ... | ... | ... | ... |

### Signaux de récupération
| Jour | FC repos | Sommeil | Body Battery | Notes |
|---|---|---|---|---|
| Lun | 51 bpm | 78/100 | 85 | — |
| Mar | 52 bpm | 72/100 | 78 | — |
| ... | ... | ... | ... | ... |

### 🟡 Niveau de fatigue : MODÉRÉ (score: 62/100)
Recommandation : **maintenir le plan tel quel**.

### Ajustements proposés pour la semaine suivante
- Mardi VMA : pas de changement
- Dimanche SL : pas de changement
- Note : surveiller la FC repos sur Mer-Jeu si elle continue de monter
```

Use the same color emojis and status codes as the widget for visual consistency across surfaces.

## Coaching rules to respect (user-specific)

### Proactive load management

If the user has already accumulated **enough quality sessions** this week (typically ≥ 2 of VMA / threshold / Hyrox Run Brick / long run), and is asking about an additional intense session, proactively suggest replacing it with easy volume (EF or EF progressif) instead of stacking more intensity. State the rationale: "Trois séances qualité sont déjà programmées cette semaine ; ajouter une 4ème augmenterait fortement le risque de fatigue accumulée."

### Recovery red flags — always surface to the user

Even if the fatigue level is "moderate" or "low", flag any of the following as standalone warnings:

- Resting HR has risen ≥ 5 bpm above the user's baseline for 2+ consecutive days
- Sleep score < 50 for 2+ consecutive nights
- Reported alcohol consumption coinciding with HR rise (the user has noted: "1 pinte le soir ≈ −15 à −25 points sur le sommeil Garmin")
- Sudden 20+ point drop in Training Readiness over 48h

### Threshold pace conservatism

When suggesting zone recalibration in Stage 3, lean conservative. The user's history shows that overly aggressive threshold targets break down quickly. A safe threshold pace is roughly 10km PB pace + 12–18s/km, not 10km PB pace + 5s/km.

### Missed sessions

Never "make up" a missed session by doubling another. If a key session (VMA, threshold, long run) was missed for fatigue reasons, that's a valid coaching decision — note the cause, do not reschedule.

## Tools to use

- **Garmin MCP** (`garmin:get_activities`, `garmin:get_sleep`, `garmin:get_heart_rate`, `garmin:get_body_battery`, `garmin:get_training_readiness`, `garmin:get_weekly_summary`) — primary data source for Stage 1
- **Google Calendar MCP** (`google-calendar:list-events`) — fetch planned sessions for the week, identified by plan hashtag (e.g. `#10km-plan-2026`)
- **`visualize:show_widget`** with `visualize:read_me` first — when available, for visual output
- **Markdown fallback** — when widget unavailable, structured text recap

## References

- [`references/tracking-module.md`](references/tracking-module.md) — full Python implementation (data fetching, comparison logic, fatigue scoring, readjustment, CSV persistence)
- [`../_shared/session-schema.md`](../_shared/session-schema.md) — standard schema used to read planned sessions
