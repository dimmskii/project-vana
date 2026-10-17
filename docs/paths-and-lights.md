# Paths and traffic lights

## NODES*.DAT

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
