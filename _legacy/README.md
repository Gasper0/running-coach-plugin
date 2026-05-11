# Running Coach — Plugin

Ce plugin regroupe deux skills complémentaires pour la préparation et l'exécution de courses à pied.

## Skills incluses

### 🏃 `running-coach.skill`
Coach virtuel pour la préparation aux courses à pied (10km, semi, marathon, Hyrox).

**Capacités principales :**
- Génération de plans d'entraînement personnalisés
- Suivi hebdomadaire des séances avec données Garmin
- Adaptation dynamique du plan selon la récupération
- Exports : Google Calendar (MCP), Garmin Connect (MCP), .ics, Excel/CSV, PDF/Word
- Bibliothèque de séances (VMA, seuil, sortie longue, Hyrox Run Brick)
- Gestion des séances de musculation orientées running
- Bilans hebdomadaires visuels

### 🎯 `race-strategy.skill`
Génération de stratégies de course personnalisées à partir du profil altimétrique réel.

**Capacités principales :**
- Parsing GPX (priorité 1), screenshot de profil (priorité 2), URL course (priorité 3)
- Distances : 5km, 10km, semi-marathon, marathon
- Splits km par km calibrés sur le chrono cible
- Widget visuel : profil + table de splits + notes tactiques
- Guide de préparation mentale personnalisé au parcours
- Ajustements optionnels : météo, chaussures, altitude

## Workflow recommandé

Les deux skills se complètent naturellement :

1. **Phase préparation** → utiliser `running-coach.skill` pour bâtir et suivre le plan
2. **Phase J-15 à J-1** → utiliser `race-strategy.skill` pour analyser le parcours et préparer la stratégie de course
3. **Jour J** → exécuter la stratégie générée

## Installation

Installer chaque `.skill` séparément dans Claude :

1. Ouvrir Claude (web ou app)
2. Aller dans Settings → Skills
3. Cliquer "Add skill" et sélectionner `running-coach.skill`
4. Répéter pour `race-strategy.skill`

Les deux skills se déclencheront automatiquement selon le contexte de la conversation.

## Versions

- `running-coach.skill` — v1
- `race-strategy.skill` — v0 (stratégie + guide mental, pas encore d'export Garmin Pace Pro)

## Roadmap

**race-strategy V1 envisagée :**
- Export Garmin Pace Pro (CSV importable)
- Calcul programmatique de la `bar` width depuis le gradient
- Examples/ avec cas tests pour itérations
- Intégration météo automatique à J-1 si date connue
