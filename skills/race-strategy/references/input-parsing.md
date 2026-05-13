# Input parsing — course profile

## Format priority

| Priority | Format | Method | Reliability |
|----------|--------|--------|-------------|
| 1 | GPX file | `scripts/parse_gpx.py` | Excellent — exact data |
| 2 | Elevation screenshot | Direct image read | Good — visual estimation |
| 3 | URL (OpenRunner, Strava, Komoot) | `web_fetch` + fallback | Variable — JS-rendered profiles often unavailable |

If multiple formats are provided, use the highest-priority one.

## Method 1 — GPX file

Run the parser script:

```bash
python /mnt/skills/user/race-strategy/scripts/parse_gpx.py <path_to_gpx>
```

The script outputs a JSON structure:

```json
{
  "distance_km": 10.13,
  "elevation_gain_m": 39,
  "elevation_loss_m": 32,
  "altitude_per_km": [
    {"km": 0, "alt": 30},
    {"km": 1, "alt": 32},
    {"km": 2, "alt": 35},
    ...
    {"km": 10.13, "alt": 30}
  ],
  "altitude_per_quarter_km": [
    {"km": 0.0, "alt": 30},
    {"km": 0.25, "alt": 31},
    ...
  ]
}
```

Use `altitude_per_quarter_km` for the chart (smoother curve), `altitude_per_km` for the splits table.

## Method 2 — Elevation profile screenshot

Read the image directly. Identify the y-axis scale (meters) and x-axis (km markers).

For each km marker on the x-axis, estimate the altitude at that point. Build a list of `{km, alt}` pairs.

If the chart shows fine-grained altitude (every 250m), capture more points for a smoother visual chart.

**Watch out for**:
- Y-axis often goes higher than the actual data range (e.g., axis 0–200m but data 30–55m). Read the actual data, not the full axis.
- Some screenshots show distance in kilometers, others in miles. Convert if needed.
- The y-axis label sometimes uses "m" or "ft" — confirm the unit.

## Method 3 — URL fetching

Try `web_fetch` on the URL first. The page summary often contains:
- Total distance
- Total D+ / D-
- Course name and location

But the **detailed elevation profile** is almost always rendered in JavaScript and won't be in the fetched HTML. Common cases:

- **OpenRunner** — returns distance and D+ in the HTML, but the km-by-km profile is JS-rendered. Ask for a screenshot of the profile.
- **Strava routes** — public routes return basic stats. Detailed profile requires login or screenshot.
- **Komoot** — similar to Strava, basic stats only via fetch.

When the URL doesn't give enough data, ask:

> "La page contient les informations de base mais le profil détaillé est rendu en JavaScript et inaccessible depuis le fetch. Peux-tu m'envoyer un screenshot du profil altimétrique ou le fichier GPX si tu l'as ?"

## Validation

Whatever format is used, verify two sanity checks before proceeding:

1. **Total distance** matches the expected race distance (±5%). If a 10km route shows 12km, something is wrong.
2. **D+ realism** — anything above 200m for a flat urban race is suspicious. Cross-check with the course description.

If the data looks off, ask the user for clarification before generating the strategy.
