# Shared resources

This directory contains files referenced by multiple skills in the plugin.

**Important:** these files are referenced via relative paths *internal to the plugin* (e.g. `../_shared/session-schema.md` from a skill's `SKILL.md`). They must remain inside the plugin directory so that they get copied along with the plugin at install time on end-user machines.

## Files

| File | Used by | Purpose |
|---|---|---|
| `session-schema.md` | all skills that emit/consume sessions | Standard schema + session type reference table (codes, colors, emojis) |
| `vdot-paces.md` | `training-planner`, `workout-builder` | Pace zone calculation from a known race time (Jack Daniels' VDOT) |
| `strength-exercises.md` | `training-planner`, `workout-builder` | Strength exercise library for running-specific reinforcement |

## When to add a file here

Add a file to `_shared/` only if it's used by **2 or more skills**. If only one skill uses it, keep it inside that skill's own `references/` folder.

Avoid putting skill instructions here — `_shared/` is for reference material (schemas, tables, libraries), not behavior. Each skill's behavior must remain in its own `SKILL.md`.
