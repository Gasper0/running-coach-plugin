# workout-builder (Phase 3 — not yet migrated)

This skill is **not yet implemented**. It will be extracted in Phase 3 of the migration.

## Migration checklist

- [ ] Create `SKILL.md` with frontmatter:
  - `name: workout-builder`
  - Trigger for: "crée-moi une séance de [type]", "construis un workout Garmin pour [séance]", "modifie ma séance de [jour]", "ajoute des fractionnés", "fais une séance de seuil pour demain"
  - Explicit NOT triggers: full training plans, weekly reviews, race strategy
- [ ] Create `references/garmin-workout-rules.md` — consolidates Garmin MCP rules:
  - `repeat_count` blocks are flat, not nested (e.g. 3×(5×400m) must be 3 sequential repeat blocks separated by standalone recoveries)
  - Pace targets in seconds-per-km as integers (242 = 4:02/km)
  - Heart rate targets in bpm integers
  - Always insert a `rest` step with `duration_type: "open"` between warmup and main block (user requirement)
  - Delete completed/cancelled workouts to keep the watch clean
- [ ] Reference `../_shared/session-schema.md` for the standard session format
- [ ] Reference `../_shared/vdot-paces.md` if pace targets need to be derived from a race time
- [ ] Test: "crée-moi une VMA 5×1000m pour mardi" — only this skill triggers, Garmin workout is created correctly

## Target scope

- Generate a single structured workout (VMA, threshold, tempo, long run with pace segments, etc.)
- Push it to Garmin via MCP (`garmin:create_workout` + `garmin:schedule_workout`)
- Push it to Google Calendar via MCP
- Modify an existing scheduled session (change pace, change duration, swap session type)

## Inputs expected

- A specific workout request from the user, OR an existing session to modify
- The user's current pace zones (either passed explicitly or inferred from `_shared/vdot-paces.md` if a recent race time is known)
- Garmin MCP available (for direct push to watch)

## What this skill does NOT do

- Create a full plan → `training-planner`
- Compare planned vs actual → `training-tracker`
