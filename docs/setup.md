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

## 3. Game files you must copy

Rockstar's data files are not in this repository and must never be committed (see `.gitignore`).
Copy them from your own retail GTA:SA install (PC v1.0):

| From your GTA:SA folder | To | Used by |
| --- | --- | --- |
| `data/Paths/NODES0.DAT` … `NODES63.DAT` (64 files) | `[vana]/vana-paths/data/` | Path graph: ped and traffic routing, traffic lights |
| `data/shopping.dat`, `text/american.gxt` | `[vana]/vana-shops/data/` | Shop prices and stock; vanilla item names |
| `data/popcycle.dat`, `pedgrp.dat`, `cargrp.dat`, `peds.ide`, `vehicles.ide`, `pedstats.dat`, `ped.dat`, `info.zon`, `map.zon` | `[vana]/vana-population/data/` | Who spawns where (see population.md) |

Example on Linux:

```sh
cp "/path/to/GTA San Andreas/data/Paths/"NODES*.DAT "vana-paths/data/"
(cd "/path/to/GTA San Andreas/data" && cp popcycle.dat pedgrp.dat cargrp.dat peds.ide vehicles.ide pedstats.dat ped.dat info.zon map.zon \
   "/path/to/server/mods/deathmatch/resources/[vana]/vana-population/data/")
```

Keep the file names in upper case; the Linux server is case-sensitive. Check the copy with the
`pathstest` console command (step 5). It must print `PASS`.

## 4. mtaserver.conf

Inside `<config>`, replace the stock `<resource>` lines with:

```xml
<resource src="vana-paths" startup="1" protected="0" />
<resource src="vana-lights" startup="1" protected="0" />
<resource src="vana-population" startup="1" protected="0" />
<resource src="vana-traffic" startup="1" protected="0" />
<resource src="vana-peds" startup="1" protected="0" />
<resource src="vana-parked" startup="1" protected="0" />
<resource src="vana-services" startup="1" protected="0" />
<resource src="vana-interiors" startup="1" protected="0" />
<resource src="vana-shops" startup="1" protected="0" />
<resource src="vana-gym" startup="1" protected="0" />
<resource src="vana-player" startup="1" protected="0" />
<resource src="vana-core" startup="1" protected="0" />
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
```

After editing `acl.xml` on a running server, run `reloadacl` in the console.

`vana-player` creates an account per player (named after their serial) and needs one ACL request
approved, once, from the console:

```text
aclrequest allow vana-player all
```

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
tools/srv.sh cmd "poptest"         # population data and sampled spawns at known places
tools/srv.sh cmd "parkedtest"      # car generator data, spawning around Grove Street
tools/srv.sh cmd "wantedtest"      # wanted level thresholds
tools/srv.sh cmd "playertest"      # player database round trip, restart points
tools/srv.sh cmd "interiortest"    # entrances pair up
tools/srv.sh cmd "shoptest"        # shop stock and prices
tools/srv.sh cmd "gymtest"         # gym equipment and the hourly cap
tools/srv.sh log 50
tools/srv.sh stop
```

Console self-test commands only run from the server console.

## Re-seeding config (optional)

Gym equipment comes from `models/gta_int.img`:

```sh
python3 tools/seed/seed_gym.py "/path/to/GTA San Andreas" "vana-gym/config"
```

Vending machines and food carts come from the map IPLs and both IMGs:

```sh
python3 tools/seed/seed_vendors.py "/path/to/GTA San Andreas" "vana-shops/config"
```

Entrances and shop points come from the map IPLs and `models/gta_int.img`:

```sh
python3 tools/seed/seed_interiors.py "/path/to/GTA San Andreas" "vana-interiors/config" "vana-shops/config"
```

Hospital and police restart points come from `main.scm`:

```sh
python3 tools/seed/seed_restarts.py "/path/to/GTA San Andreas" "vana-player/config"
```


Parked car generators are seeded the same way from `models/gta3.img` and `main.scm`:

```sh
python3 tools/seed/seed_cargens.py "/path/to/GTA San Andreas" "vana-parked/config"
```


`vana-population/config/*.lua` is committed and meant to be edited. To regenerate it from scratch
from the decompiled `main.scm` (`data/script/main.txt`) and the US 1.0 `gta_sa.exe`:

```sh
python3 tools/seed/seed_population.py "/path/to/GTA San Andreas" "vana-population/config"
```
