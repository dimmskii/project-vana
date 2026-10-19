# Placement data and the Map Editor

Everything placed in the world (spots, markers, paths) is stored in MTA's own formats: `.map` files
in map resources, with an EDF (Editor Definition Format) per owning resource, so it can be edited in
MTA's Map Editor like any map.

## Where it lives

| Map resource (`[data]/`) | Element types | Owner (EDF) | Used as |
| --- | --- | --- | --- |
| `vana-data-player` | `restart` | `vana-player` | `Restarts` |
| `vana-data-parked` | `cargen` | `vana-parked` | `CarGenerators` |
| `vana-data-interiors` | `entrance` | `vana-interiors` | `Entrances` |
| `vana-data-shops` | `shoppoint`, `vendor` | `vana-shops` | `ShopPoints`, `Vendors` |
| `vana-data-gym` | `gymequipment` | `vana-gym` | `GymEquipment` |
| `vana-data-activities` | `minigamespot`, `burglaryhouse`, `burglarydoor`, `race`, `racecheckpoint`, `chiliadroute`, `routepoint` | `vana-activities` | `MinigameSpots`, `BurglaryHouses`, `BurglaryDoors`, `RaceTable`, `ChiliadRoutes` |

- **Schemas:** each owner's `config/maps.lua` describes its element types (fields, types, defaults,
  descriptions, editor look) and converts between elements and the Lua tables the code uses.
- **Loading:** `tools/lib/map_data.lua` (`MapData`, copied into each owner) reads the elements when
  the owner starts. The data resources start first (top of the startup list in `mtaserver.conf`,
  see [setup.md](setup.md)) and keep running when an owner restarts.
- **Paths:** race checkpoints and Chiliad route points link to the next one with `nextid`, as in
  MTA race maps; a `race` / `chiliadroute` element points at its first one (`first`). Burglary doors
  link to their `house`. Entrances and doors carry the exit point they put you at (`ex`, `ey`, `ez`).
- **Notes:** `note` keeps what used to be a comment next to an entry (e.g. which map model a burglary
  door belongs to).

## Editing

1. Start the Map Editor (`editor` resource) and open one of the `vana-data-*` maps.
2. Its definitions (e.g. `vana-activities`) load with it; if not, add them under *Definitions*.
3. Move, add or delete elements; their fields show in the properties panel with descriptions.
4. **Lines:** our EDF script draws paths as arrows, door-to-house links and exit points near the
   camera. `/vanalines` toggles them.
5. Save, then restart the owning resource (e.g. `restart vana-activities`) to use the changes.

Admin helpers that move a spot in game print the element to paste instead (e.g. `/shoppoint`).

## Re-seeding

The seed scripts (`tools/seed/`) still read the retail game files, writing the old Lua tables into
a folder of your choice; `tools/convert/to_maps.lua` turns those into the `.map` (replacing every
element of that dataset, hand edits included) and regenerates the owner's EDF:

```sh
python3 tools/seed/seed_cargens.py "/path/to/GTA San Andreas" /tmp/seed
lua5.1 tools/convert/to_maps.lua --from /tmp/seed cargens
```

The car generator map also holds the 179 script generators taken from `main.scm`, which no seed
produces any more: re-seeding car generators drops them unless you merge them back. Editing in the
Map Editor is the normal way to change placement data now.

## Not converted

- **The road and footpath graph** (`NODES*.DAT`, read by `vana-paths`) stays retail binary data,
  copied at setup: about 37,000 nodes and their links aren't something to edit as editor elements.
- **Offsets relative to something else** stay in Lua config: school course layouts (from each test's
  start), shopkeeper layouts (per shop type, moved by each shop's offset), gym prop offsets.
- **World spots inside the activity rules** (job stations and drop-offs, race entry markers,
  stunt coronas, the triathlon, girlfriends' places) are the next pass.
