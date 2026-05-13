# Export Workflow

> Rules for differentiated export between calendar (all-at-once) and Garmin (week-by-week).
> This separation is intentional — read this before pushing anything.

---

## Core principle

The user wants two different things from the two targets:

| Target | Purpose | Push strategy |
|---|---|---|
| Calendar (GCal/.ics) | See the whole plan at a glance | Push the entire plan duration at once |
| Garmin Connect | Run today's workout | Push only the current week, refresh weekly |

This split avoids two anti-patterns:
- Cluttered Garmin watch with 12 weeks of upcoming workouts (intimidating, demotivating)
- Empty agenda where the user can't see what's coming (loses the roadmap view)

---

## Calendar export — full plan, one push

### When

At plan creation (Stage 6 of `training-planner`), after the user validates the plan structure.

### What gets pushed

- One calendar event per session for the entire plan duration (typically 6-18 weeks)
- Title format: `[emoji] [code] [brief session title]` (e.g., "🔴 FR 5×1000m seuil")
- Color matching the session type (see `../../_shared/session-schema.md`)
- Description: full workout structure (warmup → main → cooldown), coaching notes, target paces, target HR
- Hashtag at the end of description (e.g. `#marathon-paris-2026`) for plan-wide filtering
- Default start time: 7am for morning, 6pm for evening (configurable in `config.local.json`)
- Duration: estimated session duration

### Tools

- **Google Calendar**: use `google-calendar:create-event` for each session
- **.ics fallback**: generate a single `.ics` file with all events, save to `/mnt/user-data/outputs/`, present for download

### Critical settings for Google Calendar

- `calendar_id`: from `config.local.json` → `integrations.google_calendar.training_calendar_id`
- `sendUpdates`: always `"none"` — do not notify guests / send invites
- Color: from the session type table in `../../_shared/session-schema.md`

### Calendar refresh

Once the plan is in the calendar, the user does NOT need to re-push to calendar on a weekly basis. Calendar = static reference. Modifications (move a session, change a session type) flow through `workout-builder`, which updates the corresponding calendar event in place.

---

## Garmin export — current week only

### When

1. At plan creation (Stage 6 of `training-planner`), push **only week 1**
2. At the start of each subsequent week, the user explicitly asks "pousse la semaine X sur Garmin"
3. After plan modifications via `workout-builder`, only the affected workout is pushed

### Why not push the whole plan?

- The Garmin watch interface shows scheduled workouts as a list — 60+ entries becomes unusable
- The user only runs today's session, not next month's — pre-pushed workouts are noise
- Modifications happen often (rescheduling, intensity adjustments) — pushed workouts become stale fast
- Deleted/replaced workouts leave traces that need cleanup

### What gets pushed for "the current week"

For each running session in the upcoming 7 days:
1. `garmin:create_workout` with the structured workout (steps with pace/HR targets, repeat blocks, rest steps)
2. Capture the returned `workout_id`
3. `garmin:schedule_workout` with that `workout_id` on the session date
4. Move to the next session

Skip non-running sessions: rest days, strength sessions, mobility — Garmin doesn't represent them well. They stay in the calendar only.

### Garmin formatting rules

Use the rules from `../../workout-builder/references/garmin-workout-rules.md`. Quick reminder:
- Pace as integer seconds-per-km (242 = 4:02/km)
- HR as integer bpm
- Repeat blocks are flat — `3×(5×400m)` is three sequential repeat blocks, not nested
- Mandatory `rest` step with `duration_type: "open"` between warmup and main block
- Never call `schedule_workout` twice on the same workout

### Weekly push command

When the user says "pousse la semaine 3 sur Garmin":
1. Identify week 3 in the plan (from calendar events or memory)
2. Optionally: delete the previous week's workouts that were completed (`garmin:list_workouts` → `garmin:delete_workout`)
3. For each running session in week 3, run the create + schedule sequence
4. Confirm with a summary

This is intentionally a brief, focused command — not a full re-engagement of `training-planner`. Output format:

```
✅ Semaine 3 poussée sur Garmin

📅 Semaine du 28 sept. au 4 oct.

🏃 Séances créées :
  • Mardi 30 — 🔴 FR VMA 6×800m (workout_id: 12345)
  • Jeudi 2 — 🟠 AS Tempo 30min (workout_id: 12346)
  • Dimanche 5 — 🔵 SL 18km Z2 (workout_id: 12347)

🧹 Nettoyage : 3 workouts complétés supprimés de la semaine 2.
```

---

## .ics export — fallback for calendar

### When to offer .ics

- The user doesn't have Google Calendar MCP configured
- The user prefers an offline file they can import to any calendar app (Apple, Outlook, etc.)
- The user wants to share the plan with someone else

### How

Generate a single `.ics` file containing all events for the plan duration. Same content rules as Google Calendar (titles, descriptions, colors via category, hashtags).

Save to `/mnt/user-data/outputs/training-plan.ics`. Present via `present_files` so the user can download.

The user imports the file into their calendar of choice manually.

---

## Optional exports — Excel, Word/PDF

These are not part of the default workflow. Only generate if the user explicitly asks ("donne-moi le plan en Excel", "génère un PDF du plan").

Reference files exist for documentation:
- `excel-export.md` — Excel structure with multi-week sheet, summary tab
- `docx-export.md` — Word format with periodization summary and weekly tables

Output to `/mnt/user-data/outputs/`, present via `present_files`.

---

## Coordination with other skills

- `workout-builder` modifies individual sessions. When it does, it updates **both** Garmin (if the session is in the current/pushed week) **and** the calendar event. The skill takes care of cross-target consistency.
- `training-tracker` reads the calendar to know what was planned vs what was actually done. It does not modify the calendar — only suggests adjustments that the user validates and then sends back to `workout-builder` for execution.
- `race-week` does NOT touch the plan structure — it overlays a race-week protocol on the existing taper week.

---

## Error handling

If Google Calendar MCP is not available:
- Fall back to `.ics` automatically and explain to the user
- Save the file, present it, give import instructions

If Garmin MCP is not available:
- Push to calendar only (no Garmin push)
- Tell the user explicitly: "Plan dans ton agenda. Garmin pas accessible — tu liras les séances dans Calendar / .ics pour cette semaine."
- Document the missing MCP in case the user wants to set it up

If both fail:
- Save a `.ics` file as the unique source of truth
- Provide the structured plan in text form in the conversation as backup
