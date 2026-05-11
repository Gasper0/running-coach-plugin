# race-strategy (already exists — needs rapatriation)

This skill already exists as a standalone skill at `/mnt/skills/user/race-strategy/`. The migration consists of copying it into this plugin without functional changes.

## Migration checklist

- [ ] Copy `SKILL.md` from the standalone skill
- [ ] Copy `references/` directory (input-parsing, strategy-calibration, widget-template, mental-prep)
- [ ] Copy `scripts/parse_gpx.py`
- [ ] No content change needed — this skill was already well-scoped
- [ ] Once copied and tested, the standalone version at `/mnt/skills/user/race-strategy/` can be archived

## Target scope

(Already documented in the skill itself — see the SKILL.md content from the standalone version.)

Km-by-km pacing strategy from a course profile (GPX file, elevation screenshot, or course URL) for 5km, 10km, half-marathon, or marathon. Produces a visual widget with elevation profile, color-coded splits, tactical notes, and a personalized mental preparation guide.
