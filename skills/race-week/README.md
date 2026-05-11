# race-week (Phase 4 — not yet migrated)

This skill is **not yet implemented**. It will be extracted in Phase 4 of the migration.

## Migration checklist

- [ ] Create `SKILL.md` with frontmatter:
  - `name: race-week`
  - Trigger for: "ma course est dans [1-7] jours", "nutrition course", "que manger avant ma course", "checklist veille de course", "activation jour de course", "préparation dossard"
- [ ] Copy `references/nutrition-guide.md` from legacy
- [ ] Add content for: hydration protocol, sleep optimization, dress rehearsal (full kit test), activation session (J-1 or J-2), bib pickup checklist, race-morning routine, stress management

## Target scope

A focused protocol for the **7 days before a race**:

- **J-7 to J-4**: carb-loading strategy, taper continuation, gear check
- **J-3 to J-2**: meal planning (familiar food, no experimentation), final activation, hydration
- **J-1**: dress rehearsal, equipment laid out, alarm set, light dinner
- **J0 (race morning)**: wake time, breakfast timing, warmup, mental cues

## Inputs expected

- Race date (mandatory)
- Race distance (10km / semi / marathon / Hyrox)
- User context: known dietary preferences, prior race experience, anxiety level (if mentioned)

## What this skill does NOT do

- Build the training plan up to race week → `training-planner`
- Pacing strategy for the course itself → `race-strategy`
- Weekly review during the season → `training-tracker`
