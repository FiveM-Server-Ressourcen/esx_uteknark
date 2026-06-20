# UteKnark (esx_uteknark)

A FiveM resource for ESX-based GTA V roleplay servers. Allows players to plant and grow weed anywhere on the map where there is appropriate terrain (grass, dirt, sand).

## Project Type

This is a **FiveM Lua resource** — not a web application. It has no build system, no package manager, and no runnable server. It is deployed by dropping the files into a FiveM server's `resources/` directory.

## Tech Stack

- **Language:** Lua (FiveM client/server scripting)
- **Framework:** ESX (`es_extended`)
- **Database:** MySQL via `mysql-async`
- **Platform:** FiveM (GTA V modding framework)

## Installation (on a FiveM server)

1. Clone/copy this directory and name it `esx_uteknark`
2. Place it in your FiveM server's `resources/` directory
3. Add `ensure esx_uteknark` to `server.cfg`
4. Import `esx_uteknark.sql` into your MySQL database
5. Edit `config.lua` to configure items, growth rates, etc.
6. Restart or refresh the resource

## Dependencies (must be installed on the FiveM server)

- [es_extended](https://github.com/ESX-Org/es_extended)
- [mysql-async](https://github.com/brouznouf/fivem-mysql-async)

## File Structure

- `__resource.lua` — FiveM resource manifest
- `cl_uteknark.lua` — Client-side script
- `sv_uteknark.lua` — Server-side script
- `config.lua` — Configurable settings
- `lib/` — Shared helper modules (cropstate, growth, octree, debug)
- `locales/` — Localization files (en-US, sv-SE)
- `esx_uteknark.sql` — Database schema

## User Preferences

- No specific preferences recorded yet.
