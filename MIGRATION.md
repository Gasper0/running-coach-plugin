# Migration Tracker

Progress log for the migration from a monolithic `running-coach` skill (legacy v1) to a modular plugin (v0.1+).

Legacy version archived in branch [`legacy/v1`](https://github.com/<your-username>/running-coach-plugin/tree/legacy/v1).

---

## Phase status

- [x] **Phase 0** — Repo setup and base structure
- [x] **Phase 1** — Extract `_shared/` resources (session-schema, vdot-paces, strength-exercises)
- [ ] **Phase 2** — Extract `training-tracker` skill
- [ ] **Phase 3** — Extract `workout-builder` skill
- [ ] **Phase 4** — Extract `race-week` skill
- [ ] **Phase 5** — Refactor remaining content into `training-planner`
- [ ] **Phase 6** — Validation pass + tighten triggers across all skills
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

### YYYY-MM-DD — Phase X (...)
- (fill as you go)

---

## Notes & decisions

- `race-strategy` was already a standalone skill; rapatriated into this plugin under `skills/race-strategy/` (no functional changes).
- `_shared/` is intentionally placed *inside* the plugin folder, not above. This is required because Claude copies the plugin directory to a cache location at install time, and external paths (`../shared/`) would not resolve for end users.
- The intake widget HTML (~16 KB) belongs strictly to `training-planner`. Other skills must not depend on it.
- Personal data (Google Calendar IDs, Garmin credentials, local file paths) must never be committed. Use `config.local.json` (gitignored) for per-user configuration.
