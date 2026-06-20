---
name: UteKnark v2 Architektur
description: Schlüsselentscheidungen der v2-Erweiterung des Weed-Scripts
---

# UteKnark v2 — Architektur-Entscheidungen

## Manifest
- `fxmanifest.lua` wurde neu erstellt (fx_version 'cerulean'); FiveM bevorzugt es gegenüber dem alten `__resource.lua`.
- `__resource.lua` bleibt vorhanden, wird aber von FiveM ignoriert sobald `fxmanifest.lua` existiert.

## Datenbank
- Alte Spalte `soil` entfernt; neue Spalten: `strain VARCHAR(50)`, `water_count INT`, `fertilizer_count INT`.
- Migration-SQL ist in `esx_uteknark.sql` als Kommentar dokumentiert.

## Wachstumssystem
- Kein globaler `Growth[]`-Array mehr. Stufendaten (model, offset, time, harvest) sind direkt in `Config.Strains[key].stages[]` definiert.
- Hilfsfunktionen in `lib/growth.lua`: `GetStrainData`, `GetStageData`, `GetStageCount`, `IsHarvestStage`, `GetQualityStars`, `GetQualityLabel`.
- Qualität (1–5 Sterne) = floor((waterStars + fertStars) / 2), basierend auf Schwellwerten in Config.Quality.

## Wild Weed
- Komplett client-seitig in `lib/wildweed.lua`. Kein Server-State nötig.
- Spawns werden beim Resource-Start per Zufallszahl entschieden; Positionen kommen aus Config.
- Kein Blip, kein Marker. Spieler finden Pflanzen selbst.

## ox_lib Nutzung
- Notifications: `TriggerClientEvent('ox_lib:notify', src, {...})` vom Server.
- Client: `lib.progressBar(...)`, `lib.skillCheck(...)`, `lib.registerContext`/`lib.showContext`.
- Alle Animationen via `anim = { scenario = '...' }` im progressBar.

## Stale-Data-Fix
- `activePlants` speichert Kopien der Pflanzendaten. Beim Menü-Öffnen wird `cropstate.index[id]` erneut gelesen um aktuelle water_count/fertilizer_count zu erhalten.

## Unbenutzter Entwurf
- `cl_wildweed.lua` im Root war ein vorhandener Entwurf (server-driven approach). Nicht im Manifest, wird nicht geladen. Kann gelöscht werden.

**Why:** Sortenbasiertes System ermöglicht einfaches Hinzufügen neuer Sorten nur über Config ohne Code-Änderungen.
