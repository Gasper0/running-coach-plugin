# Word/PDF Export — Running Training Plan

## Dependencies
```bash
pip install python-docx --break-system-packages
```

## Full Python Script

```python
from docx import Document
from docx.shared import Pt, RGBColor, Inches, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from datetime import date

def hex_to_rgb(hex_color: str):
    h = hex_color.lstrip('#')
    return RGBColor(int(h[0:2],16), int(h[2:4],16), int(h[4:6],16))

SESSION_COLORS = {
    'easy':      '#C8E6C9',
    'long_run':  '#BBDEFB',
    'tempo':     '#FFE0B2',
    'intervals': '#FFCDD2',
    'strength':  '#E1BEE7',
    'recovery':  '#F5F5F5',
    'race':      '#FFF9C4',
}

SESSION_EMOJIS = {
    'easy':      '🟢',
    'long_run':  '🔵',
    'tempo':     '🟠',
    'intervals': '🔴',
    'strength':  '💪',
    'recovery':  '🧘',
    'race':      '🏆',
}

def create_training_docx(sessions: list[dict], plan_info: dict, zones_info: dict, output_path: str):
    """
    plan_info keys: runner_name, race, race_date, goal_time, total_weeks, current_pb
    zones_info keys: pace_zones (list of dicts), hr_zones (list of dicts)
        pace_zones: [{'zone':'Z1','name':'Facile','pace':'6:00-6:30 /km','use':'Sorties longues'}]
        hr_zones: [{'zone':'Z1','pct':'60-70%','bpm':'111-130','type':'Récupération'}]
    sessions: same format as ics-export.md
    """
    doc = Document()

    # Page margins
    for section in doc.sections:
        section.top_margin = Cm(2)
        section.bottom_margin = Cm(2)
        section.left_margin = Cm(2.5)
        section.right_margin = Cm(2.5)

    # ── COVER PAGE ─────────────────────────────────────────────────────────────
    title_p = doc.add_paragraph()
    title_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = title_p.add_run('🏃 PLAN D\'ENTRAÎNEMENT')
    run.font.size = Pt(28)
    run.font.bold = True
    run.font.color.rgb = RGBColor(0x15, 0x65, 0xC0)

    subtitle_p = doc.add_paragraph()
    subtitle_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    sub_run = subtitle_p.add_run(plan_info.get('race', ''))
    sub_run.font.size = Pt(18)
    sub_run.font.color.rgb = RGBColor(0x42, 0x42, 0x42)

    doc.add_paragraph()  # spacer

    # Info table
    info_table = doc.add_table(rows=5, cols=2)
    info_table.style = 'Table Grid'
    info_data = [
        ('🎯 Objectif', plan_info.get('goal_time', '')),
        ('📅 Date de course', plan_info.get('race_date', date.today()).strftime('%d %B %Y') if isinstance(plan_info.get('race_date'), date) else ''),
        ('📊 Niveau actuel', plan_info.get('current_pb', '')),
        ('📆 Durée du plan', f"{plan_info.get('total_weeks', '')} semaines"),
        ('🗓 Généré le', date.today().strftime('%d %B %Y')),
    ]
    for i, (label, value) in enumerate(info_data):
        info_table.cell(i, 0).text = label
        info_table.cell(i, 0).paragraphs[0].runs[0].font.bold = True
        info_table.cell(i, 1).text = value
    
    doc.add_page_break()

    # ── PHYSIOLOGICAL PROFILE ──────────────────────────────────────────────────
    doc.add_heading('📊 Profil Physiologique & Zones', level=1)

    doc.add_heading('Zones d\'allure', level=2)
    pace_table = doc.add_table(rows=1, cols=4)
    pace_table.style = 'Table Grid'
    pace_headers = ['Zone', 'Nom', 'Allure cible', 'Utilisation']
    for i, h in enumerate(pace_headers):
        pace_table.rows[0].cells[i].text = h
        pace_table.rows[0].cells[i].paragraphs[0].runs[0].font.bold = True

    for z in zones_info.get('pace_zones', []):
        row = pace_table.add_row()
        row.cells[0].text = z.get('zone', '')
        row.cells[1].text = z.get('name', '')
        row.cells[2].text = z.get('pace', '')
        row.cells[3].text = z.get('use', '')

    doc.add_paragraph()
    doc.add_heading('Zones de fréquence cardiaque', level=2)
    hr_table = doc.add_table(rows=1, cols=4)
    hr_table.style = 'Table Grid'
    hr_headers = ['Zone', '% FC max', 'BPM estimé', 'Type']
    for i, h in enumerate(hr_headers):
        hr_table.rows[0].cells[i].text = h
        hr_table.rows[0].cells[i].paragraphs[0].runs[0].font.bold = True

    for z in zones_info.get('hr_zones', []):
        row = hr_table.add_row()
        row.cells[0].text = z.get('zone', '')
        row.cells[1].text = z.get('pct', '')
        row.cells[2].text = z.get('bpm', '')
        row.cells[3].text = z.get('type', '')

    doc.add_page_break()

    # ── TRAINING PLAN — BY WEEK ────────────────────────────────────────────────
    doc.add_heading('📋 Plan Semaine par Semaine', level=1)

    current_week = None
    for s in sessions:
        week = s.get('week')
        if week != current_week:
            current_week = week
            phase = s.get('phase', '')
            doc.add_heading(f'Semaine {week} — {phase}', level=2)

        # Session block
        stype = s.get('session_type', 'easy')
        emoji = SESSION_EMOJIS.get(stype, '🏃')
        
        p = doc.add_paragraph()
        run = p.add_run(f"{emoji} {s.get('day_name','')}, {s['date'].strftime('%d/%m') if isinstance(s.get('date'), date) else ''} — {s.get('title','')}")
        run.font.bold = True
        run.font.size = Pt(11)

        details_p = doc.add_paragraph()
        details_p.paragraph_format.left_indent = Cm(0.5)
        details_p.add_run(f"⏱ Durée : {s.get('duration_min','')} min | 📏 Distance : ~{s.get('distance_km','')} km\n").font.size = Pt(10)
        details_p.add_run(f"💓 Zones : {s.get('zones','')} | Allure : {s.get('pace_target','')} | FC : {s.get('hr_zone','')}\n").font.size = Pt(10)
        desc_run = details_p.add_run(s.get('notes', ''))
        desc_run.font.size = Pt(10)
        desc_run.font.color.rgb = RGBColor(0x42, 0x42, 0x42)

    doc.add_page_break()

    # ── APPENDIX ───────────────────────────────────────────────────────────────
    doc.add_heading('📚 Annexes', level=1)

    doc.add_heading('Glossaire des séances', level=2)
    glossary = [
        ('Sortie facile', 'Allure conversationnelle Z1-Z2. RPE 4/10. Socle de tout plan.'),
        ('Sortie longue', 'Session clé, jamais sautée. Développe l\'endurance aérobie de base.'),
        ('Tempo / Seuil', 'Allure "durement confortable". Peut parler en phrases courtes. Z3.'),
        ('Fractionné VMA', 'Intervalles courts à haute intensité. Développe le VO2max. Z4-Z5.'),
        ('Renforcement', 'Circuit musculaire ciblé running : fessiers, gainage, mollets.'),
        ('Récupération active', 'Mobilité légère, étirements dynamiques. Accélère la récupération.'),
    ]
    for term, definition in glossary:
        p = doc.add_paragraph()
        run = p.add_run(f"• {term} : ")
        run.font.bold = True
        p.add_run(definition)

    doc.save(output_path)
    print(f"✅ Word document generated: {output_path}")
```

## PDF Conversion
After generating the .docx, convert to PDF if needed:
```python
import subprocess
subprocess.run(['libreoffice', '--headless', '--convert-to', 'pdf', output_path, '--outdir', '/mnt/user-data/outputs/'])
```
Or use python-docx2pdf:
```bash
pip install docx2pdf --break-system-packages
```
```python
from docx2pdf import convert
convert(docx_path, pdf_path)
```
