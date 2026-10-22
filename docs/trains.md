# Trains (`vana-trains`)

Freight trains and the Brown Streak on the mainland line, trams in San Fierro. The server keeps
every train on its track all the time, like a timetable; a train only becomes elements while a
player is near it, simulated by one nearby player's client, the same split as traffic
([traffic.md](traffic.md)).

## The tracks as map data

GTA:SA's four tracks (`data/Paths/tracks*.dat`) ship converted in `[data]/vana-data-trains`
(never started: the server reads its file, as the paths' areas). `vana-trains/tracks_data.lua`
says what's in it and builds each track's tables from it.

| Element | Count | What |
| --- | --- | --- |
| `tracknode` | 1,949 | A track point, id `track.index` (the game's own numbering), position, and `stop` on the six station stops |

| Track | File | Nodes | Length | What |
| --- | --- | --- | --- | --- |
| 0 | `tracks.dat` | 926 | 18,107 m | The mainland line, a loop through all three cities; the six stops (Unity, Market, Cranberry, Yellow Bell, Linden, Sobell Rail Yards) |
| 1 | `tracks3.dat` | 300 | 5,128 m | The San Fierro tram loop |
| 2 | `tracks2.dat` | 67 | | A short line by Cranberry Station (not a loop) |
| 3 | `tracks4.dat` | 656 | | A long line from the Los Santos countryside to Cranberry Station (not a loop) |

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

## The timetable (`schedule.lua`, `config/trains.lua`)

Each service runs a number of trains (settings `freight`, `passenger`, `trams`, 2 each; `/vanaset trains`
or `/trains <service> <count>`), spread evenly along its track. All trains of a track run the same
way, so none meets another head on. Every 500 ms each train:

- speeds up to its cruise (freight 18 m/s, Brown Streak 22, trams 11) at 0.5 m/s²;
- brakes (0.8 m/s²) so it stops 60 m behind any train ahead, whichever way that one faces;
- if it stops at stations (the Brown Streak), brakes to halt with its middle on each stop and waits
  20 s.

Vanilla instead spawns trains around the player; the speeds, counts and dwell are ours.

## In the world (`server.lua`)

- **Made** when a player in dimension 0 outside interiors comes within 350 m of any part of a train:
  the engine, its cars (hooked on as trailers, 20 m apart on the rail), and a driver (one of four
  workmen, ours). The track and rail distance are set on every vehicle, so a train never lands on
  the wrong track. **Removed** once no such player is within 500 m and nobody is aboard.
- **Simulated** by the nearest such player (pinned, handed over past 300 m), like traffic units.
  The server sets the speed (`setTrainSpeed`, which reaches every client); where the train is comes
  back from that client's game each tick and becomes the timetable's, so nothing is teleported in
  sight. A train that hasn't moved while it should have (nobody simulates it yet) is put where the
  timetable has it, out of sight; so is one more than 20 m off its track.
- **Direction:** `setTrainDirection(true)` is taken to run the way rail distances grow; if running
  trains show otherwise, the server flips it once and logs it.
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

## Not yet

- **In-game checks:** speed units (m/s / 50) and direction, the readback, handing a train over,
  the driver pulled out of the cab.
- **Platforms:** people waiting at the stations, boarding and leaving the Brown Streak's
  carriages (570 has a driver's and a passenger seat).
- **Level crossings:** traffic and pedestrians held at the path graph's train crossings
  (`train` on links) while a train comes.
- **Tram stops:** the tram track has no stops in the data.

## Commands

| Command | What |
| --- | --- |
| `/trains` | Every train, where it is and what it's doing (restricted: `command.trains`) |
| `/trains on`, `off` | Trains appear near players, or stay out of the world (still on the timetable) |
| `/trains reset` | Every train back at its start |
| `/trains freight\|passenger\|tram <count>` | How many run (kept; resets the trains) |
| `/trains debug on\|off` | The `vana-trains:sync` debug switch ([debug.md](debug.md)) |
| `traintest` (console) | Three hours of the timetable: no train runs into another, the Brown Streak stops at every stop on each lap, nobody over cruise or braking harder than 2 m/s², a train left on the line holds the ones behind it |
