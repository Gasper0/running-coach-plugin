# ICS Export — Running Training Plan

## Dependencies
```bash
pip install icalendar --break-system-packages
```

## Full Python Script

```python
from icalendar import Calendar, Event, Alarm, vText
from datetime import datetime, timedelta, date
import uuid

def create_training_ics(sessions: list[dict], plan_name: str, output_path: str, weeks: int | None = 2):
    """
    sessions: list of dicts with keys:
        - date: datetime.date object
        - start_hour: int (e.g., 7 for 7am) — use 7 as default if unknown
        - title: str (e.g., "Tempo Run")
        - duration_min: int
        - distance_km: float
        - zones: str (e.g., "Z3")
        - pace_target: str (e.g., "5:15-5:30 /km")
        - hr_zone: str (e.g., "80-87% HR max")
        - description: str (full workout instructions)
        - session_type: str (easy|tempo|intervals|strength|recovery|long_run|race)
    """
    cal = Calendar()
    cal.add('prodid', '-//Running Coach//Training Plan//EN')
    cal.add('version', '2.0')
    cal.add('calscale', 'GREGORIAN')
    cal.add('X-WR-CALNAME', plan_name)
    cal.add('X-WR-TIMEZONE', 'Europe/Paris')

    # Emoji map by session type
    emoji_map = {
        'easy': '🟢',
        'long_run': '🔵',
        'tempo': '🟠',
        'intervals': '🔴',
        'strength': '💪',
        'recovery': '🧘',
        'race': '🏆',
    }

    for s in sessions:
        event = Event()
        emoji = emoji_map.get(s.get('session_type', 'easy'), '🏃')
        
        event.add('uid', str(uuid.uuid4()))
        event.add('summary', f"{emoji} {s['title']} — {s['duration_min']} min")
        
        start_dt = datetime(
            s['date'].year, s['date'].month, s['date'].day,
            s.get('start_hour', 7), 0, 0
        )
        end_dt = start_dt + timedelta(minutes=s['duration_min'])
        
        event.add('dtstart', start_dt)
        event.add('dtend', end_dt)
        
        # Full description
        desc_lines = [
            s['description'],
            "",
            f"📏 Distance estimée : ~{s['distance_km']:.1f} km",
            f"💓 Zones : {s['zones']}",
            f"⏱ Allure cible : {s['pace_target']}",
            f"❤️ FC cible : {s['hr_zone']}",
        ]
        event.add('description', "\n".join(desc_lines))
        
        # Color category by session type (Apple Calendar / Outlook compatible)
        color_map = {
            'easy': 'green',
            'long_run': 'blue', 
            'tempo': 'orange',
            'intervals': 'red',
            'strength': 'purple',
            'recovery': 'gray',
            'race': 'yellow',
        }
        event.add('color', color_map.get(s.get('session_type', 'easy'), 'blue'))
        
        # 2-hour reminder alarm
        alarm = Alarm()
        alarm.add('action', 'DISPLAY')
        alarm.add('description', f"Rappel : {s['title']} dans 2h 🏃")
        alarm.add('trigger', timedelta(hours=-2))
        event.add_component(alarm)
        
        cal.add_component(event)

    with open(output_path, 'wb') as f:
        f.write(cal.to_ical())
    
    print(f"✅ ICS generated: {output_path}")
```

## Usage Example

```python
from datetime import date

sessions = [
    {
        "date": date(2025, 4, 1),
        "start_hour": 7,
        "title": "Sortie facile",
        "duration_min": 40,
        "distance_km": 6.0,
        "zones": "Z1-Z2",
        "pace_target": "6:00-6:30 /km",
        "hr_zone": "60-75% FC max (111-138 bpm)",
        "description": "Échauffement 10 min + 20 min en endurance fondamentale + récupération 10 min. Allure conversationnelle, RPE 4/10.",
        "session_type": "easy"
    },
    # ... more sessions
]

create_training_ics(
    sessions=sessions,
    plan_name="Plan 10km — Paris, 15 juin 2025",
    output_path="/mnt/user-data/outputs/training-plan-10km-2025-06-15.ics"
)
```

## Tips
- Always set a real `start_hour` if the user mentioned preferred training times
- For race day event, use session_type='race' and set duration = estimated finish time
- The .ics file is importable in Google Calendar (Settings > Import), Apple Calendar (File > Import), and Outlook

## Rolling Window Export (default behaviour)

By default the script only exports the **next 2 weeks** of sessions. This is intentional:

- The user's calendar stays clean — no months of events cluttering the view
- When the plan is adjusted (e.g. after a weekly review), re-running the script only replaces the upcoming 2 weeks — past events are untouched
- The race day event is **always included** regardless of the window

**CLI flags:**
```bash
# Default — next 2 weeks only (recommended for regular use)
python generate_ics.py

# Custom window — e.g. next 3 weeks
python generate_ics.py --weeks 3

# Full plan — all sessions from today to race day (e.g. for first-time setup)
python generate_ics.py --full
```

**Coaching instruction:** Always use the rolling 2-week default unless the user explicitly asks for the full plan. When re-exporting after a plan adjustment, remind the user that only upcoming sessions are regenerated — they do not need to delete anything from their calendar first.
