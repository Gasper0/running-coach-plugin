# Garmin Export — Forerunner 945 Structured Workouts

## Overview

Two methods are available to get structured workouts onto the Forerunner 945:

| Method | How it works | Pros | Cons |
|--------|-------------|------|------|
| **Method A — FIT file via USB** | Generate a `.fit` workout file, copy to watch | No account needed, offline | Requires USB cable, no schedule |
| **Method B — Garmin Connect API** | Upload workout via Python API, syncs to watch via BT | Wireless sync, auto-scheduled | Requires Garmin Connect account + credentials |

**Important**: Garmin does NOT allow uploading workout FIT files via the activity upload endpoint. Workout FIT files must be copied directly via USB. For wireless sync, use Method B (API).

---

## Method A — FIT Workout Files via USB

### Dependencies
```bash
pip install fit-tool --break-system-packages
```

### Key Concepts

A FIT workout is a sequence of **steps**, each with:
- **Duration**: by TIME (seconds) or DISTANCE (meters)
- **Target**: HEART_RATE zone, SPEED (pace), OPEN (no target), or CADENCE
- **Intensity**: WARMUP, ACTIVE, RECOVER, COOLDOWN, REST, INTERVAL

For pace targets: Garmin uses **speed in m/s**, NOT pace in min/km.
Convert: `speed_ms = 1000 / pace_sec_per_km`  
Example: 5:00/km → 1000/300 = 3.333 m/s

### Complete Script

```python
import datetime
import os
from fit_tool.fit_file_builder import FitFileBuilder
from fit_tool.profile.messages.file_id_message import FileIdMessage
from fit_tool.profile.messages.workout_message import WorkoutMessage
from fit_tool.profile.messages.workout_step_message import WorkoutStepMessage
from fit_tool.profile.profile_type import (
    Sport, Intensity, WorkoutStepDuration, WorkoutStepTarget,
    Manufacturer, FileType
)


def pace_to_speed(pace_str: str) -> float:
    """Convert 'M:SS' pace string to m/s speed."""
    parts = pace_str.split(':')
    total_sec = int(parts[0]) * 60 + int(parts[1])
    return round(1000 / total_sec, 4)


def make_step(name: str, intensity: Intensity,
              duration_type: WorkoutStepDuration, duration_value: float,
              target_type: WorkoutStepTarget, target_value=None,
              target_low=None, target_high=None,
              custom_target_low: float = None,
              custom_target_high: float = None) -> WorkoutStepMessage:
    """Create a single workout step."""
    step = WorkoutStepMessage()
    step.workout_step_name = name[:16]  # Garmin limits step names to 16 chars
    step.intensity = intensity
    step.duration_type = duration_type

    if duration_type == WorkoutStepDuration.TIME:
        step.duration_time = float(duration_value)        # seconds
    elif duration_type == WorkoutStepDuration.DISTANCE:
        step.duration_distance = float(duration_value)    # meters
    elif duration_type == WorkoutStepDuration.OPEN:
        pass

    step.target_type = target_type

    if target_type == WorkoutStepTarget.HEART_RATE:
        step.target_hr_zone = int(target_value)           # 1–5
    elif target_type == WorkoutStepTarget.SPEED:
        # Custom speed range in m/s
        step.custom_target_speed_low = float(custom_target_low)
        step.custom_target_speed_high = float(custom_target_high)
    elif target_type == WorkoutStepTarget.OPEN:
        pass

    return step


def make_repeat_step(repeat_count: int, first_step_index: int) -> WorkoutStepMessage:
    """Create a repeat step that loops back to first_step_index."""
    step = WorkoutStepMessage()
    step.workout_step_name = f'x{repeat_count}'
    step.intensity = Intensity.ACTIVE
    step.duration_type = WorkoutStepDuration.REPEAT_UNTIL_STEPS_CMPLT
    step.duration_value = int(repeat_count)
    step.target_type = WorkoutStepTarget.OPEN
    step.target_value = int(first_step_index)
    return step


def build_workout_fit(workout_name: str, steps: list, output_path: str):
    """Build and save a FIT workout file."""
    builder = FitFileBuilder(auto_define=True, min_string_size=50)

    # File ID
    file_id = FileIdMessage()
    file_id.type = FileType.WORKOUT
    file_id.manufacturer = Manufacturer.GARMIN.value
    file_id.product = 3113  # Forerunner 945 product ID
    file_id.time_created = round(datetime.datetime.now().timestamp() * 1000)
    file_id.serial_number = 0x12345678
    builder.add(file_id)

    # Workout header
    workout = WorkoutMessage()
    workout.sport = Sport.RUNNING
    workout.capabilities = 32
    workout.num_valid_steps = len(steps)
    workout.workout_name = workout_name[:16]
    builder.add(workout)

    # Steps
    for step in steps:
        builder.add(step)

    fit_file = builder.build()
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    fit_file.to_file(output_path)
    print(f"✅ FIT workout generated: {output_path}")


# ── TEMPLATE BUILDERS ────────────────────────────────────────────────────────

def build_easy_run_fit(name: str, duration_min: int, pace_easy: str, output_path: str):
    """Easy/recovery run — constant easy pace."""
    steps = [
        make_step('Echauff.', Intensity.WARMUP,
                  WorkoutStepDuration.TIME, 600,
                  WorkoutStepTarget.HEART_RATE, target_value=1),
        make_step('Facile', Intensity.ACTIVE,
                  WorkoutStepDuration.TIME, (duration_min - 20) * 60,
                  WorkoutStepTarget.SPEED,
                  custom_target_low=pace_to_speed(pace_easy) * 0.97,
                  custom_target_high=pace_to_speed(pace_easy) * 1.03),
        make_step('Recup.', Intensity.COOLDOWN,
                  WorkoutStepDuration.TIME, 600,
                  WorkoutStepTarget.OPEN),
    ]
    build_workout_fit(name[:16], steps, output_path)


def build_tempo_run_fit(name: str, tempo_min: int, pace_warmup: str,
                        pace_tempo: str, output_path: str):
    """Threshold/tempo run."""
    steps = [
        make_step('Echauff.', Intensity.WARMUP,
                  WorkoutStepDuration.TIME, 600,
                  WorkoutStepTarget.HEART_RATE, target_value=2),
        make_step('Tempo', Intensity.ACTIVE,
                  WorkoutStepDuration.TIME, tempo_min * 60,
                  WorkoutStepTarget.SPEED,
                  custom_target_low=pace_to_speed(pace_tempo) * 0.97,
                  custom_target_high=pace_to_speed(pace_tempo) * 1.03),
        make_step('Recup.', Intensity.COOLDOWN,
                  WorkoutStepDuration.TIME, 600,
                  WorkoutStepTarget.OPEN),
    ]
    build_workout_fit(name[:16], steps, output_path)


def build_intervals_fit(name: str, rep_count: int,
                        rep_distance_m: int, pace_interval: str,
                        recovery_time_s: int,
                        output_path: str):
    """Track intervals (e.g., 8x400m or 5x1000m)."""
    steps = [
        make_step('Echauff.', Intensity.WARMUP,
                  WorkoutStepDuration.TIME, 600,
                  WorkoutStepTarget.HEART_RATE, target_value=2),
        make_step(f'{rep_distance_m}m', Intensity.INTERVAL,
                  WorkoutStepDuration.DISTANCE, rep_distance_m,
                  WorkoutStepTarget.SPEED,
                  custom_target_low=pace_to_speed(pace_interval) * 0.97,
                  custom_target_high=pace_to_speed(pace_interval) * 1.03),
        make_step('Recup.', Intensity.RECOVER,
                  WorkoutStepDuration.TIME, recovery_time_s,
                  WorkoutStepTarget.OPEN),
        make_repeat_step(rep_count, first_step_index=1),  # repeat from step index 1
        make_step('Retour', Intensity.COOLDOWN,
                  WorkoutStepDuration.TIME, 600,
                  WorkoutStepTarget.OPEN),
    ]
    build_workout_fit(name[:16], steps, output_path)


def build_long_run_fit(name: str, total_min: int, pace_easy: str,
                       pace_progressive: str, output_path: str):
    """Long run with progressive finish."""
    base_min = total_min - 25  # last 15 min progressive + 10 min cooldown
    steps = [
        make_step('Echauff.', Intensity.WARMUP,
                  WorkoutStepDuration.TIME, 600,
                  WorkoutStepTarget.HEART_RATE, target_value=1),
        make_step('Endurance', Intensity.ACTIVE,
                  WorkoutStepDuration.TIME, (base_min - 10) * 60,
                  WorkoutStepTarget.SPEED,
                  custom_target_low=pace_to_speed(pace_easy) * 0.95,
                  custom_target_high=pace_to_speed(pace_easy) * 1.05),
        make_step('Progressif', Intensity.ACTIVE,
                  WorkoutStepDuration.TIME, 15 * 60,
                  WorkoutStepTarget.SPEED,
                  custom_target_low=pace_to_speed(pace_progressive) * 0.97,
                  custom_target_high=pace_to_speed(pace_progressive) * 1.03),
        make_step('Recup.', Intensity.COOLDOWN,
                  WorkoutStepDuration.TIME, 600,
                  WorkoutStepTarget.OPEN),
    ]
    build_workout_fit(name[:16], steps, output_path)
```

### How to Transfer to the Forerunner 945

```
1. Connect the Forerunner 945 to your computer via USB cable
2. The watch appears as a USB drive (e.g., GARMIN or Forerunner 945)
3. Navigate to: GARMIN/WORKOUTS/
4. Copy the .fit files into that folder
5. Safely eject the watch
6. Workouts are now available under: Training > Workouts on the watch
```

### Generating All Workouts for a Plan

```python
def generate_all_fit_workouts(sessions: list[dict], zones: dict, output_dir: str):
    """
    Generate individual FIT files for each running session in the plan.
    
    zones dict example:
    {
        'easy': '6:15',      # min:sec per km
        'tempo': '5:00',
        'interval_400': '3:55',
        'interval_1000': '4:05',
        'long_easy': '6:30',
        'long_progressive': '5:15'
    }
    """
    os.makedirs(output_dir, exist_ok=True)
    generated = []
    
    for s in sessions:
        stype = s.get('session_type')
        week = s.get('week', 0)
        date_str = s['date'].strftime('%Y%m%d') if hasattr(s.get('date'), 'strftime') else ''
        
        if stype == 'easy':
            fname = f"W{week:02d}_{date_str}_facile.fit"
            build_easy_run_fit(
                name=f"W{week} Facile",
                duration_min=s.get('duration_min', 40),
                pace_easy=zones['easy'],
                output_path=os.path.join(output_dir, fname)
            )
            generated.append(fname)
        
        elif stype == 'tempo':
            fname = f"W{week:02d}_{date_str}_tempo.fit"
            build_tempo_run_fit(
                name=f"W{week} Tempo",
                tempo_min=s.get('duration_min', 45) - 20,
                pace_warmup=zones['easy'],
                pace_tempo=zones['tempo'],
                output_path=os.path.join(output_dir, fname)
            )
            generated.append(fname)
        
        elif stype == 'intervals':
            fname = f"W{week:02d}_{date_str}_fractio.fit"
            notes = s.get('notes', '')
            # Parse rep info from notes or use defaults
            if '1000m' in notes or '1km' in notes.lower():
                build_intervals_fit(
                    name=f"W{week} 1000m",
                    rep_count=s.get('reps', 5),
                    rep_distance_m=1000,
                    pace_interval=zones['interval_1000'],
                    recovery_time_s=180,
                    output_path=os.path.join(output_dir, fname)
                )
            else:
                build_intervals_fit(
                    name=f"W{week} 400m",
                    rep_count=s.get('reps', 8),
                    rep_distance_m=400,
                    pace_interval=zones['interval_400'],
                    recovery_time_s=90,
                    output_path=os.path.join(output_dir, fname)
                )
            generated.append(fname)
        
        elif stype == 'long_run':
            fname = f"W{week:02d}_{date_str}_longue.fit"
            build_long_run_fit(
                name=f"W{week} Longue",
                total_min=s.get('duration_min', 75),
                pace_easy=zones['long_easy'],
                pace_progressive=zones['long_progressive'],
                output_path=os.path.join(output_dir, fname)
            )
            generated.append(fname)
    
    return generated
```

---

## Method B — Garmin Connect API (Wireless Sync)

### Dependencies
```bash
pip install garminconnect --break-system-packages
```

### Authentication
```python
import garminconnect

api = garminconnect.Garmin(email="your@email.com", password="yourpassword")
api.login()
```

### Create a Structured Workout via API

```python
def upload_workout_to_garmin_connect(api, session: dict, zones: dict):
    """
    Create a structured workout in Garmin Connect.
    It will sync to the Forerunner 945 on next Bluetooth sync.
    """
    stype = session.get('session_type')
    
    # Build workout steps based on session type
    if stype == 'tempo':
        steps = [
            {"type": "WorkoutStep", "stepOrder": 1, "intensity": "warmup",
             "durationType": "time", "durationValue": 600,
             "targetType": "heartRateZone", "targetValue": 2},
            {"type": "WorkoutStep", "stepOrder": 2, "intensity": "interval",
             "durationType": "time", "durationValue": (session.get('duration_min', 45) - 20) * 60,
             "targetType": "pace.zone", "targetValueLow": zones['tempo_low_ms'],
             "targetValueHigh": zones['tempo_high_ms']},
            {"type": "WorkoutStep", "stepOrder": 3, "intensity": "cooldown",
             "durationType": "time", "durationValue": 600,
             "targetType": "open"},
        ]
    # ... similar for other session types
    
    workout_payload = {
        "workoutName": session.get('title', 'Entrainement'),
        "description": session.get('notes', ''),
        "sportType": {"sportTypeId": 1, "sportTypeKey": "running"},
        "estimatedDurationInSecs": session.get('duration_min', 45) * 60,
        "workoutSegments": [{"segmentOrder": 1, "sportType": {"sportTypeId": 1}, 
                              "workoutSteps": steps}]
    }
    
    result = api.add_workout(workout_payload)
    return result.get('workoutId')
```

---

## Output Folder Structure

When generating for a full plan:
```
garmin-workouts/
├── W01_20250401_facile.fit
├── W01_20250403_longue.fit
├── W02_20250408_tempo.fit
├── W02_20250410_fractio.fit
...
└── README.txt   ← Instructions for transfer
```

Always generate a `README.txt` alongside the .fit files:
```
Garmin Forerunner 945 — Entraînements structurés
================================================

Pour transférer sur la montre (via USB) :
1. Connectez la montre en USB à votre ordinateur
2. Naviguez vers : GARMIN/WORKOUTS/
3. Copiez tous les fichiers .fit dans ce dossier
4. Déconnectez la montre en toute sécurité
5. Sur la montre : Entraînement > Séances

Plan : [PLAN NAME]
Course objectif : [RACE NAME] — [RACE DATE]
Objectif chrono : [GOAL TIME]
Nombre de séances : [N]
```
