# Excel/CSV Export — Running Training Plan

## Dependencies
```bash
pip install openpyxl --break-system-packages
```

## Full Python Script

```python
import openpyxl
from openpyxl.styles import PatternFill, Font, Alignment, Border, Side
from openpyxl.utils import get_column_letter
from datetime import date

# Color palette (hex, no #)
COLORS = {
    'easy':      {'fill': 'C8E6C9', 'font': '1B5E20'},  # green
    'long_run':  {'fill': 'BBDEFB', 'font': '0D47A1'},  # blue
    'tempo':     {'fill': 'FFE0B2', 'font': 'E65100'},  # orange
    'intervals': {'fill': 'FFCDD2', 'font': 'B71C1C'},  # red
    'strength':  {'fill': 'E1BEE7', 'font': '4A148C'},  # purple
    'recovery':  {'fill': 'F5F5F5', 'font': '616161'},  # gray
    'race':      {'fill': 'FFF9C4', 'font': 'F57F17'},  # yellow
    'rest':      {'fill': 'FFFFFF', 'font': '9E9E9E'},  # white
}

HEADER_FILL = PatternFill(start_color='1565C0', end_color='1565C0', fill_type='solid')
HEADER_FONT = Font(bold=True, color='FFFFFF', size=11)

def create_border():
    thin = Side(style='thin', color='CCCCCC')
    return Border(left=thin, right=thin, top=thin, bottom=thin)

def create_training_excel(sessions: list[dict], plan_info: dict, output_path: str):
    """
    sessions: list of dicts with keys:
        - week: int
        - phase: str (e.g., "Phase 1 — Base")
        - date: datetime.date
        - day_name: str (e.g., "Lundi")
        - session_type: str (easy|long_run|tempo|intervals|strength|recovery|race|rest)
        - title: str
        - duration_min: int
        - distance_km: float
        - zones: str
        - pace_target: str
        - hr_zone: str
        - notes: str

    plan_info: dict with keys:
        - runner_name: str (optional)
        - race: str (e.g., "Semi-Marathon de Paris")
        - race_date: date
        - goal_time: str
        - total_weeks: int
        - generated_date: date
    """
    wb = openpyxl.Workbook()

    # ── Sheet 1: Full Plan ─────────────────────────────────────────────────────
    ws = wb.active
    ws.title = "Plan d'entraînement"

    headers = ['Semaine', 'Phase', 'Date', 'Jour', 'Type de séance', 
               'Durée (min)', 'Distance (km)', 'Zones', 'Allure cible', 'FC cible', 'Notes']
    col_widths = [10, 22, 13, 12, 22, 13, 14, 10, 16, 20, 40]

    for i, (h, w) in enumerate(zip(headers, col_widths), 1):
        cell = ws.cell(row=1, column=i, value=h)
        cell.fill = HEADER_FILL
        cell.font = HEADER_FONT
        cell.alignment = Alignment(horizontal='center', vertical='center', wrap_text=True)
        ws.column_dimensions[get_column_letter(i)].width = w
    ws.row_dimensions[1].height = 30

    for row_idx, s in enumerate(sessions, 2):
        stype = s.get('session_type', 'easy')
        color = COLORS.get(stype, COLORS['easy'])
        fill = PatternFill(start_color=color['fill'], end_color=color['fill'], fill_type='solid')
        font_color = color['font']

        values = [
            s.get('week', ''),
            s.get('phase', ''),
            s['date'].strftime('%d/%m/%Y') if isinstance(s.get('date'), date) else s.get('date', ''),
            s.get('day_name', ''),
            s.get('title', ''),
            s.get('duration_min', ''),
            s.get('distance_km', ''),
            s.get('zones', ''),
            s.get('pace_target', ''),
            s.get('hr_zone', ''),
            s.get('notes', ''),
        ]
        for col_idx, val in enumerate(values, 1):
            cell = ws.cell(row=row_idx, column=col_idx, value=val)
            cell.fill = fill
            cell.font = Font(color=font_color, size=10)
            cell.alignment = Alignment(vertical='center', wrap_text=True)
            cell.border = create_border()
        ws.row_dimensions[row_idx].height = 22

    ws.freeze_panes = 'A2'

    # ── Sheet 2: Summary ───────────────────────────────────────────────────────
    ws2 = wb.create_sheet("Résumé")

    # Plan header info
    ws2['A1'] = 'RÉSUMÉ DU PLAN D\'ENTRAÎNEMENT'
    ws2['A1'].font = Font(bold=True, size=14, color='1565C0')
    ws2.merge_cells('A1:D1')

    info_rows = [
        ('Course', plan_info.get('race', '')),
        ('Date de course', plan_info.get('race_date', '').strftime('%d/%m/%Y') if isinstance(plan_info.get('race_date'), date) else ''),
        ('Objectif chrono', plan_info.get('goal_time', '')),
        ('Durée du plan', f"{plan_info.get('total_weeks', '')} semaines"),
        ('Généré le', plan_info.get('generated_date', date.today()).strftime('%d/%m/%Y')),
    ]
    for i, (label, value) in enumerate(info_rows, 3):
        ws2.cell(row=i, column=1, value=label).font = Font(bold=True)
        ws2.cell(row=i, column=2, value=value)

    # Volume per phase
    ws2['A10'] = 'VOLUME PAR PHASE'
    ws2['A10'].font = Font(bold=True, size=12)
    
    phase_data = {}
    for s in sessions:
        phase = s.get('phase', 'N/A')
        if phase not in phase_data:
            phase_data[phase] = {'sessions': 0, 'km': 0, 'min': 0}
        if s.get('session_type') != 'rest':
            phase_data[phase]['sessions'] += 1
            phase_data[phase]['km'] += s.get('distance_km', 0) or 0
            phase_data[phase]['min'] += s.get('duration_min', 0) or 0

    headers2 = ['Phase', 'Nb séances', 'Volume total (km)', 'Durée totale (h)']
    for i, h in enumerate(headers2, 1):
        cell = ws2.cell(row=11, column=i, value=h)
        cell.fill = HEADER_FILL
        cell.font = HEADER_FONT
        cell.alignment = Alignment(horizontal='center')
        ws2.column_dimensions[get_column_letter(i)].width = 22

    for row_i, (phase, data) in enumerate(phase_data.items(), 12):
        ws2.cell(row=row_i, column=1, value=phase)
        ws2.cell(row=row_i, column=2, value=data['sessions'])
        ws2.cell(row=row_i, column=3, value=round(data['km'], 1))
        ws2.cell(row=row_i, column=4, value=round(data['min'] / 60, 1))

    # Totals
    total_row = 12 + len(phase_data)
    ws2.cell(row=total_row, column=1, value='TOTAL').font = Font(bold=True)
    ws2.cell(row=total_row, column=2, value=sum(d['sessions'] for d in phase_data.values())).font = Font(bold=True)
    ws2.cell(row=total_row, column=3, value=round(sum(d['km'] for d in phase_data.values()), 1)).font = Font(bold=True)
    ws2.cell(row=total_row, column=4, value=round(sum(d['min'] for d in phase_data.values()) / 60, 1)).font = Font(bold=True)

    # Legend sheet
    ws3 = wb.create_sheet("Légende")
    ws3['A1'] = 'LÉGENDE DES COULEURS'
    ws3['A1'].font = Font(bold=True, size=12)
    legend = [
        ('easy', '🟢 Sortie facile / Récupération'),
        ('long_run', '🔵 Sortie longue'),
        ('tempo', '🟠 Tempo / Seuil'),
        ('intervals', '🔴 Fractionné / VMA'),
        ('strength', '💜 Renforcement musculaire'),
        ('recovery', '⚪ Récupération active / Étirements'),
        ('race', '🟡 Course / Compétition'),
    ]
    for i, (stype, label) in enumerate(legend, 3):
        color = COLORS[stype]
        cell = ws3.cell(row=i, column=1, value=label)
        cell.fill = PatternFill(start_color=color['fill'], end_color=color['fill'], fill_type='solid')
        cell.font = Font(color=color['font'], bold=True)
        ws3.column_dimensions['A'].width = 40

    wb.save(output_path)
    print(f"✅ Excel generated: {output_path}")
```

## Usage
```python
from datetime import date

plan_info = {
    "race": "Semi-Marathon de Paris",
    "race_date": date(2025, 6, 15),
    "goal_time": "1h45",
    "total_weeks": 12,
    "generated_date": date.today()
}

create_training_excel(sessions, plan_info, "/mnt/user-data/outputs/training-plan.xlsx")
```
