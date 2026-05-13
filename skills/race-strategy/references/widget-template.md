# Widget template — visual race strategy

## Overview

Use `visualize:show_widget` after calling `visualize:read_me(modules=["chart", "data_viz"])` first.

The widget has 4 sections, in this order:
1. Profile metrics (4 metric cards)
2. Elevation chart with colored zones
3. Splits table with colored tags
4. Tactical notes block (4–6 bullets)

## Color palette

The widget uses 5 colors mapped to phases. Always reuse these exact hex values:

| Phase | Color | Hex | Background tag | Text tag |
|-------|-------|-----|----------------|----------|
| Conservative (km 1) | Teal | `#1D9E75` | `#E1F5EE` | `#085041` |
| Target pace | Purple | `#7F77DD` | `#EEEDFE` | `#26215C` |
| Climb | Amber | `#EF9F27` | `#FAEEDA` | `#412402` |
| Descent | Blue | `#378ADD` | `#E6F1FB` | `#042C53` |
| Finish | Coral | `#D85A30` | `#FAECE7` | `#4A1B0C` |

## Full template

Adapt the `splits` array and `altitudes` data to the specific course. Keep the structure identical.

```html
<style>
.sw{padding:1rem 0 2rem}
.section-label{font-size:11px;font-weight:500;color:var(--color-text-tertiary);letter-spacing:.07em;text-transform:uppercase;margin:0 0 .75rem}
.metric-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;margin-bottom:1.5rem}
.mc{background:var(--color-background-secondary);border-radius:var(--border-radius-md);padding:.75rem 1rem}
.mc-label{font-size:12px;color:var(--color-text-tertiary);margin:0 0 3px}
.mc-value{font-size:20px;font-weight:500;color:var(--color-text-primary);margin:0;line-height:1}
.mc-sub{font-size:11px;color:var(--color-text-tertiary);margin:3px 0 0}
.divider{height:.5px;background:var(--color-border-tertiary);margin:1.25rem 0}
.phase-row{display:grid;grid-template-columns:auto 1fr auto auto;gap:10px;align-items:center;padding:9px 0;border-bottom:.5px solid var(--color-border-tertiary)}
.phase-row:last-child{border-bottom:none}
.phase-km{font-size:13px;font-weight:500;color:var(--color-text-primary);min-width:60px}
.phase-bar-wrap{background:var(--color-border-tertiary);border-radius:2px;height:6px;position:relative}
.phase-bar{height:100%;border-radius:2px}
.phase-pace{font-size:13px;font-weight:500;color:var(--color-text-primary);min-width:56px;text-align:right}
.phase-tag{font-size:11px;padding:2px 8px;border-radius:99px;min-width:70px;text-align:center}
.alert-block{border-radius:var(--border-radius-md);padding:.85rem 1rem;margin-top:1.25rem}
.alert-row{display:flex;align-items:flex-start;gap:10px;padding:5px 0}
.alert-dot{width:7px;height:7px;border-radius:50%;flex-shrink:0;margin-top:5px}
.alert-text{font-size:13px;color:var(--color-text-secondary)}
.alert-text strong{font-weight:500;color:var(--color-text-primary)}
</style>

<div class="sw">
  <p class="section-label">Profil altimétrique — analyse</p>
  <div class="metric-grid">
    <div class="mc"><p class="mc-label">Distance</p><p class="mc-value">{distance} km</p><p class="mc-sub">{distance_source}</p></div>
    <div class="mc"><p class="mc-label">Dénivelé +</p><p class="mc-value">{d_plus} m</p><p class="mc-sub">{profile_descriptor}</p></div>
    <div class="mc"><p class="mc-label">Bosse principale</p><p class="mc-value">{climb_location}</p><p class="mc-sub">{climb_descriptor}</p></div>
    <div class="mc"><p class="mc-label">Objectif</p><p class="mc-value">{target_chrono}</p><p class="mc-sub">{target_pace}</p></div>
  </div>

  <div style="position:relative;height:90px;margin-bottom:1.5rem">
    <canvas id="profileChart" role="img" aria-label="Profil altimétrique du parcours">{profile_summary_text}</canvas>
  </div>

  <p class="section-label">Stratégie de course — splits cibles</p>
  <div id="splits"></div>

  <div class="divider"></div>

  <p class="section-label">Points clés tactiques</p>
  <div class="alert-block" style="background:var(--color-background-secondary);border-left:3px solid #1D9E75;border-radius:0 var(--border-radius-md) var(--border-radius-md) 0">
    <!-- Generate 4-6 alert-row elements with appropriate dot colors matching phase colors -->
    <div class="alert-row"><div class="alert-dot" style="background:#1D9E75"></div><div class="alert-text"><strong>Km 1 — départ conservateur.</strong> {tactical_text_km1}</div></div>
    <!-- ... more rows ... -->
  </div>
</div>

<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.js"></script>
<script>
const isDark = matchMedia('(prefers-color-scheme: dark)').matches;
const textColor = isDark ? '#B4B2A9' : '#5F5E5A';
const gridColor = isDark ? 'rgba(255,255,255,.08)' : 'rgba(0,0,0,.06)';

// Insert real altitude data from parser (every 0.25km)
const altitudes = [/* array of altitudes */];
const labels = altitudes.map((_,i) => (i*0.25).toFixed(2));

new Chart(document.getElementById('profileChart'), {
  type: 'line',
  data: {
    labels,
    datasets: [{
      data: altitudes,
      borderColor: isDark ? 'rgba(180,178,169,0.5)' : 'rgba(95,94,90,0.4)',
      borderWidth: 1.5,
      pointRadius: 0,
      tension: 0.4,
      fill: true,
      backgroundColor: (ctx) => {
        const chart = ctx.chart;
        const {ctx: c, chartArea} = chart;
        if(!chartArea) return 'transparent';
        const grad = c.createLinearGradient(chartArea.left, 0, chartArea.right, 0);
        // Map color stops to phase boundaries (0=teal, then purple, amber for climbs, blue for descents, coral for finish)
        grad.addColorStop(0, 'rgba(29,158,117,0.25)');
        grad.addColorStop(0.1, 'rgba(127,119,221,0.2)');
        grad.addColorStop(0.5, 'rgba(239,159,39,0.25)');
        grad.addColorStop(0.7, 'rgba(55,138,221,0.2)');
        grad.addColorStop(1, 'rgba(216,90,48,0.25)');
        return grad;
      }
    }]
  },
  options: {
    responsive: true, maintainAspectRatio: false,
    plugins: { legend: { display: false }, tooltip: { enabled: false } },
    scales: {
      x: { display: false },
      y: {
        ticks: { color: textColor, font: { size: 11 }, maxTicksLimit: 3, callback: v => v + 'm' },
        grid: { color: gridColor }, border: { display: false }
        // Don't set min/max — let Chart.js auto-scale to actual data range
      }
    }
  }
});

// Splits array — adapt km, pace, bar (visual width 0-1), tag, color, bg, tc, note
const splits = [
  { km: 'Km 1', pace: '3:46/km', bar: 0.75, tag: 'Conservateur', color: '#1D9E75', bg: '#E1F5EE', tc: '#085041' },
  // ... more splits
];

const container = document.getElementById('splits');
splits.forEach(s => {
  container.innerHTML += `
    <div class="phase-row">
      <span class="phase-km">${s.km}</span>
      <div class="phase-bar-wrap">
        <div class="phase-bar" style="width:${s.bar*100}%;background:${s.color}40"></div>
      </div>
      <span class="phase-pace" style="color:${s.color}">${s.pace}</span>
      <span class="phase-tag" style="background:${s.bg};color:${s.tc}">${s.tag}</span>
    </div>`;
});
</script>
```

## Sizing notes

- For half-marathon (21 splits) and marathon (42 splits), the splits table will be long. That's fine — it remains readable.
- For marathon, consider grouping splits by 5km blocks if the table feels too long. But keep individual splits in the data for accurate cumulative time.

## Bar visual width logic

The `bar` property (0–1) gives a visual indicator of "intensity" relative to the runner's effort:
- Conservative km 1: 0.75 (slower than rest)
- Target pace flat: 0.85
- Slight climb: 0.80
- Steep climb: 0.70
- Descent: 0.90
- Finish: 0.95

This is purely visual — it doesn't need to be exact, just consistent within the same widget.
