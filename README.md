# Running Coach Plugin

A personalized running and Hyrox coaching plugin for Claude.
Covers 10km, half-marathon, marathon, and Hyrox preparation for all levels — from first-time runners to competitive athletes.

> **Status:** v0.2.0 — beta stable. 5 skills covering the full coaching workflow. Works with Claude Code, Claude Desktop, Cowork, and Claude.ai web.

---

## What's inside

The plugin bundles five focused skills under a single distribution:

| Skill | What it does | When it activates |
|---|---|---|
| `training-planner` | Builds a full periodized training plan from a guided intake | "Prépare-moi pour un 10km", "I want to train for a marathon" |
| `training-tracker` | Weekly review using Garmin/Strava data, fatigue analysis, plan adjustment | "Bilan de la semaine", "weekly review" |
| `workout-builder` | Creates a single ad-hoc workout (VMA, threshold, long run) and pushes it to Garmin | "Crée-moi une VMA pour mardi" |
| `race-week` | Race-week protocol: nutrition (adapted by distance), taper, activation, race-day checklist | "Ma course est dans 5 jours" |
| `race-strategy` | Km-by-km pacing strategy from a course profile (GPX, screenshot, URL) | "Stratégie pour mon parcours" |

Each skill is self-contained and triggers independently. Shared resources (session schema, pace zone tables) live in `skills/_shared/`.

---

## Installation

### Quick install via Claude Code marketplace (recommended)

```
/plugin marketplace add Gasper0/running-coach-plugin
/plugin install running-coach@Gasper0
```

Verify installation:
```
/plugin list
```

You should see `running-coach@Gasper0` with all 5 skills active.

### Manual install (Claude.ai web / Cowork)

If you're on Claude.ai web or Cowork without Claude Code, download the prebuilt skill zips from the [Releases page](https://github.com/Gasper0/running-coach-plugin/releases) and upload them one by one via:
- Claude.ai → Settings → Capabilities → Skills → Upload

5 zips to upload (in any order):
- `training-planner.zip`
- `training-tracker.zip`
- `workout-builder.zip`
- `race-week.zip`
- `race-strategy.zip`

The zips include shared resources inlined — each one is self-contained.

---

## Optional integration — Garmin MCP

For the full experience, install the companion [garmin-mcp](https://github.com/Gasper0/garmin-mcp) server, which gives the plugin direct access to your Garmin Connect data and the ability to push workouts to your watch.

**Without garmin-mcp**, the plugin still works fully via manual data input — you can copy-paste your week's activities and the plan will be adjusted. The skill `training-tracker` automatically falls back to a manual-input protocol when Garmin MCP is unavailable.

### Install garmin-mcp (5 minutes)

```bash
# Clone the MCP server
git clone https://github.com/Gasper0/garmin-mcp ~/garmin-mcp
cd ~/garmin-mcp

# Run the install script (creates venv, installs deps, prepares .env)
chmod +x install.sh
./install.sh

# Edit .env with your Garmin credentials
nano .env
```

### Connect garmin-mcp to your Claude client

**For Claude Code:**
```bash
claude mcp add garmin --scope user -- \
  $HOME/garmin-mcp/venv/bin/python3 \
  $HOME/garmin-mcp/server.py
```

**For Claude Desktop / Cowork:**
Edit `~/Library/Application Support/Claude/claude_desktop_config.json` and add:
```json
{
  "mcpServers": {
    "garmin": {
      "command": "/Users/YOUR_USERNAME/garmin-mcp/venv/bin/python3",
      "args": ["/Users/YOUR_USERNAME/garmin-mcp/server.py"]
    }
  }
}
```

Restart Claude Desktop after editing.

> **Note**: The `.mcp.json` file at the plugin root declares this server with template paths, but you'll need to configure it manually with your real install path. The Garmin MCP cannot be auto-installed because it requires Python, a venv, and your personal credentials.

---

## Surface compatibility

The plugin is designed to work across all Claude surfaces, with graceful degradation when capabilities are missing:

| Surface | Widgets | Garmin auto-fetch | Notes |
|---|---|---|---|
| **Claude Desktop / Cowork** | ✅ | ✅ (with garmin-mcp) | Best experience |
| **Claude Code (CLI)** | ❌ Text fallback | ✅ (with garmin-mcp) | Full functionality, text-only rendering |
| **Claude.ai web** | ✅ | ❌ Manual input fallback | Garmin unavailable but plugin remains useful |

---

## Configuration — `config.local.json`

Create a local config file to avoid re-entering personal values (PB times, FC max, training zones, calendar IDs):

```bash
cd path/to/installed/plugin
cp config.example.json config.local.json
# Edit config.local.json with your values
```

`config.local.json` is gitignored. Schema documentation in [`skills/_shared/config-schema.md`](skills/_shared/config-schema.md).

---

## Usage

Once installed, the skills trigger automatically based on what you ask Claude. Examples:

- *"I have a half-marathon in 12 weeks, I want to run it in 1h45"* → activates `training-planner`
- *"Bilan de ma semaine, j'ai sauté la VMA de mardi"* → activates `training-tracker`
- *"Make me a Garmin workout: 5×1000m at threshold pace"* → activates `workout-builder`
- *"My 10k is on Sunday, what should I eat this weekend?"* → activates `race-week`
- *"Here's the GPX of my course, what's a smart pacing plan?"* → activates `race-strategy`

---

## Repository structure

```
running-coach-plugin/
├── .claude-plugin/
│   ├── plugin.json              ← plugin metadata
│   └── marketplace.json         ← marketplace definition
├── .mcp.json                    ← optional MCP dependencies (garmin)
├── config.example.json          ← config template
├── skills/
│   ├── _shared/                 ← resources used by multiple skills
│   ├── training-planner/
│   ├── training-tracker/
│   ├── workout-builder/
│   ├── race-week/
│   └── race-strategy/
├── scripts/
│   ├── deploy.sh                ← local sync helper (Claude Code dev)
│   └── package.sh               ← generates claude.ai-ready zips
├── README.md
├── MIGRATION.md                 ← internal migration log
└── LICENSE
```

---

## Companion projects

- **[garmin-mcp](https://github.com/Gasper0/garmin-mcp)** — Garmin Connect MCP server (optional dependency for full data integration)

---

## Versioning

Following semver. Current: **v0.2.0** (beta stable).

- v0.1.x — initial migration from monolithic legacy skill
- v0.2.x — 5 skills validated, cross-surface fallbacks, marketplace release
- v1.0.0 — planned after community feedback validates stability

---

## License

MIT — see [LICENSE](./LICENSE).

This is a personal coaching plugin built around real training data. Feel free to fork it for your own use — expect to adapt the cross-training rules, pace zone defaults, and exports to your context.
