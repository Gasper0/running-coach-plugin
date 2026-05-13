---
name: race-strategy
description: Generate a complete km-by-km pacing strategy for a specific race course (5km, 10km, half-marathon, marathon) based on its real elevation profile and the runner's target chrono. Use when the user shares a GPX file, elevation screenshot, course URL (OpenRunner, Strava routes, Komoot), or mentions a specific course they want to plan how to run. Trigger phrases include "stratégie de course", "plan de course", "pacing strategy", "split strategy", "j'ai le parcours de ma course", "voici le tracé", "comment gérer ce parcours", "stratégie pour mon 10km/semi/marathon", "race plan". DO NOT trigger for creating training plans (use training-planner), modifying single workouts (use workout-builder), weekly progress reviews (use training-tracker), race-week nutrition/protocol (use race-week). Hyrox, trail, and ultra are out of scope.
---

# Race Strategy

Build a personalized km-by-km race strategy for a specific course, based on its real elevation profile and the runner's target chrono.

## When to use this skill

**Trigger for:**
- User shares a GPX file in a running context
- User shares a screenshot of an elevation profile
- User shares a URL to OpenRunner, Strava routes, Komoot, or similar
- User asks for a pacing strategy, race plan, or split plan for a specific race
- User mentions an upcoming race with a target time and wants to know how to pace it

**Distances supported:** 5km, 10km, half-marathon, marathon.
**Out of scope:** Hyrox (different pacing logic), trail, ultra.

**Do NOT trigger for:**
- Creating a training plan → use `training-planner`
- Modifying or creating a single workout → use `workout-builder`
- Weekly review of training → use `training-tracker`
- Race-week nutrition or protocol (J-7 to J0) → use `race-week`

## Execution context detection

**Before producing the strategy deliverable**, detect the execution context:
- **If `show_widget` tool is available** (Claude.ai web) → use visual widget (Path A below)
- **If `show_widget` is unavailable** (Claude Code CLI, API) → use structured markdown fallback (Path B below)

Both formats present the same strategy; only the rendering of splits and elevation profile differs.

## Workflow — 4 sequential steps

Don't skip steps — each one informs the next.

### Step 1 — Acquire the course profile

The user can provide the course in one of three formats. Priority order if multiple are available:

1. **GPX file** (best — exact data) → use `scripts/parse_gpx.py` to extract km-by-km altitude
2. **Elevation profile screenshot** → read the image directly, estimate altitudes at each km marker
3. **URL** (OpenRunner, Strava routes, Komoot, etc.) → use `web_fetch`. If the page renders the profile in JavaScript and the data isn't in the HTML, ask the user for a screenshot of the profile.

If none is provided yet, ask which format the user has. Don't try to guess the profile.

For each km, you need: altitude (meters) at start of km. The GPX script returns this automatically. For images, sample visually every km and note the trend.

Read `references/input-parsing.md` for detailed instructions on each format.

### Step 2 — Get target chrono and runner context

Before generating the strategy, ALWAYS ask the user for their target chrono — even if you can infer it from context. Phrasing example: "Quel chrono cible vises-tu pour cette course ?"

If the user asks the skill to **suggest** a realistic chrono instead of providing one:
- Check `config.local.json` for `performance_history` — recent PBs are the best baseline
- Otherwise, ask for their recent PB on a similar or shorter distance
- Ask for their current weekly volume and fitness state
- Then propose a realistic target (and a stretch target) — but still confirm the chosen chrono before proceeding

Optional context to capture if mentioned by the user — these are conditional adjustments, never asked proactively:

- **Weather**: > 22°C → splits adjusted +3 to +5 sec/km. Wind, rain noted in tactical notes.
- **Shoes**: training shoes → no adjustment. Carbon racers → no adjustment (target is for race conditions). Trail/heavy shoes → +5 to +10 sec/km.
- **Surface**: track → ideal. Road flat → ideal. Road urban with intersections → noted in tactical notes. Hilly road → already in profile.
- **Altitude**: > 1500m → +5 sec/km per 1000m above sea level.

If user mentions any of these, integrate the adjustment into splits and mention it explicitly in tactical notes. Otherwise, generate as-is.

### Step 3 — Build the strategy

Read `references/strategy-calibration.md` for the full pacing logic. The high-level rules:

- **Maintain effort, not pace, on climbs.** Accept slower splits on uphills, recover on descents.
- **Conservative km 1.** Adrenaline + crowd → start 4–5 sec/km slower than target, even on flat profiles.
- **Negative split when possible.** The second half should average equal to or faster than the first.
- **Final km commits to the finish.** Last km should be 2–4 sec/km faster than target if reserves allow.

The cumulative time of all splits MUST match the target chrono within ±5 seconds. Adjust upward or downward if needed.

### Step 4 — Generate the deliverable

Two outputs, always together, never one without the other.

#### Path A — Visual widget (when `show_widget` available)

Use `visualize:show_widget` with `read_me(modules=["chart", "data_viz"])` first. The widget contains:

1. **Section "Profil altimétrique"** — 4 metric cards: distance, D+, main climb location, target chrono
2. **Elevation chart** — Chart.js line/area chart with color-coded zones matching the strategy phases
3. **Section "Splits cibles"** — table with km, allure, color tag (Conservateur / Allure cible / Montée / Descente / Finish)
4. **Section "Points clés tactiques"** — 4–6 bullets with concrete advice per phase

Read `references/widget-template.md` for the exact code template — reuse it as a base, adapting only the data.

#### Path B — Structured markdown fallback (when `show_widget` unavailable)

If the widget tool is not available, produce the strategy in this exact markdown format:

```
## 🏁 [Distance] [Course name] — Stratégie chrono cible [HH:MM:SS]

### Profil altimétrique
| Métrique | Valeur |
|---|---|
| 🏃 Distance | [X.X] km |
| ⛰ D+ total | [N] m |
| 📍 Montée principale | km [start] - km [end] (+[N]m) |
| 🎯 Chrono cible | [HH:MM:SS] |

### Splits cibles
| Km | Altitude | Allure | Zone | Notes |
|---|---|---|---|---|
| 1 | 45 m | 4:25/km | 🔵 Conservateur | Départ contrôlé, ne pas s'emballer |
| 2 | 47 m | 4:18/km | 🟢 Allure cible | Installer le rythme |
| 3 | 62 m | 4:35/km | 🟠 Montée | Maintenir l'effort, accepter la perte de tempo |
| 4 | 78 m | 4:42/km | 🟠 Montée | Continuer en effort |
| 5 | 65 m | 4:08/km | 🟢 Descente | Récupération active, profiter |
| ... | ... | ... | ... | ... |
| 10 | 50 m | 4:05/km | 🔴 Finish | Tout donner sur le dernier km |

**Total cumulé : [HH:MM:SS]** ([±N sec vs cible])

### Points clés tactiques
- **Km 1-2** : départ contrôlé, [contexte]
- **Km 3-4** : gestion de la montée principale, [stratégie]
- **Km 5-6** : récupération active sur la descente
- **Km 7-9** : maintien de l'allure cible, attention au mental
- **Km 10** : finish complet
```

Use the same emojis and color codes as the widget for visual consistency across surfaces.

#### Mental preparation guide (always required, both paths)

This is the personalized part. Read `references/mental-prep.md` for the full pattern library.

The mental guide MUST be tied to the specific course features identified in Step 1, not generic. For each course-specific moment that requires mental management, write a paragraph addressing:

- **Where** (km X — describe the physical feature: "the gentle climb between km 5 and 7")
- **What happens** (physiological / psychological challenge: "the legs start protesting, the breathing feels shorter")
- **Mental cue** (concrete instruction the runner can recall during the race: "tell yourself 'I maintain effort, not pace — the descent is coming'")

Include 3–5 such paragraphs covering: race start, mid-race critical moments specific to this profile, the final push.

## Optional V2 — Garmin Pace Pro export

Not implemented in V1. When the user requests it, generate a CSV-formatted target pace per km that they can manually input into Garmin Connect's Pace Pro feature.

## References

- [`references/input-parsing.md`](references/input-parsing.md) — GPX/image/URL parsing details
- [`references/strategy-calibration.md`](references/strategy-calibration.md) — km-by-km pacing logic
- [`references/widget-template.md`](references/widget-template.md) — full widget code template (Path A only)
- [`references/mental-prep.md`](references/mental-prep.md) — mental preparation patterns
- [`scripts/parse_gpx.py`](scripts/parse_gpx.py) — extract km-by-km altitude from GPX

## Coordination with other skills

- If the user is in race-week (J-7 to J0) → `race-week` may have triggered already with race-week nutrition/protocol. This skill is complementary, focused only on pacing.
- If the user wants to know how their training prepared them for this course → activate `training-tracker` afterwards
- For modifying the training plan based on the race profile → handoff to `training-planner` or `workout-builder`

## Skill scope (final state)

```
race-strategy/
├── SKILL.md
├── references/
│   ├── input-parsing.md
│   ├── strategy-calibration.md
│   ├── widget-template.md
│   └── mental-prep.md
└── scripts/
    └── parse_gpx.py
```
