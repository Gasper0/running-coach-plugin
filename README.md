# Running Coach Plugin

A personalized running and Hyrox coaching plugin for Claude.
Covers 10km, half-marathon, marathon, and Hyrox preparation for all levels — from first-time runners to competitive athletes.

> **Status:** v0.1.0 — under active migration from a monolithic skill to a modular plugin. See [`MIGRATION.md`](./MIGRATION.md) for current progress.

---

## What's inside

The plugin bundles five focused skills under a single distribution:

| Skill | What it does | When it activates |
|---|---|---|
| `training-planner` | Builds a full periodized training plan from a guided intake | "Prépare-moi pour un 10km", "I want to train for a marathon" |
| `training-tracker` | Weekly review using Garmin/Strava data, fatigue analysis, plan adjustment | "Bilan de la semaine", "weekly review" |
| `workout-builder` | Creates a single ad-hoc workout (VMA, threshold, long run) and pushes it to Garmin | "Crée-moi une VMA pour mardi" |
| `race-week` | Race-week protocol: nutrition, taper, activation, race-day checklist | "Ma course est dans 5 jours" |
| `race-strategy` | Km-by-km pacing strategy from a course profile (GPX, screenshot, URL) | "Stratégie pour mon parcours" |

Each skill is self-contained and triggers independently. Shared resources (session schema, pace zone tables, strength exercise library) live in `skills/_shared/` and are referenced by the skills that need them.

---

## Prerequisites

To get the most out of this plugin, the following optional integrations are recommended:

- **Garmin Connect MCP server** — required for direct workout creation/scheduling on your Garmin watch. Install separately and configure your credentials.
- **Google Calendar MCP** — required for direct calendar sync (otherwise `.ics` export works as a fallback).
- **Strava** — optional, used by `training-tracker` for activity backup/cross-check. Requires one-time OAuth2 setup.

The plugin works without these, with file-based exports as fallbacks (`.ics`, Excel/CSV, Word/PDF, Garmin FIT files).

---

## Installation

### As a Claude Code plugin (recommended)

```
/plugin marketplace add github.com/<your-username>/running-coach-plugin
/plugin install running-coach@<marketplace-name>
```

### Manual install

Clone the repo into your local Claude skills directory:

```bash
git clone https://github.com/<your-username>/running-coach-plugin.git
# Then symlink or copy the skills/ directory into your Claude config
```

See [`scripts/deploy.sh`](./scripts/deploy.sh) for a sample deployment script.

---

## Usage

Once installed, the skills trigger automatically based on what you ask Claude. Examples:

- *"I have a half-marathon in 12 weeks, I want to run it in 1h45"* → activates `training-planner`
- *"Bilan de ma semaine, j'ai sauté la VMA de mardi"* → activates `training-tracker`
- *"Make me a Garmin workout: 5×1000m at threshold pace"* → activates `workout-builder`
- *"My 10k is on Sunday, what should I eat this weekend?"* → activates `race-week`
- *"Here's the GPX of my course, what's a smart pacing plan?"* → activates `race-strategy`

---

## Configuration

This plugin contains no personal data by default. If you want to wire it to your specific Google Calendar, Garmin profile, or other personal context, create a local config file (not committed to git):

```bash
cp config.example.json config.local.json
# Edit config.local.json with your IDs, paths, preferences
```

`config.local.json` is excluded from git via `.gitignore`.

---

## Repository structure

```
running-coach-plugin/
├── .claude-plugin/
│   └── plugin.json              ← plugin metadata
├── skills/
│   ├── _shared/                 ← resources used by multiple skills
│   ├── training-planner/
│   ├── training-tracker/
│   ├── workout-builder/
│   ├── race-week/
│   └── race-strategy/
├── scripts/
│   └── deploy.sh                ← local sync helper
├── README.md
├── MIGRATION.md                 ← internal migration progress
└── LICENSE
```

---

## Contributing

This is a personal coaching plugin built around real training data. If you fork it for your own use, expect to adapt the cross-training rules, pace zone defaults, and exports to your context.

Pull requests welcome for general improvements (clearer instructions, better trigger words, additional export formats, bug fixes).

---

## License

MIT — see [LICENSE](./LICENSE).
