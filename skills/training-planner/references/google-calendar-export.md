# Google Calendar Export — MCP Direct Integration

Push training sessions directly into the user's Google Calendar via the **MCP Google Calendar tools** (already authenticated — no OAuth setup needed). This is the preferred and simplest method when the user has the Google Calendar MCP active.

---

## Choosing between MCP and legacy script

| Feature | MCP (preferred) | Legacy Python script |
|---------|----------------|---------------------|
| Setup needed | ✅ None — already connected | ❌ Google Cloud project + credentials |
| Push sessions | ✅ Direct via tool calls | ✅ Via Python script |
| Update/patch events | ✅ Delete + recreate | ✅ Patches by session date tag |
| Delete events | ✅ `google-calendar:delete-event` | ❌ `--delete` flag (local only) |
| Works in this conversation | ✅ Yes | ❌ Requires local Python environment |

**Rule**: If the MCP Google Calendar tools are available in the current session → **always use MCP**. Only fall back to the Python script if MCP is unavailable.

---

## Calendar to use

**Always use the "Entraînement Running" calendar** for all running training sessions:
- Calendar ID: `2219901e0ef12be17dd3a6c8cedab607fdf3875805dd316feab6d3c2502a86b9@group.calendar.google.com`
- Calendar name: 🏃 Entraînement Running

For the race day event, use the same calendar unless the user asks otherwise.

---

## Step 0 — Load MCP tools

Before any calendar operation, call `tool_search` with query `"google calendar create update delete event"` to load the correct MCP tool schemas. Do NOT guess parameter names.

---

## Step 1 — Pushing the initial plan

When pushing the training plan for the first time:

1. Use `google-calendar:list-events` to fetch all future events in the Entraînement Running calendar (from today onwards)
2. If existing events are found → show the count to the user and ask:
   > "Il y a déjà X séances dans ton agenda Entraînement Running. Je les supprime avant d'ajouter le nouveau plan ?"
3. If confirmed (or calendar is empty) → proceed with creation
4. Create all sessions using `google-calendar:create-event` (or `google-calendar:create-events` for bulk)
5. Skip REST days — never create events for rest days

### Event format

```
Title:       {EMOJI} [{CODE}] {title}
             e.g. "🟢 [EF] Endurance Fondamentale 45min"
Start time:  Session date at 07:00 (running) or 18:00 (evening session)
End time:    Start + duration_minutes
Description: Phase: {phase}

             {detailed_description}

             — Running Coach —
Color:       See color map below
Calendar:    Entraînement Running
```

### Emoji & color map

| Code | Type | Emoji | Google Calendar Color |
|------|------|-------|----------------------|
| EF | Easy run | 🟢 | Sage (2) |
| SL | Long run | 🔵 | Blueberry (9) |
| FR | Intervals | 🔴 | Tomato (11) |
| AS | Tempo | 🟠 | Tangerine (6) |
| RM | Strength | 💪 | Grape (3) |
| RA | Active recovery | 🧘 | Graphite (8) |
| RACE | Race day | 🏆 | Banana (5) |
| REST | Rest day | 😴 | (skip — never create calendar events for rest days) |

---

## Step 2 — Replacing the plan (plan change or weekly readjustment)

**When the plan is modified** (weekly review, injury, rescheduling, or full plan replacement), always use the **delete-then-recreate** strategy for all future sessions. Never try to patch individual events.

### Full procedure:

**Phase A — Identify and delete all future Running Coach events**

1. Call `google-calendar:list-events` on the Entraînement Running calendar with `timeMin = today` to fetch all upcoming events
2. Filter events that were created by the Running Coach — identify them by title pattern: events containing `[EF]`, `[SL]`, `[FR]`, `[AS]`, `[RM]`, `[RA]`, `[RACE]`, or `— Running Coach —` in description
3. Show the user a summary:
   > "Je vais supprimer X séances à venir (du {first_date} au {last_date}) pour les remplacer par le plan mis à jour. C'est bon pour toi ?"
4. **Wait for user confirmation** before deleting
5. Once confirmed, call `google-calendar:delete-event` for each identified event — loop through them all, do not skip any

**Phase B — Recreate all future sessions from the updated plan**

6. Create all future sessions from the new/updated plan using `google-calendar:create-event`
7. Skip REST days
8. Do not recreate sessions that are already in the past (before today)

**Phase C — Report**

9. Report to the user:
   ```
   🗑️ X séances supprimées
   ✅ Y séances créées dans "🏃 Entraînement Running"
   📅 Prochaine séance : {next_session_title} le {next_session_date}
   ```

### Important rules for delete-then-recreate:
- **Never skip the delete phase** — stale events from the old plan must be removed before new ones are created
- **Never update individual events** — always delete all future events and recreate from scratch to ensure consistency
- **Always confirm with the user** before deleting — show count and date range of events to be deleted
- **Past events are untouched** — only delete events from today onwards

---

## Step 3 — Race day event

After pushing all sessions, create the race day event if it doesn't already exist:

```
Title:       🏆 RACE DAY — {race_name}
Date:        Race date, 08:00–12:00
Calendar:    Entraînement Running
Description: "Bonne course ! 🎉\nObjectif : {target_time}"
Color:       Banana (5)
```

Search for an existing "RACE DAY" event on the race date before creating. If it exists and the plan changed, delete and recreate it with updated info.

---

## Step 4 — Confirmation output

After any push or update, always report:
```
✅ {N} séances créées dans "🏃 Entraînement Running"
✅ 1 événement Race Day : {race_date}
📅 Prochaine séance : {next_session_title} le {next_session_date}
```

---

## Error handling

- If a delete fails → retry once, report the specific event that failed, continue with the rest
- If a create fails → retry once, report the specific session, continue with the rest
- If the calendar is not found → remind user the MCP Google Calendar must be active, and fall back to the `.ics` export (references/ics-export.md)
- Never silently skip failed operations — always report them at the end

---

## Legacy Python script (fallback only)

If MCP tools are unavailable, fall back to the `google_calendar_sync.py` script. This requires a local Python environment and Google Cloud credentials (OAuth2 credentials.json from Google Cloud Console). On first run it opens a browser for authorization, saves token.json, and asks the user to pick a calendar interactively (saved to calendar_config.json).

Usage: `python google_calendar_sync.py [--weeks N | --full | --delete | --pick]`

Events are tagged with `X-RunningCoach-Managed=true` to avoid duplicates on re-sync.
