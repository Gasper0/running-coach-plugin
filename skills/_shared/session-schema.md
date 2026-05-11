# Standard Session Schema

> Single source of truth for session representation across all skills and exports in the plugin.
> Any skill that emits or consumes a session **must** follow this schema.

---

## Session Type Reference Table

| `session_type` | `code` | Display (FR) | Display (EN) | Emoji | GCal Color | Hex Fill |
|---|---|---|---|---|---|---|
| `easy` | EF | Sortie facile | Easy run | 🟢 | Sage (2) | `#C8E6C9` |
| `long_run` | SL | Sortie longue | Long run | 🔵 | Blueberry (9) | `#BBDEFB` |
| `tempo` | AS | Tempo / Seuil | Tempo run | 🟠 | Tangerine (6) | `#FFE0B2` |
| `intervals` | FR | Fractionné / VMA | Intervals | 🔴 | Tomato (11) | `#FFCDD2` |
| `strength` | RM | Renforcement | Strength | 💪 | Grape (3) | `#E1BEE7` |
| `recovery` | RA | Récupération active | Active recovery | 🧘 | Graphite (8) | `#F5F5F5` |
| `race` | RACE | Course | Race day | 🏆 | Banana (5) | `#FFF9C4` |
| `rest` | REST | Repos | Rest day | 😴 | — (skip) | `#FFFFFF` |
| `hyrox` | HYROX | Hyrox fonctionnel | Hyrox session | 🏋️ | Flamingo (4) | `#FFE0B2` |

All exports (ICS, Excel, Word/PDF, Garmin FIT, Google Calendar, Nolio) must consume this table for emoji, colors, and naming. When building sessions internally, always use `session_type` (lowercase snake_case) as the primary key.

---

## Standard Session Data Schema

Every session dictionary must follow this schema:

```python
{
    "date": date,              # datetime.date object
    "week": int,               # week number in the plan (1-based)
    "phase": str,              # "Base" | "Build" | "Peak" | "Taper"
    "session_type": str,       # from reference table: "easy" | "long_run" | "tempo" | ...
    "code": str,               # from reference table: "EF" | "SL" | "FR" | ...
    "title": str,              # human-readable, e.g. "Sortie facile 45min"
    "duration_min": int,       # total session duration in minutes
    "distance_km": float,      # estimated distance
    "zones": str,              # e.g. "Z1-Z2"
    "pace_target": str,        # e.g. "5:30-6:00 /km"
    "hr_zone": str,            # e.g. "60-75% FC max (111-138 bpm)"
    "description": str,        # full workout instructions (warmup, main, cooldown)
    "notes": str,              # coaching notes
    "start_hour": int,         # default 7 for morning, 18 for evening
    "day_name": str,           # e.g. "Lundi", "Mardi" (in user's language)
}
```

---

## Rules for skills consuming this schema

1. **Never invent a new `session_type`** without adding it to the table above. New types must be added here first, then referenced from the skill.
2. **Always use `session_type` as the primary key**, never the display name (which varies by language).
3. **`code`** is the short uppercase tag used in agenda titles (e.g. "EF 45min", "FR 8×400m"). Always 2-5 characters.
4. **`pace_target` and `hr_zone`** are formatted strings, not numbers. Computation logic for the values lives in `vdot-paces.md`.
5. **`description`** must follow the standard structure: warmup → main block → cooldown. Each section on its own line for readability.
