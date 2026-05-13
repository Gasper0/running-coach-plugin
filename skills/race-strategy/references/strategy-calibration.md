# Strategy calibration — km-by-km pacing logic

## Core principles

1. **Maintain effort, not pace, on climbs.** A 15m climb over 1km costs ~3–5 sec/km at threshold. Accept the loss on the climb and recover on the descent.
2. **Conservative km 1.** Adrenaline + crowd density at the start always pushes runners 5–10 sec/km too fast. Prescribe a deliberate slower km 1 even on flat profiles.
3. **Negative split ideal.** Second half ≤ first half time. The fastest 10km races are usually run with 30–60s negative splits.
4. **Final km is the commitment.** If the runner has executed properly, the last km should be 2–4 sec/km faster than target.
5. **Cumulative time MUST equal target chrono ±5 sec.** Verify and adjust before delivering.

## Pacing rules per phase

### Km 1 — Conservative start
- **Pace adjustment**: target pace + 4 to 6 sec/km
- Example: target 3:42/km → km 1 at 3:46–3:48/km
- This is non-negotiable, regardless of profile

### Km 2 onwards — Pace by profile

For each subsequent km, classify by gradient:

| Gradient | Pace adjustment | Tag |
|----------|----------------|-----|
| Flat (-0.5% to +0.5%) | Target pace exactly | "Allure cible" |
| Gentle uphill (+0.5% to +2%) | +2 to +3 sec/km | "Montée douce" |
| Moderate uphill (+2% to +4%) | +5 to +8 sec/km | "Montée" |
| Steep uphill (>+4%) | +10 to +15 sec/km | "Côte" |
| Gentle downhill (-0.5% to -2%) | -2 to -3 sec/km | "Descente" |
| Moderate downhill (-2% to -4%) | -3 to -5 sec/km | "Descente franche" |
| Steep downhill (>-4%) | -5 to -8 sec/km (controlled, don't blow quads) | "Forte descente" |

Calculate gradient as `(alt_end - alt_start) / 1000` for each km segment.

### Final km — Commitment
- **Pace adjustment**: target pace - 2 to 4 sec/km if reserves allow
- If the final km has uphill, override and run at target pace flat
- Tag: "Finish"

## Phase coloring (for widget)

These match the widget template's color palette:

| Phase | Color | Tag examples |
|-------|-------|-------|
| Km 1 (conservative) | Teal `#1D9E75` | Conservateur |
| Km 2 to mid (target pace flat) | Purple `#7F77DD` | Allure cible |
| Climbs | Amber `#EF9F27` | Montée douce / Montée / Côte |
| Descents | Blue `#378ADD` | Descente / Descente franche |
| Final km | Coral `#D85A30` | Finish |

## Distance-specific notes

### 5km
- Conservative km 1 still applies but smaller (+2 to +3 sec/km)
- More uniform pacing — less profile-driven adjustment
- Final 1–1.5 km is the commitment zone

### 10km
- Standard rules above apply directly
- Mid-race (km 5–7) is the mental + physiological crux

### Half-marathon (21.1 km)
- Conservative start over km 1–2 (not just km 1)
- Real race begins at km 14
- "The wall" sometimes appears at km 17–18 — anticipate in mental prep
- Final 2 km is the commitment zone

### Marathon (42.2 km)
- Conservative over km 1–3
- Target pace from km 4 to km 30
- Km 30–35 is the most critical zone (glycogen depletion)
- If reserves remain, last 2 km can push slightly — but most marathons are about not slowing, not finishing fast

## Optional adjustments

These are applied on top of the base strategy if the user mentions them:

### Heat (>22°C)
- Add +3 sec/km for 22–26°C
- Add +5 sec/km for 26–30°C
- Add +8 to +10 sec/km for >30°C
- Apply uniformly across all splits
- Add hydration note in tactical bullets

### Wind
- Headwind on a section → +3 to +5 sec/km on that section
- Tailwind → no adjustment (don't bank on it)
- Note the affected km in tactical bullets

### Altitude (>1500m)
- +5 sec/km per 1000m above sea level
- Apply uniformly

### Shoes
- Carbon racers: no adjustment (target is for race conditions)
- Training shoes: no adjustment (assumes target is calibrated for them)
- Trail shoes on road: +5 to +10 sec/km

## Verification

Before generating the deliverable, verify:

```
sum(splits in seconds) ≈ target_chrono_in_seconds (±5 sec)
```

If the sum is off by more than 5 seconds, tweak 1–2 mid-race splits to balance. Don't touch km 1 or the final km — they have specific roles.
