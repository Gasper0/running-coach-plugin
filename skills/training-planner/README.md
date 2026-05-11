# training-planner (Phase 5 — not yet migrated)

This skill is **not yet implemented**. It will be extracted in Phase 5 of the migration (see [`MIGRATION.md`](../../MIGRATION.md)).

## Migration checklist

When extracting this skill from legacy `running-coach/SKILL.md`:

- [ ] Create `SKILL.md` with frontmatter (`name: training-planner`, tight trigger list)
- [ ] Copy `references/intake-widget.html` from legacy
- [ ] Copy `references/session-library.md` from legacy
- [ ] Copy export reference files: `ics-export.md`, `excel-export.md`, `docx-export.md`, `garmin-export.md`, `google-calendar-export.md`, `nolio-export.md`
- [ ] Create `references/periodization.md` (extracted from Step 3 of legacy SKILL.md)
- [ ] Create `references/cross-training-rules.md` (extracted from gym/Hyrox interference section)
- [ ] Create `references/beginner-marathon-rules.md` (extracted from level-specific rules)
- [ ] Update all `references/*.md` to point to `../_shared/session-schema.md` for the schema
- [ ] Remove any references to weekly tracking (now in `training-tracker`)
- [ ] Remove any references to race-week nutrition (now in `race-week`)
- [ ] Remove any references to ad-hoc workout building (now in `workout-builder`)
- [ ] Validate triggers don't overlap with the other 4 skills

## Target scope

- Intake interview (HTML widget)
- Physiological profile calculation (using `_shared/vdot-paces.md`)
- Plan periodization (Base → Build → Peak → Taper)
- Weekly plan generation
- Initial exports (ICS, Excel, Word, Garmin FIT, Google Calendar, Nolio)

## What this skill does NOT do

- Weekly progress reviews → `training-tracker`
- Single ad-hoc workouts → `workout-builder`
- Race-week nutrition / taper protocol → `race-week`
- Race-day pacing strategy → `race-strategy`
