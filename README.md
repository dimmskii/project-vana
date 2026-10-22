# ProjectVana

A freeroam gamemode for [MTA Neon](https://github.com/Dryxio/mtasa-neon) that recreates single-player
San Andreas open-world play, written in pure Lua.

This repository is the `[vana]` resource group: put it at `mods/deathmatch/resources/[vana]` on an
MTA Neon server. Rockstar's data files are not included; `docs/setup.md` lists what to copy from
your own copy of GTA:SA. `tools/` holds the seed scripts and a headless server control script.

Start here:

| Doc | What it covers |
| --- | --- |
| [docs/mission.md](docs/mission.md) | What we are building and what we deliberately leave out |
| [docs/cohesion.md](docs/cohesion.md) | Rules every resource follows: commands, permissions, UI layout |
| [docs/controls.md](docs/controls.md) | `/use` (F), `/interact` (F1) and actions: every thing a player does as a bindable command, one gate, the status line |
| [docs/setup.md](docs/setup.md) | Getting a server running, including the game files you must copy from your own copy of GTA:SA |
| [docs/references.md](docs/references.md) | Wikis, reverse-engineering sources and reference material |
| [docs/paths-and-lights.md](docs/paths-and-lights.md) | Retail path data format and traffic light rules, as verified against the game data |
| [docs/population.md](docs/population.md) | Who spawns where: vanilla popcycle, zones, gangs and weapons, from retail data and seeded config |
| [docs/player.md](docs/player.md) | Player persistence (by serial), spawning, wasted and busted |
| [docs/services.md](docs/services.md) | Wanted levels and police, ambulances, parked car generators |
| [docs/shops.md](docs/shops.md) | Entrances into interiors, the shops and the gym |
| [docs/map.md](docs/map.md) | The shared map: publishing points, categories, blips |
| [docs/activities.md](docs/activities.md) | Per-player activities ported from main.scm: the framework, burglary and the rest |
| [docs/trains.md](docs/trains.md) | Trains: the tracks as map data, the timetable, trains in the world only near players, taking one |
| [docs/traffic.md](docs/traffic.md) | Traffic, pedestrians and the AI actor architecture: Lua decides, the engine executes |
| [docs/vehicles.md](docs/vehicles.md) | Kept cars (registry and persistence), fuel, each car's radio station |
| [docs/radio.md](docs/radio.md) | The radio: stations on one server clock, car and outside radios, vanilla's programme and track data |
| [docs/editor.md](docs/editor.md) | Placement data in MTA map resources (`[data]/vana-data-*`) and editing it in the Map Editor |
| [docs/encounters.md](docs/encounters.md) | Creatures and NPCs you may run into at their spots (Bigfoot) |
| [docs/wildlife.md](docs/wildlife.md) | Animals in the countryside (Myths Maker's animal pack): spawners, models |
| [docs/libraries.md](docs/libraries.md) | Shared code in `vana-lib` (imported at runtime): game-file readers (GXT, IDE, DAT, TXD), map data; `vana-text` |
| [docs/debug.md](docs/debug.md) | Debug switches (`/vanadebug`): per-resource checks by topic, the stuck-ped detector, players' errors in the server log |
| [docs/credits.md](docs/credits.md) | Third-party mods we use (authors, sources, terms) and how mod content is handled |

## Resources

| Resource | Purpose |
| --- | --- |
| `vana-lib` | Shared code the other resources import: game-file readers, map data (docs/libraries.md) |
| `vana-text` | The game's text (`american.gxt`) for every resource |
| `vana-controls` | `/use` and `/interact`, every resource's actions as commands, the status line (the game's help box) |
| `vana-core` | Players' script errors in the server log; debug switches (`/vanadebug`) and the stuck-ped detector |
| `vana-player` | Player persistence, spawning, wasted/busted restarts |
| `vana-paths` | The path graph (GTA:SA's, converted to map data in `[data]/[paths]`); nearest-node, link and navi queries; traffic light stop rule |
| `vana-lights` | Runs the traffic lights on the vanilla single-player cycle |
| `vana-population` | Vanilla population rules: zone/time densities, ped and car groups, gangs, cops, weapons |
| `vana-parked` | Parked cars from vanilla car generators (map IPLs and the script's generators) |
| `vana-services` | Wanted levels, police pursuit, ambulances and medics |
| `vana-interiors` | Vanilla entry/exit markers into interiors |
| `vana-shops` | Ammu-Nation, fast food, clothes shops, 24/7 counters, gym fighting styles |
| `vana-gym` | Gym equipment workouts: stamina, muscle, fat |
| `vana-activities` | Per-player activities: burglary, dating, side jobs, schools, races, minigames |
| `vana-map` | Map points and radar blips for every resource (categories, icons, ranges) |
| `vana-vehicles` | Vehicle registry and exact persistence, fuel, each car's radio station |
| `vana-help` | The manual in the chat: `/?` and `/man`, every resource's commands and topics as each player may use them |
| `vana-radio` | Radio stations on one server clock (vanilla's programme, internet streams), car and outside radios |
| `[data]/vana-data-*` | Map resources holding placement data (spots, markers, paths); see docs/editor.md |
| `vana-encounters` | Creatures and NPCs you may run into at their spots: Bigfoot |
| `vana-wildlife` | Animals in the countryside: Myths Maker's animals at its spots |
| `vana-traffic` | Road traffic: server-planned routes and light stops, driven by native drive-to tasks |
| `vana-peds` | Ambient pedestrians: server-planned walks and road crossings, native follow-route tasks and event reactions |
| `vana-trains` | Freight trains, the Brown Streak and the San Fierro trams: a server timetable, elements only near players |
