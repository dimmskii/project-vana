# Setup

## 1. Server

Use an MTA Neon server from the same release as your clients. The current target is
**`neon-2026.10.09.188`**.

Either download a prebuilt server from the
[Neon releases page](https://github.com/Dryxio/mtasa-neon/releases) (`MTA-Neon-Server-Windows-x64.zip`
or `MTA-Neon-Linux-Server-x64.tar.gz`), or build the Linux server from source:

```sh
git clone --depth 1 --branch neon-2026.10.09.188 https://github.com/Dryxio/mtasa-neon.git
cd mtasa-neon
# Ubuntu deps: make binutils libncurses-dev libmysqlclient-dev zlib1g-dev libzstd-dev libssl-dev
./linux-build.sh --arch=x64 --config=release --cores=2
echo n | ./linux-install-data.sh   # data files only; we do not use the stock resources
```

`linux-build.sh` deletes `Bin/` on every run. Copy `Bin/server` somewhere else to run it, and
after a rebuild copy only `mta-server64` and `x64/*.so` back over.

## 2. Resources

1. Start with an empty `mods/deathmatch/resources/` folder. Don't install the stock resources.
2. Put this `[vana]` folder inside it.
3. Copy the game files listed below.

On Windows, a clone shows no changes it didn't make: `.gitattributes` keeps text LF and the mod
files (`mods/`) byte-for-byte, and only `tools/*.sh` are executable. Git for Windows ignores file
modes already; a clone made from WSL or Git Bash on an NTFS drive may not, so set it there:

```sh
git config core.fileMode false
```

A clone from before `.gitattributes` (files that stay "modified" and can't be stashed or
discarded): commit or copy away your own work, then `git rm -r --cached -q . && git reset --hard`.

## 3. Game files you must copy

Rockstar's data files are not in this repository and must never be committed (see `.gitignore`).
Copy them from your own retail GTA:SA install (PC v1.0):

| From your GTA:SA folder | To | Used by |
| --- | --- | --- |
| `data/shopping.dat` | `[vana]/vana-shops/data/` | Shop prices and stock |
| `models/txd/LD_BEAT.txd` | `[vana]/vana-activities/data/` | The dance and lowrider beat display's arrows (sent to players) |
| `models/hud.txd` | `[vana]/vana-shops/data/` | The radar icons drawn in the mod garages' and Pay 'n' Sprays' markers (sent to players) |
| `models/gta3.img` (the 144 radar tiles `radar00`–`radar143.txd`) and `models/hud.txd` | `[vana]/vana-map/data/` (`radar/` for the tiles) | The map (F11): its imagery and blip icons (sent to players). Extracted by `tools/seed/extract_radar.py` |
| `text/american.gxt` | `[vana]/vana-text/data/` | All game text (item names, mission titles, objectives, help), for every resource |
| `data/popcycle.dat`, `pedgrp.dat`, `cargrp.dat`, `peds.ide`, `vehicles.ide`, `pedstats.dat`, `ped.dat`, `info.zon`, `map.zon` | `[vana]/vana-population/data/` | Who spawns where (see population.md) |

Example on Linux:

```sh
cp "/path/to/GTA San Andreas/models/txd/LD_BEAT.txd" "vana-activities/data/"
cp "/path/to/GTA San Andreas/models/hud.txd" "vana-shops/data/"
python3 tools/seed/extract_radar.py "/path/to/GTA San Andreas"   # vana-map/data: radar tiles and hud.txd
(cd "/path/to/GTA San Andreas/data" && cp popcycle.dat pedgrp.dat cargrp.dat peds.ide vehicles.ide pedstats.dat ped.dat info.zon map.zon \
   "/path/to/server/mods/deathmatch/resources/[vana]/vana-population/data/")
```

Keep the file names in upper case; the Linux server is case-sensitive.

The path graph (roads, footpaths, traffic lights) ships converted, as map data in
`[data]/[paths]` ([paths-and-lights.md](paths-and-lights.md)); nothing to copy. Only to convert it
again (`tools/convert/paths_to_maps.lua`) copy `data/Paths/NODES0.DAT` … `NODES63.DAT` into
`[vana]/vana-paths/data/`. `pathstest` (step 6) checks the graph; it must print `PASS`.

The railway tracks ship converted the same way, as map data in `[data]/vana-data-trains`
([trains.md](trains.md)); nothing to copy. Only to convert them again
(`tools/convert/tracks_to_maps.lua`) copy `data/Paths/tracks.dat`, `tracks2.dat`, `tracks3.dat` and
`tracks4.dat` into `[vana]/vana-trains/data/`. Their crossings and platform spots come from our own
map data (`tools/convert/track_places.lua`).

Vanilla's flight recordings ship converted too, in `[data]/vana-data-air` ([air.md](air.md)); only to
convert them again (`tools/convert/flights_to_maps.lua`) copy `data/Paths/carrec.img` into
`[vana]/vana-air/data/`.

## 4. mtaserver.conf

Inside `<config>`, replace the stock `<resource>` lines with these, and only these: the Map Editor
runs as a server of its own with `editor.conf`, never from this list ([editor.md](editor.md)). The other
`vana-data-*` resources (player, parked, interiors, encounters, wildlife, radio, trains, air) aren't started at
all: vana-lib reads their files; they only have to be in `resources/`.

```xml
<resource src="vana-lib" startup="1" protected="0" />
<resource src="vana-core" startup="1" protected="0" />
<resource src="vana-text" startup="1" protected="0" />
<resource src="vana-controls" startup="1" protected="0" />
<resource src="vana-data-shops" startup="1" protected="0" />
<resource src="vana-data-gym" startup="1" protected="0" />
<resource src="vana-data-activities" startup="1" protected="0" />
<resource src="vana-map" startup="1" protected="0" />
<resource src="vana-paths" startup="1" protected="0" />
<resource src="vana-lights" startup="1" protected="0" />
<resource src="vana-cars" startup="1" protected="0" />
<resource src="vana-population" startup="1" protected="0" />
<resource src="vana-vehicles" startup="1" protected="0" />
<resource src="vana-radio" startup="1" protected="0" />
<resource src="vana-help" startup="1" protected="0" />
<resource src="vana-traffic" startup="1" protected="0" />
<resource src="vana-peds" startup="1" protected="0" />
<resource src="vana-trains" startup="1" protected="0" />
<resource src="vana-air" startup="1" protected="0" />
<resource src="vana-parked" startup="1" protected="0" />
<resource src="vana-services" startup="1" protected="0" />
<resource src="vana-interiors" startup="1" protected="0" />
<resource src="vana-shops" startup="1" protected="0" />
<resource src="vana-gym" startup="1" protected="0" />
<resource src="vana-activities" startup="1" protected="0" />
<resource src="vana-wildlife" startup="1" protected="0" />
<resource src="vana-encounters" startup="1" protected="0" />
<resource src="vana-player" startup="1" protected="0" />
```

For a private development server, keep it out of the public server lists:

```xml
<ase>0</ase>
<neon_registry>0</neon_registry>
```

## 5. acl.xml

Our admin commands are restricted. `vana-player` grants their rights to the `Admin` ACL itself
on every start (`adminRights` in `vana-player/config/player.lua`; the `Console` group inherits
`Admin`). For reference, they are:

```xml
<!-- ProjectVana -->
<right name="command.traffic" access="true"></right>
<right name="command.peds" access="true"></right>
<right name="command.wanted" access="true"></right>
<right name="command.shoppoint" access="true"></right>
<right name="command.setmoney" access="true"></right>
<right name="command.addmoney" access="true"></right>
<right name="command.setstat" access="true"></right>
<right name="command.event" access="true"></right>
<right name="command.warp" access="true"></right>
<right name="command.warphere" access="true"></right>
<right name="command.warps" access="true"></right>
<right name="command.cleanvehicles" access="true"></right>
<right name="command.vanadebug" access="true"></right>
<right name="command.vanaset" access="true"></right>
<right name="command.animal" access="true"></right>
<right name="command.pos" access="true"></right>
<right name="command.car" access="true"></right>
<right name="command.spawncar" access="true"></right>
<right name="command.trains" access="true"></right>
<right name="command.air" access="true"></right>
```

After editing `acl.xml` on a running server, run `reloadacl` in the console.

Our resources ask for ACL rights through `<aclrequest>`; approve them once from the console (the
server saves it). `vana-lib` reads the data resources' `.map` files for everyone
(`general.ModifyOtherObjects`: reading another resource's files), every resource that imports shared
code from `vana-lib` on the server needs `loadstring` (see [libraries.md](libraries.md)), `vana-controls` runs other commands typed in
`/interact`'s box (`executeCommandHandler`, which still checks the player's own rights), and
`vana-player` creates an account per player (named after their serial):

```text
aclrequest allow vana-lib all
aclrequest allow vana-paths all
aclrequest allow vana-text all
aclrequest allow vana-controls all
aclrequest allow vana-vehicles all
aclrequest allow vana-population all
aclrequest allow vana-traffic all
aclrequest allow vana-peds all
aclrequest allow vana-player all
aclrequest allow vana-parked all
aclrequest allow vana-interiors all
aclrequest allow vana-shops all
aclrequest allow vana-gym all
aclrequest allow vana-activities all
aclrequest allow vana-wildlife all
aclrequest allow vana-encounters all
aclrequest allow vana-radio all
```

Then restart them (or the server).

### Resource settings

A resource's levers (densities, caps, aggression) are MTA's own resource settings: the `<settings>` in
its `meta.xml` hold the defaults, each public (`@name`), and a changed value is kept in the server's
`settings.xml` (`mods/deathmatch/settings.xml`), so it survives restarts and updates. Change them in
game or at the console with `/vanaset` (vana-core, restricted: `command.vanaset`), or in the admin
panel's resource settings:

```text
/vanaset                         the resources with settings
/vanaset wildlife                its settings and values ("vana-" can be left out)
/vanaset peds density 0.6        change one, at once
```

So far: vana-wildlife ([wildlife.md](wildlife.md)), vana-peds and vana-traffic (`density`, which
`/peds density` and `/traffic density` also set, and `maxPerPlayer`). A script binds its own with
vana-lib's `settings` module (server) and exports `getSettings`/`setSetting` for `/vanaset`.

Admins are listed by serial in `vana-player/config/player.lua` (`groups.Admin`), not in
`acl.xml`. Find a player's serial in the server log's CONNECT line.

## 6. Running and testing headless

From this repo's root (the `[vana]` folder). `tools/srv.sh` finds the server from its own location:

```sh
tools/srv.sh start
tools/srv.sh cmd "pathstest"       # path data integrity
tools/srv.sh cmd "lightstest"      # light colours and the stop rule over every lit road segment
tools/srv.sh cmd "lightcycletest"  # vanilla light cycle order and timing (runs at 10x game speed)
tools/srv.sh cmd "traffictest"     # traffic planner: 100 virtual cars x 300 s against the light cycle
tools/srv.sh cmd "pedtest"         # ped planner: 200 virtual peds x 300 s, road crossings against the walk signal
tools/srv.sh cmd "traintest"       # train timetable: 3 h of every service, stops, spacing, a train left on the line
tools/srv.sh cmd "airtest"         # airliner timetable and circuit: 4 h, no jumps, no planes meeting, no endless waits
tools/srv.sh cmd "poptest"         # population data and sampled spawns at known places
tools/srv.sh cmd "parkedtest"      # car generator data, spawning around Grove Street
tools/srv.sh cmd "wantedtest"      # wanted level thresholds
tools/srv.sh cmd "playertest"      # player database round trip, restart points
tools/srv.sh cmd "interiortest"    # entrances pair up
tools/srv.sh cmd "shoptest"        # shop stock and prices
tools/srv.sh cmd "gymtest"         # gym equipment and the hourly cap
tools/srv.sh cmd "vehicletest"     # kept cars: snapshots, lists, persistence, fuel, radio
tools/srv.sh cmd "wildlifetest"    # wildlife spawners, species files, the settings in force
tools/srv.sh log 50
tools/srv.sh stop
```

Console self-test commands only run from the server console.

## Linting

`tools/lint.sh [resource ...]` checks every script with `luac5.1` and `luacheck` (Ubuntu:
`sudo apt install lua5.1 lua-check`). It knows MTA's client and server functions
(`tools/luacheck/mta-*.txt`: the pinned Neon API stubs plus the functions Neon's luadefs register)
and each resource's own globals, so it reports typos, stray globals and dead code.
It also fails when a copy of the Map Editor line script (copied from `vana-lib` by
`tools/sync-libs.sh`) differs from its source, and it knows the globals each resource imports.

## Re-seeding config (optional)

Every vanilla-derived config says where it came from on its first line (`Origin:`). Canonical ones
were taken once (from `main.scm`, the mission scripts or the exe) and are only edited by hand; seeded
ones can be regenerated from your game files, which overwrites hand edits. The decompiled `main.scm`
isn't needed for setup: it's reading material for porting more of vanilla.

Placement data (car generators, entrances, shop points, vendors, gym equipment, minigame spots,
burglary doors) lives in the `[data]/vana-data-*` map resources and is edited in the Map Editor. Its
seed scripts (`seed_cargens`, `seed_interiors`, `seed_vendors`, `seed_gym`, `seed_minigames`,
`seed_burglary`) still work, through `tools/convert/to_maps.lua`: see [editor.md](editor.md).

The popcycle group table (`vana-population/config/groups.lua`) comes from the US 1.0 `gta_sa.exe`:

```sh
python3 tools/seed/seed_population.py "/path/to/GTA San Andreas" "vana-population/config"
```

The radio's track data (`vana-radio/config/radio_data.lua`: track IDs, durations, beats; see
[radio.md](radio.md)) comes from the US 1.0 `gta_sa.exe` and `audio/`:

```sh
python3 tools/seed/seed_radio.py "/path/to/GTA San Andreas" "vana-radio/config"
```

The mod garages' part IDs and colour palette (`vana-shops/config/carmods_data.lua`; see
[shops.md](shops.md)) come from `veh_mods.ide` and `carcols.dat`:

```sh
python3 tools/seed/seed_carmods.py "/path/to/GTA San Andreas" "vana-shops/config"
```
