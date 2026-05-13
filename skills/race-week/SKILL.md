---
name: race-week
description: Race-week protocol for a running event happening in the next 1-7 days. Covers nutrition, hydration, sleep, taper, activation sessions, equipment checklist, and race-morning routine, all adapted dynamically to the race distance (10km / half-marathon / marathon / Hyrox). Trigger phrases include "ma course est dans [1-7] jours", "ma course est ce week-end", "nutrition course", "que manger avant ma course", "checklist veille de course", "activation jour de course", "préparation dossard", "j'ai un [10km/semi/marathon/Hyrox] dimanche". DO NOT trigger for race-day pacing strategy (use race-strategy), creating new training plans (use training-planner), weekly progress reviews (use training-tracker), or creating individual workouts (use workout-builder).
---

# Race Week

## Purpose

Deliver a structured race-week protocol covering the 7 days before a race. The protocol adapts to the distance — a 10km does not require the same approach as a marathon. Always output a visual checklist via `show_widget` (no plain markdown fallback).

## When to use this skill

**Trigger for:**
- "ma course est dans [1-7] jours" / "ma course est ce week-end"
- "j'ai un [10km/semi/marathon/Hyrox] dimanche"
- "nutrition course" / "que manger avant ma course"
- "checklist veille de course"
- "activation jour de course"
- "préparation dossard"

**Do NOT trigger for:**
- Pacing strategy / km-by-km plan → use `race-strategy`
- Creating new training plans → use `training-planner`
- Weekly review of training → use `training-tracker`
- Creating/modifying individual workouts → use `workout-builder`

## Inputs needed

Before producing anything, confirm with the user:

1. **Race date** — exact date (mandatory). Compute J-7 to J0 from there.
2. **Race distance** — 10km / semi / marathon / Hyrox. Defines which protocol applies.
3. **Race start time** — used to backtime the race-morning routine (breakfast 3h before, etc.)
4. **Hyrox-specific** — if Hyrox, ask the format (Solo / Doubles / Pro)

Do not produce the protocol without these inputs. The advice changes meaningfully between distances.

## Protocol adapted by distance

The principle: longer distances need more glycogen loading, more taper, more hydration. Shorter distances need less of everything except readiness.

Full details for each distance in `references/nutrition-protocols.md`. Below is the summary.

### 10km

**Taper**: 4-5 days. Last quality session at J-4 or J-5, then easy volume only.
**Glycogen loading**: not required. Normal diet, slightly higher carbs J-1.
**Final sessions**:
- J-2: easy run 25-30 min
- J-1: rest or 15 min activation with 3-4 strides
**Race-morning breakfast** (3h before): 60-80g carbs + light protein.

### Half-marathon (21 km)

**Taper**: 7 days. Volume reduced 30%, intensity preserved until J-4.
**Glycogen loading**: moderate. Carbs at ~7-8 g/kg J-2 and J-1.
**Final sessions**:
- J-3: short session with 4-6 strides at race pace
- J-2: easy 30 min + 3-4 strides
- J-1: rest or 15-20 min activation
**Race-morning breakfast** (3h before): 80-100g carbs + light protein.

### Marathon (42 km)

**Taper**: full 2-3 weeks (already handled by `training-planner`). Race-week is the final touch.
**Glycogen loading**: full. Carbs at 10-12 g/kg/day from J-3 to J-1.
**Final sessions**:
- J-5: last medium session (45 min easy + short tempo)
- J-3: easy 30 min + 2-3 strides at marathon pace
- J-2: easy 25 min
- J-1: rest or 15 min activation
**Race-morning breakfast** (3h before): 100-130g carbs + minimal protein/fiber.

### Hyrox

**Taper**: 7 days, similar to half-marathon but preserves some station work.
**Glycogen loading**: moderate. Carbs at 7-8 g/kg J-2 and J-1. **Plus** maintain protein at 1.6-2.0 g/kg (stations are muscular work).
**Final sessions**:
- J-4: last Run Brick session, reduced intensity (3 rounds × 1 station)
- J-2: easy run 25 min + 2-3 stations at moderate effort
- J-1: rest or mobility 15 min
**Race-morning breakfast** (2.5-3h before): 80-100g carbs + 20-25g protein.
**Specific note**: Hyrox demands explosive power on stations — avoid heavy fiber the day before (digestion under load).

## Rules common to all distances

These apply regardless of distance:

### Hydration

- J-3 to J-1: target 35-40 ml/kg/day water (urine pale yellow, not transparent)
- J-1 evening: add electrolytes (sodium 500-700mg)
- Race-morning: 400-500ml water 2h before, then sip until 30min pre-race

### Sleep

- Target 8h on J-2 (sleep banking matters more than J-1)
- J-1 sleep is often disturbed — that's normal, don't stress about it
- No alarms earlier than necessary on race morning

### Foods to AVOID J-3 to J0

- Anything you haven't eaten before during training (no experimentation)
- High-fiber foods (raw vegetables, whole grains, legumes) on J-1
- Alcohol from J-3 onwards (the user has noted: alcohol = -15 to -25 points on Garmin sleep score, direct impact on resting HR and recovery)
- Spicy foods, very fatty foods on J-1
- New caffeine doses or types — keep what's habitual

### Mental preparation

Encourage the user to:
- Visualize the start, the middle (where it gets hard), and the finish
- Have a mantra ready for the tough km (race-strategy skill can help build pacing-anchored mantras)
- Plan for the worst-case (rain, side stitch, GI distress) — knowing the response reduces panic

### Equipment checklist (J-1)

The user prepares the night before:
- [ ] Bib + safety pins / race number belt
- [ ] Shoes (the ones tested in training, not new)
- [ ] Race kit (top, bottoms, socks tested)
- [ ] GPS watch charged (>80%)
- [ ] Energy gels/products (if applicable — quantity by distance)
- [ ] Anti-chafing (vaseline, body glide)
- [ ] Sunscreen if relevant
- [ ] Warm-up clothes for after the race
- [ ] Phone charged, transport plan to the start
- [ ] Cash + ID + transport pass

## Output: visual race-week widget — REQUIRED

Always conclude the protocol with a `visualize:show_widget` call. Never deliver as plain markdown only.

The widget must contain, in this order:

1. **Header banner** — distance, race date, time remaining (e.g. "🏁 Marathon Paris — Dimanche 21 sept. — J-5")

2. **7-day timeline grid** (J-7 to J0 as columns, rows as themes):
   - Row 1 — 🏃 Training: session for that day (or "rest")
   - Row 2 — 🍝 Nutrition: focus of the day (e.g. "Normal", "↑ Carbs", "Carb loading J-3")
   - Row 3 — 💧 Hydration: target ml/day
   - Row 4 — 😴 Sleep: target hours + reminder

3. **Race-morning timeline card** — backtimed from the race start hour:
   - Wake up
   - Breakfast (with macros)
   - Last bathroom break
   - Travel to start
   - Bag check
   - Warm-up
   - Final hydration sip
   - Race start

4. **Equipment checklist** — visual to-do list with checkboxes, generated from the section above + Hyrox-specific items if applicable

5. **Foods to avoid banner** — red-tinted card with the J-3 to J0 prohibitions

6. **Mental cues card** — 2-3 short, personalized cues based on the distance and the user's known weaknesses (from training-tracker history if available)

Refer to `visualize:read_me` with module `interactive` before building the widget.

## Coaching rules to enforce (user-specific)

### No experimentation in the final 3 days

If the user mentions trying a new gel, new shoes, new pre-race ritual, **flag this strongly**. The race day is not the day to test new things — every new variable is a risk of GI distress, blisters, or unexpected fatigue.

### Hyrox-specific: protein in race-week is non-negotiable

For Hyrox events, the user must maintain 1.6-2.0 g/kg protein even during carb loading. Stations require muscular work — under-fueled muscles can't sled push or wall ball at intensity.

### Alcohol pattern recognition

If the user mentions alcohol consumption in race-week (especially J-3 to J-1), reference their known data: "Tu m'as déjà mentionné que 1 pinte le soir = -15 à -25 points sur ton score sommeil Garmin et impact direct sur ta FC repos. À 3 jours d'une course, c'est un coût mesurable."

### Travel + race = extra rest

If the user is racing in another city (e.g. Hyrox in Brussels, Toulouse), add 1h of sleep on J-2 and J-1, and avoid heavy meals during travel. Mention this if travel context is visible.

### J-1 stress management

If the user expresses anxiety about the race in the conversation, validate it ("c'est normal et même bon signe — ça veut dire que la course compte"), then redirect to controllable items: equipment ready, food planned, sleep prioritized. Do not minimize, but don't dramatize.

## References

- [`references/nutrition-protocols.md`](references/nutrition-protocols.md) — detailed nutrition protocols per distance with macronutrient targets and meal examples
- [`../_shared/session-schema.md`](../_shared/session-schema.md) — session schema for any final sessions referenced

## Coordination with other skills

- If the user asks about pacing for the race itself → activate `race-strategy` in parallel
- If the user reports recovery data after a race-week session → activate `training-tracker` if they ask for a review, but the race-week timeline takes priority during the 7-day window
