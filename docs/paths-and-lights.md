# Paths and traffic lights

## The path graph as map data

The game reads the path graph from map data: one map resource per area,
`[data]/[paths]/vana-data-paths-00` … `-63` (editable in the Map Editor with the `vana-paths`
definitions), never started, read by the server from its files (vana-lib's `map_data`).
`vana-paths/paths_data.lua` says what each element holds and builds each area's tables from them,
the same tables the DAT reader gave, so routing, lights, traffic and peds are as before:

| Element | Count | What |
| --- | --- | --- |
| `pathnode` | 68,237 | A node, id `area.index` (the game's own): position, `kind` (vehicle or ped), `width`, `flood` (which connected network), `traffic`, `spawn`, `roadblocks`, `boats`, `emergency`, `highway`, `notHighway`, `parking`, `extraFlags` (bits of unknown use, as the game had them) |
| `pathlink` | 71,811 | A connection, once (the game lists it in both nodes): `a`, `b`. A vehicle link carries its navi node (it stands at it): `dir`, `width`, `lanesLeft`, `lanesRight`, `lightDir`, `light`, `train`; `naviNode` for the 4 whose navi node belongs to neither end. `crossingA`/`crossingB` per side; `length` only for the 1,290 that aren't the distance rounded down. A ped link stands at its middle |
| `patharea` | 64 | The 384-byte trailer, as `index:value` pairs (a few 1s and 3s in 21 areas) |

Left out: the filler block (always `0000FFFF`), each node's runtime pointer, constant cost and
stored link start and count, and the order within each node's link list. The two navi nodes the game
shares between two links each are one per link (31,468). A field at its default isn't written:
14 MB for the 64 areas.

- **Converting:** `lua5.1 tools/convert/paths_to_maps.lua [folder with NODES*.DAT]` (from
  `vana-paths/data/` by default) writes the 64 resources, then reads them back the way the game
  does and checks every node and link against the DAT files.
- **Loading:** an area loads when first asked for, and every area in the background after start
  (about 8 s in all); a missing area is a warning in the server log.
- **Rebuilt, not trusted:** each node's link count and list, vehicle nodes before ped nodes (an
  added node gets the next index), and each link's length. A link crossing areas lives in its navi
  node's area (a ped link: its `a`'s); the areas around one are searched for it.

## Editing paths

Open an area's resource (`vana-data-paths-15` is Grove Street's) in the Map Editor's own server
([editor.md](editor.md)). Near the camera our line script draws, refreshed twice a second:

| Drawn | Means |
| --- | --- |
| Cross at a node | Its type: cyan road, orange highway, blue boat path, red emergency only, purple parking, green ped path |
| Curve, node to node | A vehicle link, through its navi node (the link element stands there): drag the link to bend it. Dimmer: quieter traffic |
| Straight line | A ped link |
| Arrowhead halfway | One-way (lanes only one way: left lanes run toward the navi node's own node, `naviNode` or `a`) |
| Yellow cross | A traffic light at the navi node; white: a train crossing |
| Thick yellow line | A ped crossing (`crossingA`/`crossingB`) |
| Red stub | The other end is in an area that isn't open |

- **Moving** a node or a link is all it takes; lengths and link lists are rebuilt when loaded.
- **A new node:** place a *Path node*; its id can be anything unique (it gets the next index;
  vehicle nodes go before ped nodes). Set `kind` to `vehicle` for a road.
- **A new link:** place a *Path link* where its lane point goes and type its ends' ids in `a` and
  `b` (a node in a neighbouring area by its full id). A road link needs `dir` (the lane direction,
  e.g. `0.7,-0.7`); without it, it's a ped link.
- **Connectivity:** routing only joins nodes of one `flood` network; a new road joining two keeps
  each node's own value until we recompute them (not yet).
- **Saving** writes every field, defaults included, so an edited area's file grows (about twice);
  it reads the same.

Not checked in the editor itself yet: the drawing, and the editor coping with an area's thousands of
elements (the largest, 41, has about 9,000).

## NODES*.DAT (the converter's source)

There are 64 files, one per 750 × 750 area. The areas form an 8 × 8 grid starting at
(-3000, -3000):

```
area = floor((y + 3000) / 750) * 8 + floor((x + 3000) / 750)
```

17 retail nodes lie just outside their own file's area.

Layout, verified on all 64 retail files (`vana-paths/paths_format.lua`):

| Section | Entry size | Count |
| --- | --- | --- |
| Header | 20 | 1: nodes, vehicle nodes, ped nodes, navi nodes, links (`uint32` each) |
| Path nodes (vehicle first, then ped) | 28 | nodes |
| Navi nodes | 14 | navi nodes |
| Links (`area`, `node`) | 4 | links |
| Filler | 768 | 1 |
| Navi links (bits 0-9 navi index, 10-15 area) | 2 | **links** |
| Link lengths | 1 | **links** |
| Intersection flags (bit 0 road cross, bit 1 ped light) | 1 | **links** |
| Trailer | **384** | 1 |

The wikis get the bold entries wrong or leave them ambiguous: they give a 192-byte trailer and
an unclear count for the intersection flags.

Positions are `int16 / 8`, node width is `uint8 / 8`, and navi direction is `int8 / 100`.

Two more facts checked against the retail files:

- **Navi lanes:** `leftLanes` (bits 8-10) run toward the navi node's target node and `rightLanes`
  (bits 11-13) away from it.
- **Crossing flags:** the road-cross and ped-light flags are set on one link direction only for
  1,547 of about 1,700 crossings. Treat them as properties of the segment.

Retail totals: 30,587 vehicle nodes, 37,650 ped nodes, 31,466 navi nodes and 143,622 links.
1,697 links are road crossings, and 1,294 of those have a ped light.

## Traffic lights

### Which lights belong to which navi node

Bits 16-17 of a navi node's flags give its light type: 1 = north-south, 2 = west-east. 823 retail
navi nodes are type 1 and 866 are type 2. In vanilla, `LightForCars1()` drives type 1 and
`LightForCars2()` drives type 2.

MTA replaces those with a single synced state from `getTrafficLightState()`:

| State | N-S (type 1) | W-E (type 2) | Ped signal |
| --- | --- | --- | --- |
| 0 | green | red | don't walk |
| 1 | amber | red | don't walk |
| 2 | red | red | **walk** |
| 3 | red | green | don't walk |
| 4 | red | amber | don't walk |
| 5 | green | green | don't walk |
| 6 | amber | amber | don't walk |
| 7 | amber | green | don't walk |
| 8 | green | amber | don't walk |
| 9 | off | off | off |

Source: Neon `Client/multiplayer_sa/CMultiplayerSA.cpp`, the
`HOOK_CTrafficLights_Get{Primary,Secondary}LightState` hooks. The game's visual lights pick
primary (N-S) or secondary (W-E) from each light object's heading
(`CTrafficLights::FindTrafficLightType`).

### Stop rule

From `CTrafficLights::ShouldCarStopForLight` (gta-reversed), restated geometrically and checked
against the retail data:

- A navi node's direction always points toward its **attached** node (the node in its
  target-area and target-node fields).
- Bit 14 (direction flag) selects which way the light governs traffic:
  - **Flag 1:** traffic heading toward the attached node. In 1,047 of 1,213 retail cases the
    attached node is the junction.
  - **Flag 0:** traffic heading away from the attached node. In 423 of 476 cases the other end is
    the junction.
- A car governed by the light stops if the light isn't green (amber counts as stop) and the navi
  point is between 0 and 12 units ahead of it along its direction of travel.

### Cycle

| | N-S green | N-S amber | W-E green | W-E amber | All red (peds walk) | Total |
| --- | --- | --- | --- | --- | --- | --- |
| Vanilla SA (`CTimer` ms / 2 & 16383) | 10 s | 2 s | 10 s | 2 s | 8.77 s | 32.77 s |
| MTA built-in (`CGame::ProcessTrafficLights`) | 8 s | 3 s | 8 s | 3 s | 2 s, between N-S and W-E only | 24 s |

`vana-lights` locks the lights and drives MTA states 0 → 1 → 3 → 4 → 2 with the vanilla
durations, scaled by game speed. Vanilla's flashing "don't walk" (the last 2 s of the ped
phase) has no MTA state; the lights stay at state 2 until the cycle restarts.
