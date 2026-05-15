---
name: training-planner
description: Create a complete periodized running training plan from scratch, with personalized intake interview, physiological zone calculation, weekly structured plan, and exports to Garmin Connect (week-by-week) and Google Calendar / .ics (full plan). Use ONLY for initial plan creation, not for modifications or follow-up. Trigger phrases include "prépare-moi pour un [10km/semi/marathon/Hyrox]", "j'ai une course dans X semaines/mois", "génère-moi un plan d'entraînement", "I want to prepare for a [race]", "build me a training plan for [event]". DO NOT trigger for weekly progress reviews (use training-tracker), modifying or creating single workouts (use workout-builder), race-week protocol (use race-week), or race-day pacing strategy (use race-strategy).
---

# Training Planner

## Purpose

Build a personalized, periodized training plan for a target running race (10km, half-marathon, marathon, or Hyrox). The workflow is end-to-end: intake → zones → plan → exports. Once delivered, the plan lives in the user's calendar and on their Garmin watch. Subsequent modifications go through `workout-builder`; weekly reviews go through `training-tracker`.

## When to use this skill

**Trigger for plan creation only:**
- "prépare-moi pour un [10km / semi / marathon / Hyrox]"
- "j'ai une course dans X semaines/mois, je veux préparer"
- "génère-moi un plan d'entraînement"
- "build me a training plan for [event]"

**Do NOT trigger for:**
- Modifying or moving an existing session → use `workout-builder`
- Creating a one-off workout → use `workout-builder`
- Reviewing the past week's training → use `training-tracker`
- Race-week protocol (1-7 days before race) → use `race-week`
- Pacing strategy for the race itself → use `race-strategy`

If the user already has a plan and wants to adjust it, redirect them to the appropriate skill rather than rebuilding from scratch.

## Execution context detection

**Before starting Stage 1, detect the execution context** to pick the right intake method:

- **If `show_widget` tool is available** (typically Claude.ai web, Cowork) → use Path A (interactive widget)
- **If `show_widget` is unavailable** (typically Claude Code CLI) → use Path B (structured text protocol)

Both paths collect the same information; the format and UX differ.

**Also check Garmin MCP availability**, which affects Stage 6 only:
- Garmin MCP available (Cowork, Claude Code) → full export workflow with calendar + Garmin push
- Garmin MCP unavailable (claude.ai web) → calendar export only; Garmin push deferred to Cowork

This is mentioned to the user at Stage 6 if needed, not earlier.

## Workflow — 6 stages, in order

### Stage 1 — Intake interview

#### Path A: Interactive widget (preferred when available)

Render the intake widget at `references/intake-widget.html` via `show_widget`. The widget collects all required inputs through chips and form fields, then submits a structured summary via `sendPrompt`.

Wait for the user to submit the widget. Use the returned summary as authoritative input for the next stages.

#### Path B: Structured text protocol (fallback)

If `show_widget` is not available, ask the questions in **5 grouped blocks**. Present all blocks at once, let the user answer freely (in bulk or detailed), then structure the response yourself before moving to Stage 2.

**Block 1 — Race target** (required)
1. Distance: 10km / semi-marathon / marathon / Hyrox
2. Race date (YYYY-MM-DD or "dans X semaines")
3. Time goal: target chrono (HH:MM:SS) OR "just finish" OR "improve from previous chrono"
4. For Hyrox: format (Solo / Doubles / Pro) and previous Hyrox time if any

**Block 2 — Runner profile** (required)
1. Running experience: < 6 months / 6 months–1 year / 1–3 years / 3–5 years / 5+ years
2. Current weekly volume (km/week, rough estimate is fine)
3. Best recent time (within last 12 months): distance + chrono (e.g. "10km en 44:00")
4. Lifestyle activity: sedentary / moderately active / very active

**Block 3 — Availability** (required)
1. Sessions per week: 2 / 3 / 4 / 5+
2. Available days: list (e.g. "Tue, Thu, Sat, Sun")
3. Max duration per session in week: < 45min / 45-60min / 60-90min / 90min+
4. Preferred time of day: morning / midday / evening / flexible
5. Cross-training: strength, cycling, swimming, yoga (which days?)

**Block 4 — Physiology** (required for accurate zones)
1. Age
2. Biological sex (for HR max estimation)
3. Weight (kg, optional)
4. Height (cm, optional)
5. HR data known: resting HR? max HR? VMA?
6. Preferred terrain: road / trail / track / treadmill
7. Current or recent injuries (optional but important)

**Block 5 — Recovery and exports**
1. Recovery quality: very good / decent / moderate / poor
2. GPS watch: Garmin / Apple / Polar / Suunto / Coros / none
3. Desired exports: Google Calendar / Garmin Connect / .ics file / Excel / Word/PDF
4. Other context: travel constraints, schedule constraints, special preferences

Tell the user: "Réponds en vrac ou en détail, je structure ensuite. Tous les blocs ne sont pas obligatoires — ceux marqués 'required' suffisent pour démarrer."

After the user responds, **summarize what you understood** in a structured format and ask for confirmation before moving to Stage 2.

### Stage 2 — Calculate physiological zones

Compute the user's training zones from inputs in priority order:

1. **From `config.local.json`** if it exists and contains `training_zones` — use those values directly
2. **From a recent race time** (10km, semi, marathon) — apply VDOT method, see `../_shared/vdot-paces.md`
3. **From an estimated VMA** (Garmin or test) — derive paces from VMA percentages
4. **From age-based defaults** (Tanaka formula for FC max) — last resort, flag this as low-confidence

Always present the computed zones to the user for validation before proceeding. Allow override.

### Stage 3 — Build the periodized plan structure

Determine the plan length (weeks until race) and divide into phases. See `references/periodization.md` for the full ruleset.

Default phase structure:

| Distance | Total weeks | Base | Build | Peak | Taper |
|---|---|---|---|---|---|
| 10km | 6-10 | 2-3 | 2-3 | 2 | 1 |
| Semi | 10-12 | 3 | 3-4 | 2-3 | 1-2 |
| Marathon | 14-18 | 4-5 | 5-6 | 3 | 2-3 |
| Hyrox | 8-12 | 2-3 | 3-4 | 2-3 | 1 |

Apply the 10% rule: weekly volume increases by no more than 10% from one week to the next.

### Stage 4 — Fill in each week's sessions

For every week, generate sessions following the user's weekly structure (e.g., quality Tue/Thu, long run Sun, rest Mon). Reference `references/session-library.md` for session templates by phase and intensity.

For each session, build the standard schema (see `../_shared/session-schema.md`).

For Hyrox plans, include a "Run Brick" session type once a week (running + 1-2 stations). Do NOT generate detailed station protocols here — the user uses `workout-builder` for that level of detail.

### Stage 5 — Present the plan for validation

Before any exports, show the user:
- Phase-by-phase summary (weeks per phase, focus, volume targets)
- Week-by-week table (sessions, distances, durations)
- Total volume across the plan
- Key sessions (peak workouts, marathon-pace workouts, etc.)

If `show_widget` available: use a `show_widget` table format with color coding from `../_shared/session-schema.md`.

If not available: use a structured markdown summary with phase breakdown table and week-by-week table.

Wait for explicit user validation ("c'est bon, on pousse") in both paths.

### Stage 6 — Exports (CRITICAL — workflow differs by target AND by surface)

The export strategy is **deliberately different** between calendar and Garmin, see `references/export-workflow.md` for full rules.

#### Calendar (Google Calendar OR .ics) — full plan, push all at once

Calendar export works on **all surfaces** because Google Calendar MCP is a remote MCP (cloud-based), available on claude.ai web, Cowork, and Claude Code.

- Generate all events for the entire plan duration
- Push to Google Calendar via MCP, or generate a single `.ics` file for download
- Color-code by session type, add hashtag (e.g. `#marathon-paris-2026`)

#### Garmin Connect — current week only, refresh weekly (surface-dependent)

Garmin push works on **Cowork or Claude Code only** (Garmin MCP is a local stdio server).

**If Garmin MCP available** (Cowork, Claude Code):
- Push only the current week's structured workouts to Garmin
- At the start of each new week, the user will ask the skill to push the next week
- Quick command: "pousse la semaine 3 sur Garmin"

**If Garmin MCP NOT available** (claude.ai web):
- Skip the Garmin push step at plan creation
- Tell the user explicitly: "Le plan est dans ton agenda (✓ tout le programme). Pour le push Garmin (semaine 1), bascule sur **Cowork** quand tu seras prêt à attaquer — je pousserai la semaine en cours sur ta montre."
- The plan can still be fully created and validated; only the watch-side activation is deferred

For Garmin pushes when available, use the rules from `workout-builder/references/garmin-workout-rules.md`.

After initial creation, end the session with a reminder appropriate to the surface:
- On Cowork/Claude Code: "Le plan complet est dans ton agenda. Pour Garmin, je n'ai poussé que la semaine 1. Dis-moi 'pousse la semaine 2 sur Garmin' au début de la semaine prochaine."
- On claude.ai web: "Le plan complet est dans ton agenda. Pour activer la semaine 1 sur Garmin, bascule sur Cowork et demande 'pousse la semaine 1 sur Garmin'."

### Optional exports (on demand only)

Excel/CSV, Word/PDF — only if the user explicitly asks. Don't propose proactively.
- `references/excel-export.md`
- `references/docx-export.md`

## Coaching rules to enforce

### Conservative zones for first plans

If this is the user's first plan with the assistant (no `config.local.json` yet), default to **conservative pace zones**. It's easier to revise upward after one cycle than to break down from too-aggressive targets. Specifically:
- Threshold: 10km PB pace + 12-18 s/km (not + 5 s/km)
- VMA: derived from 1.5km test or 3000m PR, not extrapolated from 10km

### Quality session protection

Place quality sessions (VMA, threshold) on days with fresh legs. Default order:
- Mardi: VMA or threshold (after rest day)
- Jeudi: threshold or tempo (mid-week)
- Dimanche: long run (low intensity but high volume)

**Never place a quality session within 48h of another.**

### Cross-training interference

If the user does strength training (especially leg work), do NOT schedule it the day before VMA. Strength legs goes on Saturday to enable a back-to-back stimulus useful for Hyrox prep. Avoid Monday strength legs (kills Tuesday VMA).

### Hyrox + running combo

If the user is preparing both a Hyrox event and a running race in parallel, prioritize the proximity-priority race. Defer the secondary objective by reducing its quality block intensity.

### Volume progression — strict 10% rule

Never increase weekly volume by more than 10% versus the previous week, **except** for stepback weeks (every 3-4 weeks, reduce by 25-30% to recover). Stepback weeks are mandatory in plans longer than 8 weeks.

### Recovery week placement

In plans of 10+ weeks, insert a recovery week every 3-4 weeks. Volume drops 30%, intensity preserved at low dose.

## Required inputs and tools

### MCP tools used
- **`google-calendar:list-calendars`** + **`google-calendar:create-event`** — for calendar exports (all surfaces)
- **`garmin:create_workout`** + **`garmin:schedule_workout`** + **`garmin:list_workouts`** — for Garmin pushes (Cowork, Claude Code only)
- **`show_widget`** (when available) — for the intake widget and plan validation widget

### File inputs
- `config.local.json` at the plugin root (optional but recommended) — see `../_shared/config-schema.md`

## References

- [`references/intake-widget.html`](references/intake-widget.html) — interactive intake form (Path A only)
- [`references/periodization.md`](references/periodization.md) — phase structure rules, stepback weeks, distance-specific patterns
- [`references/session-library.md`](references/session-library.md) — session templates by phase and type
- [`references/export-workflow.md`](references/export-workflow.md) — calendar (all-at-once) vs Garmin (week-by-week) workflow rules
- [`references/garmin-export.md`](references/garmin-export.md) — Garmin-specific export details
- [`references/google-calendar-export.md`](references/google-calendar-export.md) — GCal event format, colors, hashtags
- [`references/ics-export.md`](references/ics-export.md) — .ics file generation as fallback
- [`../_shared/session-schema.md`](../_shared/session-schema.md) — standard session schema (single source of truth)
- [`../_shared/vdot-paces.md`](../_shared/vdot-paces.md) — pace zone calculation from race times
- [`../_shared/config-schema.md`](../_shared/config-schema.md) — config.local.json schema for personal values

## Handoff to other skills

Once the initial plan is delivered:
- **For weekly reviews** → user activates `training-tracker` with "bilan de la semaine"
- **For modifying a session** → user activates `workout-builder` with "modifie ma séance de [jour]"
- **For the next Garmin push** → user activates this skill briefly with "pousse la semaine X sur Garmin" (requires Cowork or Claude Code)
- **For race-week protocol** (J-7 to J0) → user activates `race-week`
- **For race-day pacing** → user activates `race-strategy`

Mention these handoffs at the end of the initial plan delivery, so the user knows where to go next.
