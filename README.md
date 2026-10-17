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
| [docs/setup.md](docs/setup.md) | Getting a server running, including the game files you must copy from your own copy of GTA:SA |
| [docs/references.md](docs/references.md) | Wikis, reverse-engineering sources and reference material |
| [docs/paths-and-lights.md](docs/paths-and-lights.md) | Retail path data format and traffic light rules, as verified against the game data |
| [docs/population.md](docs/population.md) | Who spawns where: vanilla popcycle, zones, gangs and weapons, from retail data and seeded config |
| [docs/player.md](docs/player.md) | Player persistence (by serial), spawning, wasted and busted |
| [docs/services.md](docs/services.md) | Wanted levels and police, ambulances, parked car generators |
| [docs/shops.md](docs/shops.md) | Entrances into interiors, and the shops |
| [docs/traffic.md](docs/traffic.md) | Traffic, pedestrians and the AI actor architecture: Lua decides, the engine executes |

## Resources

| Resource | Purpose |
| --- | --- |
| `vana-core` | Placeholder core resource |
| `vana-player` | Player persistence, spawning, wasted/busted restarts |
| `vana-paths` | Reads the retail `NODES*.DAT` path graph; nearest-node, link and navi queries; traffic light stop rule |
| `vana-lights` | Runs the traffic lights on the vanilla single-player cycle |
| `vana-population` | Vanilla population rules: zone/time densities, ped and car groups, gangs, cops, weapons |
| `vana-parked` | Parked cars from vanilla car generators (map IPLs and `main.scm`) |
| `vana-services` | Wanted levels, police pursuit, ambulances and medics |
| `vana-interiors` | Vanilla entry/exit markers into interiors |
| `vana-shops` | Ammu-Nation, fast food, clothes shops, 24/7 counters |
| `vana-traffic` | Road traffic: server-planned routes and light stops, driven by native drive-to tasks |
| `vana-peds` | Ambient pedestrians: server-planned walks and road crossings, native follow-route tasks and event reactions |
