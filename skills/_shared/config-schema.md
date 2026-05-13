# config.local.json Schema

> Per-user configuration for the running-coach plugin. Stored at the plugin root, gitignored.
> Read by all skills in the plugin when present. Falls back to defaults / prompts when absent.

---

## Purpose

The config file holds personal data that:
- Doesn't change often (10km PB, FC max, training preferences)
- Shouldn't be in the skill files (each user has different values)
- Shouldn't be re-entered every conversation

When a skill needs a personal value (e.g., `training-planner` computing zones), it checks `config.local.json` first. If the value exists, it's used directly. If not, the skill asks the user.

---

## File location

```
running-coach-plugin/
├── config.example.json    ← template, committed
├── config.local.json      ← real values, gitignored
└── skills/
    └── ...
```

Setup for first use:
```bash
cd ~/Claude/Projects/running-coach-plugin
cp config.example.json config.local.json
# Edit config.local.json with your values
```

---

## Schema sections

### `user`
Basic identification.

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string | recommended | Used in plan titles, dialogues |
| `language` | "fr" \| "en" | recommended | Skill outputs language |
| `timezone` | IANA tz | recommended | "Europe/Paris", etc. |

### `physiology`
Body and physiological baselines.

| Field | Type | Notes |
|---|---|---|
| `age` | int | Used for FC max estimation if not known |
| `weight_kg` | float | Used for nutrition (g/kg targets) |
| `height_cm` | int | Optional |
| `sex` | "male" \| "female" | Used for FC max formula adjustment |
| `hr_max` | int (bpm) | Direct value — overrides age-based estimation |
| `hr_resting` | int (bpm) | Used to detect fatigue (rising > +5 bpm = warning) |
| `vma_kmh` | float | Direct VMA value from a test |
| `vo2max` | int | Optional, from Garmin estimation |

### `performance_history`
Recent best times by distance, used to derive pace zones.

| Field | Format | Notes |
|---|---|---|
| `5km_pb` | "MM:SS" | e.g. "18:30" |
| `10km_pb` | "HH:MM:SS" or "MM:SS" | e.g. "37:45" |
| `10km_pb_date` | "YYYY-MM-DD" | When the time was set (used to gauge freshness) |
| `semi_pb` | "HH:MM:SS" | |
| `marathon_pb` | "HH:MM:SS" | |
| `hyrox_pb` | "HH:MM:SS" | |
| `hyrox_pb_format` | "Solo" \| "Doubles" \| "Pro" | |

### `training_zones`
Pace and HR zones. Either provide explicit values, or leave `null` and let `training-planner` derive them from `performance_history` via VDOT method.

| Field | Format | Notes |
|---|---|---|
| `z1_recovery_pace_min_per_km` | "M:SS" | e.g. "5:10" |
| `z2_endurance_pace_min_per_km` | "M:SS-M:SS" | range |
| `z3_tempo_pace_min_per_km` | "M:SS-M:SS" | |
| `z4_threshold_pace_min_per_km` | "M:SS-M:SS" | |
| `z5_vma_pace_min_per_km` | "M:SS-M:SS" | |
| `z1_hr_max_pct` to `z5_hr_max_pct` | int (%) | HR zone boundaries as % of FC max |

### `training_preferences`
Weekly structure and timing defaults.

| Field | Type | Default | Notes |
|---|---|---|---|
| `weekly_volume_km_baseline` | float | null | Used as starting point for new plans |
| `sessions_per_week` | int | 5 | |
| `rest_day` | day name | "Monday" | |
| `quality_days` | array of day names | ["Tuesday", "Thursday"] | |
| `long_run_day` | day name | "Sunday" | |
| `strength_day` | day name | "Saturday" | |
| `default_session_start_morning` | "HH:MM" | "07:00" | Used for calendar events |
| `default_session_start_evening` | "HH:MM" | "18:00" | Used for calendar events |

### `integrations`
MCP and external service configuration.

#### `google_calendar`
| Field | Type | Notes |
|---|---|---|
| `training_calendar_id` | string | Full GCal calendar ID, ending with `@group.calendar.google.com` |
| `event_naming.completed_prefix` | string | Emoji or prefix for completed sessions |
| `event_naming.cancelled_prefix` | string | For cancelled sessions |
| `event_naming.lightened_suffix` | string | For lightened sessions |
| `event_naming.race_prefix` | string | For race events |
| `default_hashtag` | string | Plan-wide hashtag e.g. `#marathon-2026` |

#### `garmin`
| Field | Type | Default | Notes |
|---|---|---|---|
| `weekly_push_strategy` | "current_week_only" \| "full_plan" | "current_week_only" | See export-workflow.md |
| `auto_cleanup_completed` | bool | true | Delete completed workouts after sync |
| `default_watch_model` | string | null | For logging |

### `coaching_rules`
Personal coaching preferences that override skill defaults.

| Field | Type | Default | Notes |
|---|---|---|---|
| `conservative_threshold_offset_seconds` | int | 15 | Threshold = 10km PB + this offset s/km |
| `min_hours_between_quality_sessions` | int | 48 | |
| `stepback_week_frequency` | int | 4 | Every N weeks |
| `stepback_volume_reduction_pct` | int | 25 | |

---

## How skills read the config

In Python or pseudo-code:

```python
from pathlib import Path
import json

config_path = Path("running-coach-plugin/config.local.json")
if config_path.exists():
    config = json.loads(config_path.read_text())
    user_hr_max = config.get("physiology", {}).get("hr_max")
else:
    user_hr_max = None  # skill will prompt the user

# Always handle missing values gracefully — never crash because a field is null
```

The skill must:
1. Try config.local.json first
2. Use the value if present and non-null
3. Fall back to asking the user if missing
4. Optionally offer to save the answer back to config.local.json for next time

---

## Privacy notes

- `config.local.json` is gitignored — it never leaves the user's machine
- The plugin's `.gitignore` already excludes it
- Calendar IDs and personal physiological data are sensitive — keep them out of the repo

When the plugin is shared/distributed (Phase 7), only `config.example.json` is published as a template.
