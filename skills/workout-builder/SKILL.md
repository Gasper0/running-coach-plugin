---
name: workout-builder
description: Create or modify a single running workout and push it to Garmin Connect. Use ONLY when the user requests a one-off workout (not a full plan) or wants to modify a session already scheduled. Trigger phrases include "crée-moi une séance de [VMA/seuil/EF/long]", "construis un workout Garmin pour [séance]", "modifie ma séance de [jour]" (priority case), "ajoute des fractionnés à mon plan", "fais une séance de seuil pour demain", "déplace ma VMA à mercredi". DO NOT trigger for creating new full training plans (use training-planner), weekly progress reviews (use training-tracker), race-day pacing (use race-strategy), or race-week nutrition (use race-week).
---

# Workout Builder

## Purpose

Create or modify a single structured running workout and push it directly to the user's Garmin watch via the Garmin MCP. Garmin is the default and only target — Google Calendar sync is optional and only happens on explicit request.

This skill handles two distinct flows:
- **Path A (priority)** — Modify a session already scheduled in the user's plan
- **Path B** — Create a brand-new standalone workout

## When to use this skill

**Trigger for:**
- "crée-moi une séance de VMA / seuil / tempo / sortie longue"
- "construis un workout Garmin pour [type de séance]"
- "modifie ma séance de mardi" (changer date/durée/intensité d'une séance existante)
- "déplace ma VMA à mercredi"
- "ajoute des fractionnés"
- "fais une séance de seuil pour demain"
- "raccourcis mon long run de dimanche"
- "remplace ma séance de jeudi par un footing récup"

**Do NOT trigger for:**
- Full training plan creation → use `training-planner`
- Weekly review / fatigue analysis → use `training-tracker`
- Race pacing strategy → use `race-strategy`
- Race-week protocol → use `race-week`

## Inputs needed

Before doing anything, confirm with the user:

1. **Path A or B** — is the user modifying an existing scheduled session, or creating a new one from scratch?
2. **Date** — exact date of the session (Garmin schedules on specific dates, not relative)
3. **Session type** — easy, long run, tempo, threshold, VMA/intervals, recovery, hyrox-specific
4. **Structure** — duration, distance, number of reps, target paces, target HR zones
5. **Push targets confirmation** — by default push to Garmin only; ask explicitly if user wants Google Calendar sync too

Do NOT push to Garmin without explicit confirmation of the structure. Always show the user a summary of the workout before calling `garmin:create_workout`.

## Path A — Modify an existing scheduled session (priority workflow)

This is the most common case. The user already has a plan with sessions scheduled; they want to adjust one.

### Step A1 — Locate the existing session

1. Identify which session the user is talking about (date + type, e.g. "ma VMA de mardi 19 mai")
2. Fetch the current state from Garmin:
   ```
   garmin:list_workouts
   ```
   Look for the workout scheduled on the target date.
3. If the user mentions Google Calendar tagging (e.g. `#10km-plan-2026`), also fetch the corresponding GCal event for cross-reference:
   ```
   google-calendar:search-events  # with the date and plan tag
   ```

### Step A2 — Determine what changes

Common modifications:

| Change type | What to do |
|---|---|
| Change date | Delete the existing workout, recreate on new date |
| Change duration / volume | Modify steps, recreate workout |
| Change intensity (pace targets, HR zones) | Modify step targets, recreate workout |
| Change session type entirely | Delete old workout, create new one |

⚠️ **Garmin does not support in-place workout editing via MCP.** Modifications = delete + recreate. Always:
1. Capture the existing `workout_id` and its `scheduled_date`
2. `garmin:delete_workout` with that ID
3. Create the new workout (Step B2 below)
4. Schedule it (Step B3 below)

### Step A3 — Confirm before destroying

Before calling `garmin:delete_workout`, **always show the user**:
- What's being deleted (current workout structure)
- What's being created in its place
- And ask: "On valide ?"

This prevents accidental loss of a workout the user wanted to keep.

## Path B — Create a new standalone workout

### Step B1 — Build the session structure

Use the standard schema from `../_shared/session-schema.md`. A typical workout has three blocks:

```
warmup (typically 10–15 min, easy pace)
  ↓
[mandatory "rest" step with duration_type: "open"]   ← see Garmin rules
  ↓
main block (intervals, threshold segments, etc.)
  ↓
cooldown (typically 5–10 min, easy pace)
```

For pace targets, derive from the user's known zones (Z1–Z5 in `../_shared/vdot-paces.md`) or from a recent race time. **Default to conservative**: threshold pace ≈ 10km PB pace + 12–18 s/km, never less.

### Step B2 — Create the workout in Garmin

Use `garmin:create_workout` with the structure built in Step B1. Capture the returned `workout_id` immediately — you'll need it for scheduling.

**Critical formatting rules** (full details in `references/garmin-workout-rules.md`):
- Pace targets: integers in seconds/km (e.g. 242 for 4:02/km, not "4:02")
- HR targets: integers in bpm
- Nested repeats: **flatten into sequential repeat blocks** separated by standalone recovery steps. `3×(5×400m)` is NOT a nested structure — it is three sequential `repeat` blocks of `5×400m` each, with recoveries between groups.
- Always insert a `rest` step with `duration_type: "open"` between warmup and main block (user requires manual Lap press)

### Step B3 — Schedule the workout

Use `garmin:schedule_workout` with the `workout_id` from Step B2 and the target date.

⚠️ **Never call `schedule_workout` twice on the same workout** — this creates duplicates that can't be cleanly deleted without recreating the workout. If you need to reschedule, delete first, then create + schedule fresh.

## Pace targets and HR zones

The user's reference values:
- **10km PB**: 37:45 (3:47/km, March 2026)
- **Threshold pace**: 4:02–4:08/km (242–248 sec/km) — derived conservatively from 10km PB
- **VMA pace**: 3:29–3:34/km (~209–214 sec/km)
- **Easy / Z1–Z2**: 4:55–5:10/km (~295–310 sec/km)
- **FC max**: 199 bpm (Hyrox Toulouse March 2026)
- **FC resting**: ~47–52 bpm

When in doubt about a pace target, ask the user — never invent a value that conflicts with their known zones.

## Google Calendar sync (on explicit request only)

By default, do NOT push the workout to Google Calendar. The user uses GCal as a separate planning layer.

If the user explicitly says "ajoute aussi sur mon calendrier" or "mets-le dans mon Google Calendar", then:

1. Confirm the training calendar name (the user's training calendar ID is in their `config.local.json` — typically tagged `#10km-plan-2026` or similar in event titles)
2. Use `google-calendar:create-event` with:
   - Title: emoji + code + brief description (e.g. "🔴 FR 5×1000m seuil")
   - Color matching the session type (see `../_shared/session-schema.md` table)
   - Description: full workout structure
   - Hashtag at the end of description (e.g. `#10km-plan-2026`)
   - `sendUpdates: "none"` — do NOT send notifications

## Cleanup rules

After a workout is completed (or cancelled), the user wants their Garmin to stay clean.

If the user mentions a session was done or skipped, ask if they want to delete the corresponding workout:

```
garmin:list_workouts
# Find the completed/cancelled one
garmin:delete_workout
```

This keeps the watch interface uncluttered for the next session.

## Output format

After every successful push, present a summary in this exact format:

```
✅ Séance créée et programmée

📅 Date : [date]
🏃 Type : [emoji] [code] — [title]
⏱ Durée estimée : [min]
🎯 Allure cible : [pace range]
❤️ FC cible : [HR zone]

📲 Push :
  • Garmin Connect ✓
  • Google Calendar [✓ / skipped]

[Si modification :] Ancienne séance supprimée : [id supprimé]
```

## References

- [`references/garmin-workout-rules.md`](references/garmin-workout-rules.md) — complete Garmin MCP technical rules (step types, pace/HR formatting, repeat block flattening, manual lap rules)
- [`../_shared/session-schema.md`](../_shared/session-schema.md) — standard session schema and color/emoji table
- [`../_shared/vdot-paces.md`](../_shared/vdot-paces.md) — pace zone calculation from race performance

## Coaching rules to enforce

### Proactive load management

If the user requests a quality session (VMA, threshold, hyrox brick) but already has ≥ 2 quality sessions scheduled in the same week, proactively flag this:

> "Tu as déjà X séances qualité programmées cette semaine. Une 4ème augmenterait fortement le risque de fatigue accumulée. Souhaitez-vous plutôt remplacer une séance existante, ou ajouter une sortie en endurance fondamentale (EF) ?"

Wait for explicit user choice before proceeding.

### Conservative threshold pace

When the user requests a threshold session without specifying paces, default to `10km PB pace + 12–18 s/km`. Never default below `10km PB + 5 s/km` — this is the user's known threshold ceiling, and going below it consistently breaks down.

### Recovery between quality sessions

If a quality session is being placed less than 48h after another quality session, flag this and propose either moving it or downgrading one to recovery.

### Hyrox specifics

For Hyrox Run Brick sessions (running + stations), do NOT push to Garmin as a structured workout — Garmin doesn't handle station work in workout format. Instead:
1. Create a "free run" workout on Garmin (just the running portion as warmup or main block, no station instructions)
2. Tell the user the station details verbally / in chat
3. Optionally push the full session to Google Calendar (if requested) with stations described in the event body
