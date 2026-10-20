# Placement data and the Map Editor

Everything placed in the world (spots, markers, paths) is stored in MTA's own formats: `.map` files
in map resources, with an EDF (Editor Definition Format) per owning resource, so it can be edited in
MTA's Map Editor like any map.

## Where it lives

| Map resource (`[data]/`) | Element types | Owner (EDF) | Used as |
| --- | --- | --- | --- |
| `vana-data-player` | `restart`, `spot` | `vana-player` | `Restarts`; spots for `config/player.lua` |
| `vana-data-parked` | `cargen` | `vana-parked` | `CarGenerators` |
| `vana-data-interiors` | `entrance` | `vana-interiors` | `Entrances` |
| `vana-data-shops` | `shoppoint`, `vendor` | `vana-shops` | `ShopPoints`, `Vendors` |
| `vana-data-gym` | `gymequipment` | `vana-gym` | `GymEquipment` |
| `vana-data-encounters` | `encounter` | `vana-encounters` | `Encounters` (one per encounter, by `kind`: Bigfoot) |
| `vana-data-wildlife` | `wildlifespawner` | `vana-wildlife` | `WildlifeSpawners` (the animals' spots) |
| `vana-data-radio` | `speaker` | `vana-radio` | `Speakers` (placed by hand: no seed) |
| `vana-data-activities` | `minigamespot`, `burglaryhouse`, `burglarydoor`, `race`, `racecheckpoint`, `chiliadroute`, `routepoint`, `spot` | `vana-activities` | `MinigameSpots`, `BurglaryHouses`, `BurglaryDoors`, `RaceTable`, `ChiliadRoutes`; spots for the rule configs |

- **Schemas:** each owner's `config/maps.lua` describes its element types (fields, types, defaults,
  descriptions, editor look) and converts between elements and the Lua tables the code uses.
- **Loading:** `MapData` (`vana-lib`'s `map_data`, imported by each owner) reads them when the owner
  starts. Most data resources are never started: vana-lib reads their `.map` files for the server
  (`mapFileElements`; reading another resource's files takes `general.ModifyOtherObjects`, which
  only vana-lib asks for), so none of it goes to players. The few whose data client scripts read
  too (`clients = true` in the dataset: `vana-data-activities`, `-gym`, `-shops`) run as map
  resources at the top of the startup list ([setup.md](setup.md)). A missing data resource or file
  is a `[MapData] WARNING` in the server log. After editing a map, restart its owner (and the map
  itself, for the three that run).
- **Paths:** race checkpoints and Chiliad route points link to the next one with `nextid`, as in
  MTA race maps; a `race` / `chiliadroute` element points at its first one (`first`). Burglary doors
  link to their `house`. Entrances and doors carry the exit point they put you at (`ex`, `ey`, `ez`);
  an entrance or shop point with an `instance` is in that dimension (a copy of an interior: a second
  24/7 under its own name, 3000 and up; garages use 4000 and up, activities 20000 and up).
- **Spots:** world positions inside the rule configs (job stations and drop-offs, race entries,
  stunt coronas, the triathlon, girlfriends' places, school starts and rings, the start spawn...) are
  `spot` elements, and the configs read them by id, keeping every other field and comment in Lua:
  - `At("Jobs.trucking.start")` gives `{ x, y, z }` (plus `[4]`, the spot's `w`, when the entry had a
    4th value: a heading, radius or points, whatever the rules use it as)
  - `At("Jobs.freight.stations.1", { forward = 150000, back = 60000 })` fills the position into the
    given table; named spots (`shape="named"`, e.g. `Dating.girls.1.car`) fill `x`, `y`, `z`
  - `Spots("Jobs.trucking.destinations")` is the whole list (every spot with that `set`, in `index`
    order): add or remove drop-offs in the editor without touching the Lua. Sets marked `path` are
    routes and are drawn as such.
  The ids are the config paths, so the Lua says where each is used. A spot's `interior` is only
  where the editor shows it; the rules keep their own interior fields.
- **Notes:** a few types still have a `note` (which map model a burglary door belongs to). Every
  attribute of a running map's elements goes to every client, so data carries what the game uses,
  not provenance: where things came from is in [credits.md](credits.md) and these docs.

## Running the editor

The Map Editor runs as a server of its own, never inside the game server: on start it (through
`mapmanager`) stops every running map, and our `vana-data-*` resources are maps, so the game loses
its data; it also stops the resources whose definitions it loaded when it closes. The game's
`mtaserver.conf` lists no editor resources (`edf`, `editor*`, `freecam`, `move_*`, `msgbox`,
`tooltip`, `mapmanager`).

Neon's server comes with the editor's own config: `editor.conf` (port 22010, HTTP 22011, one
player, its own log `logs/editor_server.log`) and `editor_acl.xml` (the rights the editor needs).
Use them as they are, in the same `mods/deathmatch` as the game:

1. The editor's resources (from MTA's resource pack: `[editor]` with `edf`, `editor`,
   `editor_gui`, `editor_main`, `freecam`, `move_cursor`, `move_freecam`, `move_keyboard`, `msgbox`,
   `tooltip`; `[managers]/mapmanager`; and `freeroam`, which the editor checks for) are in
   `resources/`, next to `[vana]`.
2. Stop the game server (they share `settings.xml` and the databases), then start the editor one:
   `"MTA Server64.exe" --config editor.conf` on Windows, `./mta-server64 --config editor.conf` on
   Linux.
3. Connect to `127.0.0.1:22010` (or the client's own *Map Editor* button, if your client's server
   folder has `[vana]` too).

None of the game's resources run in the editor: opening a `vana-data-*` map loads its owners'
definitions (`edf:definitions`), and the editor starts those resources with their files only, no
scripts, so our controls, HUD and spawning stay out of its way. Our line script comes with the
definitions.

## Editing

1. In the editor server, open one of the `vana-data-*` maps.
2. Its definitions (e.g. `vana-activities`) load with it; if not, add them under *Definitions*.
3. Move, add or delete elements; their fields show in the properties panel with descriptions.
4. **Lines:** our EDF script draws paths as arrows, door-to-house links and exit points near the
   camera. `/vanalines` toggles them.
5. Save, then on the game server restart the owner (and the map too, if it's one of the three that run: e.g. `restart vana-data-activities`,
   `restart vana-activities`) to use the changes; commit the `.map`.

**No comments in data.** Saving rewrites the whole `.map` from its elements, so anything kept for
later is an element switched off, `enabled="false"` (the Flint County 24/7 door in
`entrances.map`, the mod's other Bigfoot spots in `encounters.map`), never XML commented out;
`tools/lint.sh` refuses comments in data maps beyond the converter's one-line type headers. Data
comes from the maps themselves, not from re-running seed scripts.

Admin helpers that move a spot in game print the element to paste instead (e.g. `/shoppoint`).

## Re-seeding

The seed scripts (`tools/seed/`) still read the retail game files, writing the old Lua tables into
a folder of your choice; `tools/convert/to_maps.lua` turns those into the `.map` (replacing every
element of that dataset, hand edits included) and regenerates the owner's EDF:

```sh
python3 tools/seed/seed_cargens.py "/path/to/GTA San Andreas" /tmp/seed
lua5.1 tools/convert/to_maps.lua --from /tmp/seed cargens
```

Spots aren't seeded: re-seeding keeps the map's spots. After changing a `config/maps.lua` schema,
`lua5.1 tools/convert/to_maps.lua --edf` regenerates the EDFs. `tools/convert/spots.lua` did the
one-time move of the rule configs' positions into spots (checking the rewritten configs give
exactly the original tables).

The car generator map also holds the 179 script generators taken from `main.scm`, which no seed
produces any more: re-seeding car generators drops them unless you merge them back. Editing in the
Map Editor is the normal way to change placement data now.

## Not converted

- **The road and footpath graph** (`NODES*.DAT`, read by `vana-paths`) stays retail binary data,
  copied at setup: about 37,000 nodes and their links aren't something to edit as editor elements.
- **Offsets relative to something else** stay in Lua config: school course layouts (from each test's
  start), shopkeeper layouts (per shop type, moved by each shop's offset), gym prop offsets.
- **Not positions, though they look like them:** Blood Ring's arena box (`Racing.bloodring.area`),
  the girlfriends' busy hours, and the quarry's reward cars (`{ model, x, y, z, heading }`, model first:
  still in Lua, to become spots with the model kept in Lua).
