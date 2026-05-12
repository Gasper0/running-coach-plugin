# Garmin Workout Rules

> Complete technical reference for creating and scheduling workouts via the Garmin MCP.
> All rules here are battle-tested from real use — do not deviate.

---

## 1. Workout creation workflow

The correct sequence is always:

```
garmin:create_workout    →  returns workout_id
       ↓
garmin:schedule_workout  with that workout_id on the target date
```

**Never call `schedule_workout` twice on the same workout.** It creates duplicates that cannot be cleanly removed without recreating the workout from scratch. If you need to reschedule:

1. `garmin:delete_workout` with the existing workout_id
2. Create a fresh workout with `create_workout`
3. Schedule it on the new date

---

## 2. Step types

These are the only step types supported by the Garmin MCP:

| Step type | Purpose |
|---|---|
| `warmup` | Warmup block at the start (usually easy pace) |
| `interval` | A work segment (typically high intensity) |
| `recovery` | Active recovery between interval reps |
| `rest` | Pause / open lap (often manual) |
| `repeat` | A loop containing multiple steps with a `repeat_count` |
| `cooldown` | Cooldown block at the end (easy pace) |

---

## 3. Duration types

Each step must specify a `duration_type`:

| `duration_type` | Means | Example |
|---|---|---|
| `time` | Duration in seconds | 600 sec = 10 min |
| `distance` | Distance in meters | 400 m, 1000 m |
| `open` | Until manual lap press by user | for the mandatory rest between warmup and main |

---

## 4. Target types

For pace or HR targets on a step:

| `target_type` | Format |
|---|---|
| `pace` | Integers in seconds-per-km. Provide `target_value_low` and `target_value_high` as integers |
| `heart_rate` | Integers in bpm. Provide `target_value_low` and `target_value_high` as integers |
| `open` | No specific target — runner sets their own |

### Pace conversion table

| Target pace | Seconds/km integer |
|---|---|
| 3:30 /km | 210 |
| 3:40 /km | 220 |
| 3:50 /km | 230 |
| 4:00 /km | 240 |
| 4:02 /km | 242 |
| 4:08 /km | 248 |
| 4:10 /km | 250 |
| 4:30 /km | 270 |
| 4:55 /km | 295 |
| 5:00 /km | 300 |
| 5:10 /km | 310 |
| 5:15 /km | 315 |
| 5:30 /km | 330 |
| 6:00 /km | 360 |

Formula: `seconds/km = minutes × 60 + seconds`. Example: 4:08/km = 4×60 + 8 = 248.

---

## 5. CRITICAL — Mandatory rest step between warmup and main

**On every running workout, insert a `rest` step with `duration_type: "open"` between the warmup and the first main step.**

Why: the user wants the option to press Lap manually before starting the main block (so the warmup ends, the rest gives time to remove the jacket / start the music / stretch briefly, and the main effort begins on a clean lap).

Structure:

```
[1] warmup        — time, 600 sec, open pace
[2] rest          — open, no target              ← MANDATORY
[3] interval/repeat (the main block)
[4] cooldown      — time, 300 sec, open pace
```

Skipping this step is a regression for the user. Always include it.

---

## 6. CRITICAL — Flatten nested repeat blocks

**True nested repeats are NOT supported by the Garmin MCP.** A session like `3×(5×400m)` is not a single repeat-of-repeat. It must be expressed as three sequential repeat blocks separated by standalone recovery steps between groups.

### Wrong (will fail or render as "0 fois" on the watch):

```
repeat 3 times {
  repeat 5 times {
    interval 400m
    recovery 60s
  }
  rest 3min
}
```

### Right (sequential flat blocks):

```
[3] repeat 5 times {
      interval 400m
      recovery 60s
    }
[4] rest 180 sec               ← between-group recovery

[5] repeat 5 times {
      interval 400m
      recovery 60s
    }
[6] rest 180 sec               ← between-group recovery

[7] repeat 5 times {
      interval 400m
      recovery 60s
    }
```

The watch will display "Series 1/3", "Series 2/3", "Series 3/3" with rep counters inside each group.

### When is a `repeat` block fine?

Single-level repeats are fully supported and preferred over manually unrolling reps:

```
✅ repeat 5 times { interval 1000m at threshold ; recovery 90s }
```

This gives the user a live rep counter on the watch ("Rep 1/5", "Rep 2/5", etc.). Always use `repeat` for single-level repetition; only flatten when there would be nesting.

---

## 7. Standard workout structure templates

### Easy run (EF)

```
[1] warmup     — 5 min @ open pace
[2] rest       — open
[3] interval   — [target duration] @ Z1-Z2 (HR or pace)
[4] cooldown   — 3 min @ open pace
```

### Threshold (AS)

```
[1] warmup     — 15 min @ open pace
[2] rest       — open                              ← MANDATORY
[3] repeat 2 times {
      interval — 15 min @ 242–248 sec/km (4:02–4:08/km)
      recovery — 3 min @ easy
    }
[4] cooldown   — 10 min @ open pace
```

### VMA intervals — 3×(5×400m) example

```
[1] warmup     — 15 min @ open pace
[2] rest       — open                              ← MANDATORY

[3] repeat 5 times {
      interval — 400m @ 209–214 sec/km (3:29–3:34/km)
      recovery — 60s @ easy
    }
[4] rest       — 180 sec                          ← inter-group recovery

[5] repeat 5 times {
      interval — 400m @ 209–214 sec/km
      recovery — 60s @ easy
    }
[6] rest       — 180 sec                          ← inter-group recovery

[7] repeat 5 times {
      interval — 400m @ 209–214 sec/km
      recovery — 60s @ easy
    }

[8] cooldown   — 10 min @ open pace
```

### Long run with progressive segments (SL progressive)

```
[1] warmup     — 10 min @ open pace
[2] rest       — open
[3] interval   — 8 km @ Z2 (HR 138–155 bpm)
[4] interval   — 5 km @ Z3 (HR 155–168 bpm)
[5] interval   — 2 km @ Z3-Z4 (HR 168–178 bpm)
[6] cooldown   — 5 min @ open pace
```

---

## 8. Heart rate targets — when to use them

Use HR targets instead of pace when:
- Long runs (HR is more reliable than pace for endurance work)
- Recovery runs (avoid the user running too fast by chasing a pace)
- Hot weather / hilly terrain (pace becomes misleading)

Use pace targets when:
- Threshold / VMA / tempo work (precise intensity needed)
- Track sessions
- Race-pace simulations

The user's known HR zones (from FC max 199, FC resting ~50):

| Zone | % FC max | bpm range |
|---|---|---|
| Z1 — Recovery | < 65% | < 130 |
| Z2 — Endurance | 65–75% | 130–149 |
| Z3 — Tempo | 75–85% | 149–169 |
| Z4 — Threshold | 85–92% | 169–183 |
| Z5 — VO2max | 92–100% | 183–199 |

---

## 9. Cleanup — keep the watch clean

After each completed or cancelled session, the user wants the corresponding workout removed from their watch. Always offer to clean up:

```
garmin:list_workouts
# Identify completed/cancelled workout
garmin:delete_workout  with the workout_id
```

This prevents accumulation of stale workouts and keeps the daily watch interface uncluttered.

---

## 10. Common mistakes to avoid

| Mistake | Consequence |
|---|---|
| Passing pace as string "4:02" instead of integer 242 | Workout creation fails or pace is misread |
| Nesting `repeat` blocks | Watch displays "0 fois" or fails to load |
| Calling `schedule_workout` twice on same workout_id | Duplicate scheduled workout, hard to remove |
| Forgetting the mandatory `rest` between warmup and main | User loses the manual lap break they expect |
| Pushing a Hyrox brick session as a structured workout | Stations can't be represented; create a free run instead |
| Inventing pace targets from memory | Inconsistent with user's known zones; always reference `vdot-paces.md` or known race times |
