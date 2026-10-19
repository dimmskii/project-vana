# Vehicles: registry, persistence, fuel and radio stations (`vana-vehicles`)

## The registry

Every car a player gets into is **kept**: remembered, persisted exactly, and protected from the
cleanup that recycles traffic, parked and police cars.

- **Who holds a car:** the last player to drive it. A car no player has driven (riding in a taxi or
  a traffic car) is held by its last player passengers. Once a player has driven it, passengers
  never take it over.
- **Each player's list:** the last `registrySize` cars (10), most recently used first. Getting back
  into a car moves it to the front. The least recently used car falls off the end, and is released
  once it's on nobody's list.
- **Released cars** go back to ordinary cleanup: destroyed once empty with no player within
  `dropRadius` (250 m), unless traffic is still driving them.
- **Kept cars stay in the world**, wherever they were left. A traffic car whose unit despawns
  (nobody near) keeps its spot, driverless with the engine off; its driver and passengers go.
- **Excluded:** vehicles another resource manages (`vana:managed`: mission vehicles, quarry
  rewards, courier bikes) and owned reward cars (`vana:owner`).
- **Rejoining:** quitting in a kept car puts you back in your seat when you rejoin.

Other resources check the element data `vana:kept` (server-only) before destroying a vehicle:
`vana-traffic` (despawn and released cleanup), `vana-parked` (abandoned cars), `vana-services`
(responders and roadblocks). If anything destroys a kept car anyway, for example a resource that
created it stopping, it is rebuilt from a snapshot straight away.

### What is persisted

Everything the server knows about the car, in `vehicles.db` (sqlite, not committed):

- model, position, rotation, interior, dimension, variant, plate
- colours (all four, RGB), paintjob, upgrades, headlight colour, handling that differs from the model's
- health and every damage state: panels (7), doors (6) and their open ratios, lights (4), wheels (4), blown
- engine, lights override, locked, sirens, taxi light, landing gear, damage proof, frozen, alpha
- fuel, radio station, the trailer it tows

Kept cars are saved every `saveIntervalMs` (30 s, only when something changed), on exit, when a
player quits in one, and when the resource stops. A server restart rebuilds them; restarting only
`vana-vehicles` picks up the cars still in the world.

GTA:SA has no free-form body deformation: all visible damage is these component states, which MTA
syncs from the clients natively. So a snapshot is the complete damage.

## Fuel

After the `gasoline.cs` CLEO mod (bytecode read with `SASCM.INI`):

- A 30000-unit tank. Fuel burns only while a player drives, per frame at 25 fps by speed band:
  1 unit below 45 m/s, 2 to 85, 3 to 110, 4 to 140, 5 above, 1 in the air, none standing still.
  About 20 minutes of ordinary driving per tank.
- Empty: the engine dies and won't start again.
- Pumps: the mod's 16 gas station spots. Roll up to one (within 1.5 m) with less than 29000 in the
  tank: the car is held while it fills, 300 units per $1 (a full tank is about $100), paid at the end.
- A car first driven by a player has 10-100% of a tank (the mod: anything from empty).
- Bicycles, boats, aircraft and trains don't use fuel. Ped drivers don't burn fuel.
- The gauge sits above the radar.

## Dashboards

Each vehicle has a dashboard skin (`vana:dashboard`), picked by the server the first time a player
gets in: by model (`models` in `config/dashboards.lua`), else `default`; bicycles and trains have none.
Kept cars keep theirs. A skin names a TXD and lays out its parts (images, needles, a lamp, text) in
vanilla's 640 x 448 HUD space, anchored to the bottom right and scaled with the screen height; the
client reads the TXD once with `sa_txd.lua`. Without a skin (or if it fails to load) the plain fuel
gauge above the radar stands in.

- **`gasoline`** (the default), from the gasoline mod's `gasoline.txd`: the speedometer (0-260 km/h),
  the fuel dial built into it, the fuel lamp (red below 5000), the lock icon when locked, and the
  nitro dial when nitro is fitted. Positions are the mod's own. Its needles' angles (`zero`, `per`)
  were measured on the textures, as the mod's formulas don't fit this dial; checked by rendering the
  dial offline at 0, 60, 140 and 260 km/h, but still to confirm in game.

## Radio

- **Station per car** (`vana:radio`: a `vana-radio` station ID, 1 Playback FM .. 11 WCTR, 0 off),
  first picked as vanilla (`CPed::SetRadioStation`): one of the driver's two favourites from
  `peds.ide`, else the model's default (engine vehicle audio settings, via gta-reversed). Police and
  other emergency vehicles, and vehicles without a radio, get no station. The station is persisted
  with the car.
- **Playing it, switching and the outside radio** are `vana-radio`'s: see [radio.md](radio.md).

## Performance parts (`performance.lua`)

Ours, sold at the mod garages after the vanilla parts (any car the garages take). A car's tune is
element data `vana:tune` (category -> level, synced), kept with it like its colours (snapshot
`tune`, also for a car saved mid-visit to a garage). Its handling is always worked out from the
model's original handling (`getOriginalHandling`) with the levels' multipliers on top, so levels
never compound and a rebalanced config reaches every car.

| Category | Levels (price) | Scales the car's own |
| --- | --- | --- |
| Engine | stage 1 ($2500), 2 ($6000), 3 ($12000) | torque x1.10 / 1.20 / 1.32, top speed x1.04 / 1.08 / 1.12, rev inertia x0.95 / 0.90 / 0.85 |
| Turbo | one ($20000), on top of any stage | torque x1.25, top speed x1.06; a whine |
| Brakes | sport ($2000), race with ABS ($5000) | braking x1.2 / x1.4 |
| Suspension | sport ($3000), race ($7000) | stiffness, damping, anti-dive; race also steering lock x1.05 |
| Tyres | sport ($2500), race ($6000) | grip x1.08 / 1.16, sliding grip x1.04 / 1.08 |
| Armour | armour ($8000), heavy ($18000) | damage taken x0.7 / 0.45, weight x1.05 / 1.12 |
| Lightweight | kit ($7000) | weight x0.88, turn mass x0.9, drag x0.95 |
| Drivetrain | AWD conversion ($9000) | all-wheel drive |

- **The turbo's whine** (`turbo_client.lua`): every client plays a looped game sound on running
  turbo cars within 60 m: GENRL bank 131 (the vehicle generic bank, global 138), sound 10 (the
  Hydra's front jet; 29 is a generic whine), pitched from 0.75 to 1.6 with speed against the car's
  own top speed, louder on the throttle. `/turbosound <bank> <sound>` auditions another, `off`
  silences it (per player). The game's own engine sound is untouched.
- **Traffic:** tuned street racers also roll performance parts (engine 1-2, a turbo now and then,
  tyres, brakes).
- `performancetest` (console): a car tuned fully and back gets exactly its model's handling again.

## Cleaning up (`/cleanvehicles`)

Admin (`command.cleanvehicles`, granted to `Admin` by vana-player):

- `/cleanvehicles`: every empty vehicle nobody keeps (abandoned traffic, parked cars, dropped cars).
- `/cleanvehicles all`: every empty vehicle, kept ones too.
- `/cleanvehicles <player>`: that player's kept vehicles (a unique part of the name is enough).

Kept cars removed this way come off every player's list and out of the registry first, so they
aren't rebuilt. Never removed: a vehicle with anyone in any seat (player or ped), a trailer such a
vehicle tows, mission and reward cars (`vana:managed`, `vana:owner`), trains. Parked cars come back
from their generators as usual. `vehicletest` checks the occupied and kept cases.

## Ambient cars' parts (`tuning.lua`)

Traffic, parked cars and random-event cars get parts as they're made (`tuneRandomly`, config
`tuning`); emergency responders don't.

- **Vanilla** (`CAutomobile`'s constructor): models whose handling has `HYDRAULIC_GEOM` (0x10000:
  the lowriders) get hydraulics one time in four.
- **Ours:** 15% of taxis have nitro (after vanilla's "all taxis have nitro" cheat); 35% of street
  racers and 30% of lowriders are tuned (random parts they fit in 2-6 / 1-4 slots, and a random
  paintjob 40% of the time where the model has them); 3% of anything else has other wheels.
- `tuningtest` (console): builds 400 each of a Voodoo, a taxi, an Elegy and an Admiral and logs the
  rates (Voodoo hydraulics ~25%, taxi nitro ~15%).

## Testing

- `vehicletest` (console): snapshot/rebuild round trip, list rules (size, most recent first,
  re-entering, release), persistence in the database, rebuilding a destroyed kept car, fuel bands
  and radio picks.
- `vehicletest keep`, then restart (or stop and start) `vana-vehicles`, then `vehicletest check`:
  one kept car survives the restart exactly.

## Not yet verified in game

- The fuel gauge's position at other resolutions; the refuel hold at each pump.

## Not yet done / known gaps

- Pump blips: SA has no fuel radar icon; pumps could get a vana-map category once there's an icon.
- Not persisted (no server API): dirt level, nitro charge, the police scanner state.
- Kept wrecks stay until they fall off every list.
- Peds are not persisted (a kept traffic car loses its driver when it despawns).
- Other persistence candidates: dropped weapons and money pickups, bodies.
