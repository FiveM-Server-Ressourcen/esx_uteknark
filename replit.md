# UteKnark (esx_uteknark) — Extended Edition

A FiveM resource for ESX-based GTA V roleplay servers.  
Players can grow multiple weed strains anywhere on the map, discover wild weed in the world, and manage quality through watering and fertilizing.

## Project Type

**FiveM Lua resource** — not a web application.  
No build system, no package manager, no runnable server.  
Deploy by dropping this folder into your FiveM server's `resources/` directory.

---

## Tech Stack

| Layer     | Technology                          |
|-----------|-------------------------------------|
| Language  | Lua (FiveM client/server scripting) |
| Framework | ESX (`es_extended`)                 |
| Database  | MySQL via `mysql-async`             |
| UI / UX   | `ox_lib` (progress bars, menus, skillchecks, notifications) |
| Platform  | FiveM (GTA V modding framework)     |

---

## Installation (on a FiveM server)

1. Clone/copy this directory and name it `esx_uteknark`
2. Place it in `resources/`
3. Add `ensure esx_uteknark` to `server.cfg`
4. Import `esx_uteknark.sql` into your MySQL database  
   ⚠️ This **drops and recreates** the `uteknark` table — backup first on upgrades!
5. Add all seed items, `flower_pot`, `fertilizer`, and water items to your ESX items table
6. Edit `config.lua` to configure strains, positions, timings, etc.
7. Restart the resource

---

## Dependencies (must be running on the FiveM server)

- [es_extended](https://github.com/ESX-Org/es_extended)
- [mysql-async](https://github.com/brouznouf/fivem-mysql-async)
- [ox_lib](https://github.com/overextended/ox_lib)

---

## File Structure

```
esx_uteknark/
├── fxmanifest.lua          Modern FiveM resource manifest (used by current FiveM)
├── __resource.lua          Legacy manifest (fallback for very old servers)
├── config.lua              All configurable values
├── cl_uteknark.lua         Client: planted plant rendering & interaction (ox_lib menus)
├── cl_wildweed.lua         Client: wild weed spawning & collection
├── sv_uteknark.lua         Server: planting, watering, fertilizing, harvest, growth tick
├── esx_uteknark.sql        Database schema (run once on install)
├── lib/
│   ├── octree.lua          Spatial index for planted plants
│   ├── growth.lua          Growth stage definitions + GetPlantModel() helper
│   ├── cropstate.lua       Plant state: DB persistence, octree, network events
│   └── debug.lua           Debug overlay (client only)
└── locales/
    ├── en-US.lua           English strings
    └── sv-SE.lua           Swedish strings
```

---

## Features

### Planting System
- Plants can be placed **anywhere** on the map (no soil/terrain restrictions)
- Requires: **seed item** (strain-specific) + **flower pot** item
- Plants persist across server restarts (stored in MySQL)

### Weed Strains (via config)
| Strain       | Seed Item          | Growth Speed |
|--------------|--------------------|--------------|
| OG Kush      | `og_kush_seed`     | Standard     |
| Purple Haze  | `purple_haze_seed` | 20 % faster  |
| Amnesia      | `amnesia_seed`     | 25 % slower  |
| White Widow  | `white_widow_seed` | 10 % slower  |

Add new strains by adding a block to `Config.Strains` — nothing else needed.

### Quality System (1–5 ★)
Harvest quality depends on:
- Watering count (40 % weight)
- Fertilizer applications (40 % weight)
- Tending care bonus (20 % weight)

### Wild Weed System
- Positions configured in `Config.WildWeed.Positions`
- On server start each position has a configurable spawn chance
- Strain is selected randomly by weighted probabilities
- **No blips, no markers, no map hints**
- Players collect seeds via ox_lib progress bar + skillcheck minigame
- Positions respawn after a configurable cooldown

### Care Actions (all use ox_lib)
| Action     | Key  | Requires         | ox_lib used            |
|------------|------|------------------|------------------------|
| Plant menu | E    | near planted plant | Context menu          |
| Water      | menu | water item       | Progress bar + animation |
| Fertilize  | menu | fertilizer item  | Progress bar + animation |
| Tend/Harvest | menu | —              | Progress bar + animation |
| Destroy    | menu | —                | Progress bar + animation |
| Wild collect | E  | near wild plant  | Skillcheck + progress bar |

---

## Config Quick Reference

```lua
Config.FlowerPot      = 'flower_pot'
Config.WaterItems     = { 'water_bottle', 'watering_can' }
Config.FertilizerItem = 'fertilizer'

Config.Strains.og_kush = {
    name = 'OG Kush', seed = 'og_kush_seed', product = 'weed_og_kush',
    prop_young = ..., prop_mature = ..., timeMultiplier = 1.0,
    yield = {3,5}, seedReturn = {1,3},
}

Config.WildWeed.SpawnChance = 0.65
Config.WildWeed.Positions   = { vector4(x,y,z,h), ... }
Config.WildWeed.StrainWeights = {
    { strain = 'og_kush', weight = 40 }, ...
}
```

---

## User Preferences

- No specific preferences recorded yet.
