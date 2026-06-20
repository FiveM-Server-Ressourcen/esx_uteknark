# UteKnark (esx_uteknark)

A FiveM resource for ESX-based GTA V roleplay servers. Extended weed growing system with multiple strains, wild weed, quality system, and ox_lib integration.

## Project Type

This is a **FiveM Lua resource** — not a web application. It has no build system, no package manager, and no runnable server. It is deployed by dropping the files into a FiveM server's `resources/` directory.

## Tech Stack

- **Language:** Lua (FiveM client/server scripting)
- **Framework:** ESX (`es_extended`)
- **Database:** MySQL via `mysql-async`
- **UI/UX:** `ox_lib` (notifications, progress bars, context menus, skill checks)
- **Platform:** FiveM (GTA V modding framework)

## Installation (on a FiveM server)

1. Clone/copy this directory and name it `esx_uteknark`
2. Place it in your FiveM server's `resources/` directory
3. Add `ensure esx_uteknark` to `server.cfg`
4. Import `esx_uteknark.sql` into your MySQL database
5. Add all required items to your ESX items table (see Items section below)
6. Edit `config.lua` to configure strains, wild weed positions, etc.
7. Restart or refresh the resource

## Dependencies (must be installed on the FiveM server)

- [es_extended](https://github.com/ESX-Org/es_extended)
- [mysql-async](https://github.com/brouznouf/fivem-mysql-async)
- [ox_lib](https://github.com/overextended/ox_lib) ← Neu in v2.0

## Required ESX Items (in your items table)

For each strain:
- `og_kush_seed`, `og_kush_weed`
- `purple_haze_seed`, `purple_haze_weed`
- `amnesia_seed`, `amnesia_weed`
- `white_widow_seed`, `white_widow_weed`

Sonstige:
- `flower_pot` — Blumentopf (Pflanzvoraussetzung)
- `water_bottle` / `watering_can` — Wasser-Items
- `fertilizer` — Dünger

## Neue Features v2.0

- **Überall pflanzen** — kein Bodenmaterial-System mehr
- **4 Weed-Sorten** — OG Kush, Purple Haze, Amnesia, White Widow (erweiterbar via Config)
- **Wild Weed System** — zufällige Spawns ohne Blips/Marker
- **Qualitätssystem** — 1–5 Sterne basierend auf Pflege
- **ox_lib Integration** — Animationen, Progressbars, Kontextmenü, Minigame
- **Gießen & Düngen** — beliebig viele Items konfigurierbar

## File Structure

- `fxmanifest.lua` — FiveM Resource-Manifest (v2, ersetzt `__resource.lua`)
- `config.lua` — Alle konfigurierbaren Einstellungen
- `cl_uteknark.lua` — Client-Script
- `sv_uteknark.lua` — Server-Script
- `lib/growth.lua` — Wachstums-Hilfsfunktionen
- `lib/cropstate.lua` — Datenhaltung (Octree + MySQL)
- `lib/octree.lua` — Räumliche Partitionierung (unverändert)
- `lib/debug.lua` — Debug-Helfer (unverändert)
- `lib/wildweed.lua` — Wild-Weed-System (Client)
- `locales/` — Sprachdateien
- `esx_uteknark.sql` — Datenbankschema

## Adding New Strains

Nur in `config.lua` unter `Config.Strains` einen neuen Eintrag hinzufügen:
```lua
my_strain = {
    name       = 'My Strain',
    seed       = 'my_strain_seed',    -- ESX Item-Name
    product    = 'my_strain_weed',    -- ESX Item-Name
    yield      = {3, 5},
    seedReturn = {1, 3},
    stages = {
        { label='Keimling', model=`prop_weed_02`, offset=vector3(0,0,-1.0), time=30 },
        { label='Wachstum', model=`prop_weed_02`, offset=vector3(0,0,-0.6), time=120 },
        { label='Blüte',    model=`prop_weed_01`, offset=vector3(0,0,-0.3), time=240 },
        { label='Erntereif',model=`prop_weed_01`, offset=vector3(0,0,0),    time=120, harvest=true },
    },
},
```
Dann das Item in ESX anlegen und ggf. zum Wild-Weed-System unter `Config.WildWeed.StrainChances` hinzufügen.

## User Preferences

- Keine spezifischen Präferenzen bisher.
