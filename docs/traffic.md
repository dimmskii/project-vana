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
- **Lanes:** path nodes and navi points sit on the middle of the road, so every target (cruising
  and stop points alike) is moved into the unit's lane: 5.4 m lanes (the engine's width), right of
  the centre line on two-way roads, spread across a one-way road. A unit keeps the lane it's in.
  `traffictest` fails if any light stop lands on the centre line of a two-way road.
- **Bikes, bicycles and quads:** their riders stay ambient peds with GTA's ambient event profile while
  riding (not mission actors), so collisions knock them off as in vanilla.
- **When a unit ends** (jacked, driver killed or out, wrecked, bailing out): its occupants are
  released (automatic sync) and become vana-peds pedestrians once on foot. Those still seated stop
  being mission actors (so a jacked car's passenger bails out, as in vanilla) and are told to get out
  by whoever syncs them, every 2 s; after 5 tries they're taken out of the car, beside it. Before
  this, a passenger of a car you jacked sat on in it as a mission actor nothing ran.
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
- **Kept cars:** a car a player has been in is remembered by `vana-vehicles` (see
  [vehicles.md](vehicles.md)) and never destroyed here. A kept unit that despawns leaves its car
  where it is, driverless, with the engine off.
- **Radio:** a spawned car tunes to one of its driver's favourite stations (`peds.ide`).

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

**Keeping them walking.** A ped can stop for three reasons; each has its own recovery:

- **Nobody simulates it** (it freezes in its pose, even in mid-air): every tick the server checks the
  ped's syncer is still its owner, and if not, pins it back (`setElementSyncer(..., true, true)`) and
  sends its orders again. vana-services does the same for its crews.
- **The order didn't take** (it stands idle): a walk that arrives stays the ped's task, standing
  still at its end, and GTA refuses a new walk over it, or over one still walking, or queues the new
  one and quietly drops it; so nearly every re-target used to fail, and the ped stopped at the old
  point. Our walks are plain go-tos, so the old one is cleared (`killPedTask`) before each new one;
  a flee sequence (route tasks) never is. A reaction of GTA's own that ends also leaves the ped idle.
  Twice a second the owner's client checks each walk: moving, arrived, the sequence running (not
  just standing at its end), or busy with a reaction (falling, getting up, reacting, fleeing).
  Otherwise, after 0.8 s it gives the order again; after 6 tries in vain (a ped that's blocked: GTA
  ends a walk short when it can't get through) it asks the server for a fresh route. A fight against
  a target the owner hasn't streamed in runs to where the target is until it can attack; one still
  idle after its 5 re-issues is called off and the ped walks on. vana-services' clients watch
  their crews' walk, get-in and get-out orders the same way (5 tries in 25 s), clearing an old walk
  the same way.
- **The target can't be reached:** not moving 1.5 m in 8 s, the server sends the target again, and
  after two sends a fresh route from where the ped stands. Waiting at a kerb counts for up to 60 s,
  then the ped walks somewhere else. A follower (couples, gangs) more than 4 m from its slot gets its
  slot sent again the same way; one 25 m behind leaves the group and walks on alone.

A ped hanging in the air (not on the ground, not falling, for 1 s) is put back on the ground under it,
and no walk is given meanwhile. GTA can keep one pinned there (waiting for collision): the second time
it's also nudged downwards, the third time it's removed even in view. With no ground loaded under it
and out of view, it's removed at once. With `vana-peds:orders` on (docs/debug.md), every one of these is logged.

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

- Lane-offset targets: how cars hold their lane through turns and at lights.
- Riders knocked off bikes (ambient event profile while riding).
- Jacked crews, passengers' answers and holdups of drivers (see population.md).

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
