# training-tracker (Phase 2 — first to migrate)

This skill is **not yet implemented**. It will be extracted in Phase 2 of the migration — the first skill to be created.

## Migration checklist

- [ ] Create `SKILL.md` with frontmatter:
  - `name: training-tracker`
  - Trigger ONLY for: "bilan de la semaine", "weekly review", "comment s'est passée ma semaine", "ajuste mon plan", "analyse mes données Garmin de la semaine"
  - Explicit NOT triggers: creating new plans, designing workouts, race strategy
- [ ] Copy `references/tracking-module.md` from legacy
- [ ] Adapt references to point to `../_shared/session-schema.md`
- [ ] Document the 4 stages: data collection → comparison planned vs actual → fatigue analysis → plan readjustment
- [ ] Document the fatigue level table (🟢/🟡/🟠/🔴) and associated actions
- [ ] After creation: edit legacy `running-coach/SKILL.md` to **remove** weekly-review triggers and add a pointer "For weekly reviews, see training-tracker"
- [ ] Test: send "bilan de ma semaine" — verify only `training-tracker` triggers

## Target scope

- Pull Garmin and/or Strava data for the past 7 days
- Compare actual vs planned for each session of the week
- Fatigue analysis from Body Battery, resting HR trend, sleep score, Training Readiness
- Adjust the upcoming week's plan based on fatigue level
- Generate the weekly recap widget (visual format with metric cards, session list, mini bar charts)

## Inputs expected

- A plan already exists (created by `training-planner` or manually scheduled in the user's calendar)
- Garmin credentials configured (cached after first use)
- Optionally: Strava OAuth setup

## What this skill does NOT do

- Create new plans → `training-planner`
- Create new isolated workouts → `workout-builder`
