# Migration Tracker

Progress log for the migration from a monolithic `running-coach` skill (legacy v1) to a modular plugin (v0.1+).

Legacy version archived in branch [`legacy/v1`](https://github.com/<your-username>/running-coach-plugin/tree/legacy/v1).

---

## Phase status

- [x] **Phase 0** — Repo setup and base structure
- [x] **Phase 1** — Extract `_shared/` resources (session-schema, vdot-paces, strength-exercises)
- [x] **Phase 2** — Extract `training-tracker` skill
- [x] **Phase 3** — Extract `workout-builder` skill
- [x] **Phase 4** — Extract `race-week` skill
- [x] **Phase 5** — Refactor remaining content into `training-planner`
- [x] **Phase 6** — Validation pass + tighten triggers across all skills
- [ ] **Phase 7** *(post-migration)* — Add marketplace.json, publish public, test install from another machine

---

## Per-skill triggers (final state — for reference during migration)

To avoid trigger contention between skills, each one matches a tight set of phrases:

### training-planner
- "prépare-moi pour un [10km/semi/marathon/Hyrox]"
- "j'ai une course dans X semaines/mois"
- "génère-moi un plan d'entraînement"
- "I want to prepare for a [race]"
- **NOT** for: weekly reviews, one-off workouts, race-week nutrition, pacing strategy

### training-tracker
- "bilan de la semaine"
- "weekly review"
- "comment s'est passée ma semaine"
- "ajuste mon plan"
- "analyse mes données Garmin de la semaine"
- **NOT** for: creating new plans, designing workouts, race strategy

### workout-builder
- "crée-moi une séance de [type]"
- "construis un workout Garmin pour [séance]"
- "modifie ma séance de [jour]"
- "ajoute des fractionnés"
- **NOT** for: full training plans, weekly reviews, race strategy

### race-week
- "ma course est dans [1-7] jours"
- "nutrition course"
- "que manger avant ma course"
- "checklist veille de course"
- "activation jour de course"

### race-strategy
- Shares a GPX file / elevation screenshot / course URL
- "stratégie pour mon parcours"
- "pacing strategy"
- "split plan"

---

## Migration log

### 2026-05-11 — Phase 0 (Repo setup)
- Created repo structure
- `plugin.json` initialized at v0.1.0
- `_shared/` placeholder ready
- Skill placeholders created for the 5 target skills

### 2026-05-11 — Phase 2 (training-tracker)
- Extracted training-tracker skill as first migration target
- SKILL.md (169 lines) with tight triggers focused on "bilan de la semaine" / "weekly review" phrases
- tracking-module.md (810 lines) copied verbatim from legacy — full Python implementation for Garmin data collection, comparison, fatigue scoring, plan readjustment
- Visual weekly recap widget format documented as mandatory output
- User-specific coaching rules encoded: proactive load management, conservative threshold pace, alcohol/sleep correlation flag
- Validation: skill detected in Claude Code `/skills`, trigger phrase activates correctly
- Updated `scripts/deploy.sh` to symlink each skill individually (required for Claude Code detection)

### 2026-05-12 — Phase 3 (workout-builder)
- Extracted workout-builder skill with Path A/B workflow
- Garmin MCP integration validated end-to-end in Claude Code
- Coaching rules encoded: proactive load management, conservative threshold, 48h recovery rule
- Note: user-specific pace values still hardcoded — to be moved to config.local.json in Phase 7

### 2026-05-13 — Phase 4 (race-week)
- Extracted race-week skill with distance-adaptive nutrition protocols
- Coverage: 10km, half-marathon, marathon, Hyrox — each with specific macros and timelines
- Mandatory show_widget output for visual race-week timeline
- Hyrox-specific protein protocol baked in (1.8-2.0 g/kg vs 1.4-1.6 for running)
- Coaching rules: no experimentation in final 3 days, alcohol pattern recognition, travel adaptation

### 2026-05-13 — Phase 5 (training-planner + CLI fallback)
- Refactored legacy running-coach into focused training-planner skill
- Scope limited to plan creation; modifications/reviews/race-week handled by companion skills
- Differentiated export workflow: calendar all-at-once, Garmin week-by-week
- Hyrox simplified to "Run Brick" session type in library
- Personal values (PB, FC max, zones) moved to config.local.json schema
- Added widget-first + text fallback pattern to training-planner, training-tracker, race-week — skills now work identically on Claude.ai web and Claude Code CLI

### 2026-05-13 — Phase 6.1 (race-strategy rapatriation)
- Rapatriated race-strategy from standalone skill into the plugin
- Enriched with NOT-triggers, widget-first + text fallback pattern, coordination notes
- All 5 skills now live in the plugin structure
- Next: Phase 6.2 (claude.ai bridge + legacy deactivation), Phase 6.3 (trigger validation)

### 2026-05-14 — Phase 6 complete (validation pass)
- Phase 6.1: Rapatriated race-strategy into the plugin
- Phase 6.2: Added package.sh for claude.ai bridge, uploaded 5 skills, added Garmin MCP availability fallback to 3 skills, deactivated legacy running-coach
- Phase 6.3: Tightened triggers based on 7-phrase test matrix — 5/7 correct, 1 acceptable, 1 fixed (retrospective vs proactive disambiguation between training-tracker and workout-builder)
- Migration tracker now ready for Phase 7 (public distribution via marketplace.json)

### YYYY-MM-DD — Phase X (...)
- (fill as you go)

---

## Notes & decisions

- `race-strategy` was already a standalone skill; rapatriated into this plugin under `skills/race-strategy/` (no functional changes).
- `_shared/` is intentionally placed *inside* the plugin folder, not above. This is required because Claude copies the plugin directory to a cache location at install time, and external paths (`../shared/`) would not resolve for end users.
- The intake widget HTML (~16 KB) belongs strictly to `training-planner`. Other skills must not depend on it.
- Personal data (Google Calendar IDs, Garmin credentials, local file paths) must never be committed. Use `config.local.json` (gitignored) for per-user configuration.
