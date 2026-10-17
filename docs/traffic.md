# Traffic, pedestrians and AI actors

## The decision: Lua decides, the engine drives

Neon offers two levels of driving AI:

- **Native wander** (`setPedDriveWander`), used by Neon's `native-vehicle-traffic`. GTA picks
  every turn and obeys traffic lights from its own internal clock. That clock is each client's
  private `CTimer`. Neon does not hook `CTrafficLights::LightForCars1/2` (only the visual light
  state), so native cars disagree with the lights players see, and with each other after an
  ownership handoff. Routes are also uncontrollable.
- **Native drive-to** (`setPedDriveTo`): GTA steers, keeps lanes, avoids cars and runs the real
  physics toward a point we choose. With the driving style `stop_for_cars_ignore_lights`, its own
  light logic is switched off.

`vana-traffic` uses the second, with all decisions in server-side Lua:

| Concern | Where |
| --- | --- |
| Route (every junction choice) | Server: `planner.lua`, over the retail path graph (`vana-paths`) |
| Traffic lights | Server: the synced MTA light state (`vana-lights`), with vanilla stop rules |
| Spawning, despawning, density, which client simulates which car | Server: `server.lua` |
| Steering, lanes, collision avoidance, physics | The owning client: native drive-to task (`client.lua`) |

This keeps long-term control in our hands. The same split, where the server sends an intent and
the owning client runs a native task, is how shop, mission and other scripted NPCs should be
built, so ambient traffic and scripted actors behave alike.

## Cars

### How a unit drives

- **Ownership:** each unit is one vehicle and one driver ped, simulated by one player's client.
  `setElementSyncer(..., true, true)` pins the owner. The server hands the unit over when that
  player leaves range or quits.
- **Waypoints:** every 500 ms the server reads the unit's position, moves it along its planned
  route and picks a target:
  - **Cruising:** the route node about 80 m ahead, driven to in `normal` mode. Each new target
    restarts the native task, which re-plans GTA's road route and slows the car near its target.
    So a new target is only sent once the unit is within 40 m of the current one, at most every
    1.5 s, and never when it would be identical.
  - **Stopping for a light:** the vehicle position that puts its **front bumper** 3 m before the
    light's navi point, in `accurate` mode, which brakes to a halt there. The owning client
    reports each model's front length (bounding box) once.
- **Spawning:** the server turns the engine on (server-created vehicles start with it off, and a
  native driver can't move them), and the owner gives the car a rolling start along its heading.
- **Light rules (vanilla):**
  - Red: stop, unless the line can't be made even braking hard (7 m/s²).
  - Amber: stop if it can be done comfortably (5 m/s²) at the stop point; otherwise commit and
    clear the junction.
  - A decision to stop is never reversed before green.
- **Routes:**
  - Routes prefer going straight, stay within one flood-fill group and exclude boat and
    emergency-only nodes.
  - They only follow a segment in a direction that has lanes. On a navi node, `leftLanes` run
    toward its target node and `rightLanes` away from it. This was checked against the retail
    roads: read the other way, the opposite carriageway of 93% of divided roads would lie on the
    right.
  - A car only turns back at a dead end, even against the lanes at one of the 16 one-way dead ends.
    A car caught bouncing in a dead-end fragment despawns once no player is within 80 m.
- **Occupants and encounters:** see `population.md`: passengers, collision reactions (panic,
  fight, jack, honk), and occupants joining the pedestrian population on foot.
- **Release:** jacked, wrecked or killed units are released to the world. Released elements are
  destroyed once no player is near.

## Pedestrians (`vana-peds`)

The same split. The server plans routes over the retail ped nodes and decides road crossings. The
owning client runs a straight native go-to (a `go_to` task sequence) toward the next sidewalk node
about 6 m ahead, re-targeted within 3.5 m.

GTA's own route follower (`setPedNavigateTo`), and the seek and flee tasks built on it, take slots
from the point-route and node-route pools, which hold only 64 each. A crowd of walkers using them
exhausted the pools and crashed clients (`gta_sa+0x2699E7`). So nothing of ours walks with route
tasks any more, and attack and flee orders wait while either pool has 12 or fewer free slots
(`engineGetPoolUsedCapacity`).

Every client leases Neon's `ambient-wander` event profile for these peds. Neon only lets the
current syncer act on it. The profile isn't tied to the wander task: GTA's own event responses
(avoiding peds and cars, reacting to aimed guns, gunfire and damage, fleeing, fighting) overlay
our task and hand back to it afterwards. The peds must therefore not be mission actors.

Road crossings use the intersection flags on the links:

- **Lit crossing:** wait at the kerb node until the ped signal is WALK (MTA state 2). Start any
  crossing early in the walk phase (6 s or more left); later, only one that can mostly be finished
  in the time left.
- **Unlit crossing:** wait until no moving vehicle is within 18 m of it.
- **No stopping halfway:** a ped already more than 3 m out on a crossing never stops. Arriving at
  the kerb never counts as being out.

Spawns reject routes that start on a crossing or bounce inside tiny isolated path fragments.
`pedtest [seed]` walks 200 virtual peds for 300 s each and checks that no crossing is started
without approval, alongside the same route checks as `traffictest`.

## Admin control

`/traffic on|off|clear|density <n>|debug on|off` and `/peds on|off|clear|density <n>` are
restricted commands. They need `command.traffic` and `command.peds` (granted to the `Admin` ACL in
`docs/setup.md`). `traffic debug on` makes owning clients report real speed and native autopilot
state, and logs every unit crawling while it isn't stopping for a light.

## Testing

`traffictest [seed]` (console only) drives 100 virtual units for 300 s each along real planned
routes under the vanilla light cycle, with realistic acceleration and braking. It checks:

- no red-light runs (amber commits that clear on red are reported separately)
- no U-turns except at dead ends
- only usable nodes in routes
- no stalled units

## Not yet verified in game

The server-side logic is tested; the client side needs a real client:

- Car path smoothing on curves looks off (noted in game; to tune later).
- Pedestrians in game: follow-route smoothness, kerb waits, native reactions, and whether cars
  stop for peds still on a crossing.
- Ownership handoff between two players.

## Not yet done

- Vehicle, driver and pedestrian models from popcycle, cargrp and pedgrp (placeholder pools for now).
- Spawn density from node traffic level and spawn probability, and spawning out of view.
- A planned-route dead end can leave a car re-targeting its last node (seen once in East Beach).
- Emergency vehicles; boats and aircraft; ped groups (couples, gangs) and cops.
