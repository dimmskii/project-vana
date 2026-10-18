# Vehicles: registry, persistence, fuel and radio (`vana-vehicles`)

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

## Radio

- **Station per car** (`vana:radio`, an MTA channel: 1 Playback FM .. 11 WCTR, 0 off), first picked
  as vanilla (`CPed::SetRadioStation`): one of the driver's two favourites from `peds.ide`, else the
  model's default (engine vehicle audio settings, via gta-reversed). Police and other emergency
  vehicles keep the native police scanner; some vehicles have no radio.
- **The driver chooses**; passengers only when no player drives.
- **Live stations:** one client listening in a car leads each station. It reports its native radio
  state (Neon `getRadioPlaybackState`: track, position, queue) on every new track and every 15 s.
  Everyone else tuned in applies it (`setRadioPlaybackState`), so the whole server hears the same
  song at the same moment.
- **From outside:** a running car's radio is heard within 25 m, muffled (BASS parametric EQ), as a
  3D `playSFX3D("radio", archive, track)` sound in sync with the station. Native track IDs map to an
  archive and track through `TrakLkup.dat`'s order (track counts per archive in `config/radio.lua`).
  A station nobody listens to in a car gets its tracks picked by the clients hearing it from
  outside, shared through the server the same way.

## Testing

- `vehicletest` (console): snapshot/rebuild round trip, list rules (size, most recent first,
  re-entering, release), persistence in the database, rebuilding a destroyed kept car, fuel bands
  and radio picks.
- `vehicletest keep`, then restart (or stop and start) `vana-vehicles`, then `vehicletest check`:
  one kept car survives the restart exactly.
- `radiostatus` (console): live stations, their leaders, and every player's car and station.

## Not yet verified in game

- The radio switch flow (driver vs passenger), followers jumping to the leader's track, and how
  the outside radio sounds (volume, muffling, range).
- The fuel gauge's position at other resolutions; the refuel hold at each pump.

## Not yet done / known gaps

- Pump blips: SA has no fuel radar icon; pumps could get a vana-map category once there's an icon.
- Not persisted (no server API): dirt level, nitro charge, the police scanner state.
- Kept wrecks stay until they fall off every list.
- Peds are not persisted (a kept traffic car loses its driver when it despawns).
- Other persistence candidates: dropped weapons and money pickups, bodies.
