# Aircraft (`vana-air`)

Airliners between Los Santos, San Fierro and Las Venturas; Dodos and Rustlers flying circuits at
Verdant Meadows; news helicopters circling the cities by day; helicopters and airliners passing
over now and then. Like the trains ([trains.md](trains.md)), the server keeps every aircraft where
its plan puts it at the time, and makes elements only near players, flown by the nearest player's
client. No radar blips.

## Legs: what an aircraft does over time (`legs.lua`)

Everything an aircraft does is a leg: timed frames (position, forward and right vectors, velocity,
landing gear), built the same on the server and on the client from a short description:

| Leg | What |
| --- | --- |
| `flight` | A vanilla flight recording, or a stretch of one |
| `taxi` | Turn on the spot, roll along a taxi route (speeding up to 8 m/s and slowing to a stop before each turn), turn to the spot's heading |
| `park` | Standing at a spot |
| `hold` | A lap of a holding circle, climbing to or coming down from a hold level |
| `spline` | Flown through points on a smooth curve at their speeds, banked into turns (planes up to 35 degrees, helicopters 20 with the nose a little down); points marked ground are on the runway, wheels down |

The client sets the aircraft's matrix and velocity every frame from the leg at that moment. Wheels
down near the ground, a plane is put on the ground by its own model's lowest point (bounding box)
rather than at the leg's height, blending back to it over the first 10 m up: the recordings were
made with an AT-400, and the parking and taxi heights are the ATP mod's (any other model sank into
the runway, gear out of sight, belly scraping). This is ours, not Neon's native recording playback:
that can't start partway through or move to another client. A
new owner gets the leg and how far into it the aircraft is, and carries on. Without a pilot (shot,
pulled out) the flying stops and the game's physics has it: what's in the air comes down.

## Data (`[data]/vana-data-air`)

| File | Elements | From |
| --- | --- | --- |
| `flights.map` | `flightpath` (from, to, gear up and down, duration), `flightframe` (5,216: position, forward, right, velocity) | Vanilla's `carrec041`-`049` in `data/Paths/carrec.img`: the airport ticket desk's flights (main.scm `PLANES`, which flies the AT-400 on 42-49; 41 only the ATP mod uses) |
| `airports.map` | `airport`, `airspot` (a plane waits here: its runway, flights that start or end there), `taxiroute` + `taxipoint` (linked by `nextid`), `circuit` + `circuitpoint` | Ours, seeded from the ATP airport-traffic CLEO mod's coordinates; the circuit through the flight school's rings ([activities.md](activities.md)) |
| `helis.map` | `helispot` (news: where a news helicopter circles, its radius and city) | Ours |

- **Converting the flights:** `lua5.1 tools/convert/flights_to_maps.lua [folder with carrec.img]`
  (from `vana-air/data/` by default) reads the recordings (32-byte frames: time, velocity /16384 in
  game units, right and forward /127, position), works out when the gear goes up (30 m over the
  runway) and down (60 m over it on the way in), and checks the result against the recordings. Ours,
  but close to vanilla's ticket desk (LS to LV: gear down at 105 s ours, 110 s vanilla).
- **airports.map and helis.map are ours,** edited in the Map Editor; nothing generates them.

## Airliners (`schedule.lua`)

Each plane (2 each of AT-400, Andromada, Shamal and Nevada: settings `at400`, `andromada`, `shamal`,
`nevada`) waits at a departure spot (45-120 s, ours), takes off on a recording to another airport,
lands, taxis to a departure spot there, and so on. Its pilot is `WMYPLT`, as in the ATP mod.

- **Booked as time windows:** runways, and every spot a roll or taxi passes within 30 m, with 10 s
  either side. A plane takes off once its runway and its takeoff roll are clear.
- **Landing:** 75 s before touchdown it asks for the landing roll, a taxi route to a departure spot,
  and that spot from then on. Refused, it holds: a circle through that point (600 m across, 55 m/s),
  at its own level over that runway (60 m higher and 300 m wider for each plane already holding),
  asking again every lap; cleared, it comes back down to the join point over a lap and rejoins the
  recording where it left it. A grounded plane can always leave, so the airports never lock up.
- **Planes the spots can't take** start in the air on their way in.
- **Taken:** a player who pulls the pilot out (on the ground) has the plane: it leaves the
  timetable, its bookings are dropped, and what it stands on is never booked through. A plane taken
  or wrecked is replaced by another of its model in the air, on its way in. The pilot walks off as
  one of vana-peds' pedestrians, fighting or fleeing by temper and fear.

The ATP mod's spots are all on the runways, and landings at Las Venturas and San Fierro roll through
the departure spots there, so each of those airports handles one plane at a time and busy planes hold
(in `airtest`, 4 planes: 114 flights and 265 holding laps in 4 hours; 8 planes: 124 flights, 602
laps). Stands off the runways, with taxi routes to them, add room without any code change.

## Verdant Meadows circuit

Two Dodos and two Rustlers (`circuit` models) fly the same loop round and round, spaced evenly
(93 s a lap): touch down from the west, roll, take off again, climb out east and round through the
flight school's rings at 100-110 m (touch-and-go training).

## Helicopters

- **News (ours):** one per city between 7:00 and 22:00, now and then (on air 8-15 min, off 10-20):
  in from 1.5 km away, laps of one of the city's heli spots at 18 m/s, away again. SAN News' Maverick
  (488), pilot and camera operator.
- **Following a wanted player (vanilla):** from 4 stars the second helicopter is the news one; that's
  vana-services ([services.md](services.md)).
- **Passing by (ours):** every minute, for each player with none around, a 15% chance of a helicopter
  flying past 150-400 m off, 110-180 m up (Maverick 50%, Sparrow 25%, Raindance 15%, Leviathan 10%).
- **Airliners overhead (vanilla's ambient planes, `CPlane::DoPlaneGenerationAndRemoval`):** every
  90 s, 12% for each player: one high over them (300-550 m), never in vanilla's no-plane zones and
  only the small ones (Shamal, Nevada) in its no-big-plane zones (downtown Los Santos and San Fierro;
  `CPlane::AreWeInNoPlaneZone`, `AreWeInNoBigPlaneZone`, gta-reversed). Vanilla's choice of where they
  come from isn't reversed yet; ours: straight past, 1.8 km each side.

## Commands

| Command | What |
| --- | --- |
| `/air` | Every aircraft, what it's doing, where (restricted: `command.air`) |
| `/air on`, `off` | Aircraft appear near players, or stay out of the world |
| `/air reset` | Start everything over |
| `/air at400\|andromada\|shamal\|nevada <count>` | How many airliners of each (kept; resets them) |
| `/air pass` | A helicopter flies past you now |
| `/air debug on\|off` | The `vana-air:sync` debug switch ([debug.md](debug.md)) |
| `airtest` (console) | 4 hours of the timetable and the circuit: every plane keeps flying, never jumps, no two within 25 m on the ground or in a hold, nobody waits 15 minutes, circuit planes never within 100 m |

## Not yet

- **In-game checks:** everything flown (orientation from the recordings, gear, the hold and its
  rejoin, handovers, a pilot shot in flight).
- **Stands and taxiways** off the runways (data only).
- **The ticket desk** (vanilla `PLANES`): buying a seat on the next real flight.
- **Riding along:** players boarding an airliner as passengers.
