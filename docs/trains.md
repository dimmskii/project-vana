# Trains (`vana-trains`)

Freight trains and the Brown Streak on the mainland line, trams in San Fierro. The server keeps
every train on its track all the time, like a timetable; a train only becomes elements while a
player is near it, simulated by one nearby player's client, the same split as traffic
([traffic.md](traffic.md)).

## The tracks as map data

GTA:SA's four tracks (`data/Paths/tracks*.dat`) ship converted in `[data]/vana-data-trains`
(never started: the server reads its file, as the paths' areas). `vana-trains/tracks_data.lua`
says what's in it and builds each track's tables from it.

| Element | File | Count | What |
| --- | --- | --- | --- |
| `tracknode` | `tracks.map` | 1,949 | A track point, id `track.index` (the game's own numbering), position, and `stop` on the six station stops |
| `trackcrossing` | `crossings.map` | 155 | A road or footpath link crossing a track at the same height (within 3 m): where they cross, `track`, the link's ends `a` and `b` (pathnode ids), `kind` (`vehicle` or `ped`) |
| `platformspot` | `platforms.map` | 45 | A place to wait for the train at a stop, facing the track, `stop` (its tracknode id) |

| Track | File | Nodes | Length | What |
| --- | --- | --- | --- | --- |
| 0 | `tracks.dat` | 926 | 18,107 m | The mainland line, a loop through all three cities; the six stops (Unity, Market, Cranberry, Yellow Bell, Linden, Sobell Rail Yards) |
| 1 | `tracks3.dat` | 300 | 5,128 m | The San Fierro tram loop |
| 2 | `tracks2.dat` | 67 | | A short line by Cranberry Station (not a loop) |
| 3 | `tracks4.dat` | 656 | | A long line from the Los Santos countryside to Cranberry Station (not a loop); through Los Santos it is the double track's second rails, 4 m beside track 0 |

- **Numbering:** the game numbers the tracks in the order it loads the files, not by the files'
  names; checked against Neon's copy of the default tracks (`Shared/gta/TrackNodes.h`).
- **Distances** along a track are the game's: node to node in 2D, the last node joined back to the
  first, so they are the rail distances `getTrainPosition` and `setTrainPosition` use (the
  mainland line comes out at 18,107 m, as the game has it).
- **Stops:** the DAT files' last column is 1 on exactly six nodes of the mainland line, at the
  stations. Trains that stop halt with their middle there (ours: the platforms' extent isn't in the data).
- **Converting:** `lua5.1 tools/convert/tracks_to_maps.lua [folder with tracks*.dat]` (from
  `vana-trains/data/` by default) writes the resource, then reads it back the way the game does and
  checks every node against the DAT files (positions keep MapData's 4 decimals). The DAT files are
  only needed for that ([setup.md](setup.md)).
- **Crossings and platforms:** `lua5.1 tools/convert/track_places.lua` works them out from the map
  data we ship (the path graph and `tracks.map`; no game files) and rewrites `crossings.map` and
  `platforms.map`, hand edits included. The path graph has no train-crossing flags at all (`train`
  is false on every link), so crossings are found by geometry. Platform spots are the ped path
  nodes beside each stop, 3-16 m from the track, 0.2-3.5 m above the rails, within 45 m along it, on
  the side whose platform edge is nearest (with nodes up to 4 m further out). Sobell Rail Yards has
  no platform. Most of the tram's crossings are street lanes along its line.

## The timetable (`schedule.lua`, `config/trains.lua`)

Each service runs a number of trains (settings `freight`, `passenger`, `trams`, 2 each; `/vanaset trains`
or `/trains <service> <count>`), spread evenly along its track. All trains of a track run the same
way, so none meets another head on. Every 500 ms each train:

- speeds up to its cruise (freight 18 m/s, Brown Streak 22, trams 11) at 0.5 m/s²;
- brakes (0.8 m/s²) so it stops 60 m behind any train ahead, whichever way that one faces;
- if it stops at stations (the Brown Streak), brakes to halt with its middle on each stop and waits
  20 s.

Vanilla instead spawns trains around the player; the speeds, counts and dwell are ours. vana-cars'
train models (the Mastodon and its wagons, the Streakliner) are commented out of the services,
waiting on a Neon fix: an added train model crashes the client ([cars.md](cars.md)).

## In the world (`server.lua`)

- **Made** when a player in dimension 0 outside interiors comes within 350 m of any part of a train:
  the engine, its cars (hooked on as trailers, 20 m apart on the rail), and a driver (one of four
  workmen, ours). The track and rail distance are set on every vehicle, so a train never lands on
  the wrong track. **Removed** once no such player is within 500 m and nobody is aboard.
- **Simulated** by the nearest such player (pinned, handed over past 300 m), like traffic units.
  The server sets the speed (`setTrainSpeed`, which reaches every client); where the train is comes
  back from that client's game each tick and becomes the timetable's, so nothing is teleported in
  sight. Positions arrive a fraction of a second late, so they're only compared with each other,
  never with the timetable's. A train that hasn't moved while it should have (nobody simulates it
  yet), one more than 20 m off its track and one more than 50 m from the timetable are put where the
  timetable has it, out of sight. After that, the server's copy of the position stays the old one
  until the owner's game syncs again; until then readbacks are ignored and the train runs on the
  timetable (put where that has it every 5 s, so it's right when it streams in).
- **Direction:** `setTrainDirection(true)` is taken to run the way rail distances grow; if a running
  train shows otherwise (three readbacks in a row going backwards), the server flips it once and
  logs it. A second time is only a warning in the log.
- **Vanilla:** no radar blips for trains; they can't be wrecked (damage-proof) and don't derail while
  they run themselves. They're `vana:managed`, so vana-vehicles never keeps one.
- **Taken:** a player who pulls the driver out drives the train: it leaves the timetable, the others
  keep clear of it, and it can derail, as in vanilla. The driver fights or flees by temper and fear
  (config/personalities.lua) and walks on as one of vana-peds' pedestrians; vana-services counts
  the jacking (`car_steal`). A train with nobody at the controls brakes to a halt. Once nobody is
  aboard, it's removed after 60 s (at once if derailed) as soon as no player is near, and a new train
  of its service goes back on the line where nobody is.

### Why it is built this way

The old `project-trains` resource drew a grey radar blip for every engine and car, and made its
trains on each client alone, teleporting them every frame. Every train out of a player's range had
its cars unhooked and parked at (0, 0, 1000) every frame: up to 150 cars with their decoration,
piled on one spot that sits 30-300 m from the interiors (the 24/7s, clothes shops, tattoo parlours,
Ammu-Nations, police stations). Entering one streamed the pile in and the frame rate collapsed.
Here nothing is parked anywhere, nothing follows a player's dimension, and a train nobody is near
has no elements.

## Level crossings

A crossing on the mainland line (and the two short lines) is closed while a train is within 12 s of
it at its speed (at least 50 m), is on it, or hasn't cleared it by 10 m; a taken train closes them
on both sides, as it may go either way. The tram's crossings never close: trams share the street,
as in vanilla. The schedule works it out every tick for every train, in the world or not.

- **Cars** (`vana-traffic`, `planner.lua`): a closed crossing on the way to a route node is a stop
  line 7 m before the first rails (4 m from their centre, plus the light stop's 3 m), in the car's
  lane; as with a red light, a car that can't stop braking at 7 m/s² commits and clears it. Roads
  over the double track stop before the nearer rails.
- **Pedestrians** (`vana-peds`, `planner.lua`): they wait 4 m before the first rails on their path;
  one already past that point walks on.
- **How they know:** vana-lib's `train_crossings` (`TrainCrossings.between`, `.refresh`) fetches the
  crossings from vana-trains (`getCrossings`) and the closed ones each tick (`getClosedCrossings`).
  Without vana-trains there are none.

## Platforms and passengers (`platforms.lua`)

Vanilla's trains let passengers off and take new ones on at stations (Neon switches that off); ours:

- **Waiting:** a station fills while a player is within 150 m: one at a time, at a free platform
  spot no closer than 20 m to a player, up to 60% of its spots by day (7:00-22:00) and 25% at night,
  at most 6. Civilians from vana-population. A station nobody is within 220 m of empties. Someone
  who strays 15 m from their spot (fleeing gunfire, say) is no longer waiting: vana-peds takes them.
- **Aboard:** a Brown Streak made near a player starts with each passenger-car seat (570: the
  driver's and the passenger seat) taken at even odds.
- **At a stop:** each passenger gets off at 40%, and each person waiting gets on at 70%, into the
  nearest free seat (native enter and exit tasks, run by the client that syncs them). The train waits
  up to 15 s longer for those still getting on. Anyone not in after 15 s is put in if they're at the
  car, or goes back to waiting; a passenger not out after 6 s is taken out onto the platform.
- **After:** whoever gets off walks on as one of vana-peds' pedestrians. Someone waiting or riding
  who is hurt by a player fights or flees by temper and fear, through vana-peds.

## Not yet

- **In-game checks:** platforms and boarding (the native enter task on a carriage), crossings
  holding traffic and pedestrians, the driver pulled out of the cab.
- **Tram stops:** the tram track has no stops in the data.

## Commands

| Command | What |
| --- | --- |
| `/trains` | Every train, where it is and what it's doing, and who waits at which station (restricted: `command.trains`) |
| `/trains on`, `off` | Trains appear near players, or stay out of the world (still on the timetable) |
| `/trains reset` | Every train back at its start |
| `/trains freight\|passenger\|tram <count>` | How many run (kept; resets the trains) |
| `/trains debug on\|off` | The `vana-trains:sync` debug switch ([debug.md](debug.md)) |
| `traintest` (console) | Three hours of the timetable: no train runs into another, the Brown Streak stops at every stop on each lap, nobody over cruise or braking harder than 2 m/s², a train left on the line holds the ones behind it, no crossing is open with a train on it, and crossings are open most of the time |
