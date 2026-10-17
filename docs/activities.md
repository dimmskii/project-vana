# Activities (`vana-activities`)

Ports of vanilla's always-available activities from `main.scm`: burglary, dating, the vehicle side
jobs, schools, races and challenges, minigames and gambling. Agreed rules:

- **Solo instances.** Each player runs their own activity: their own targets, timers and rewards.
  Others can see what's spawned but can't take part or take over progress.
- **Vanilla rewards, saved.** Permanent perks are earned per player and kept with `vana-player`.
- **Vanilla first.** Rules, numbers and text come from the mission scripts and `american.gxt`;
  anything we had to invent is marked "ours" in the configs.

## Framework (`core/`)

- **Sessions** (`core/server.lua`): one activity per player at a time. A session owns what it
  spawns (vehicles, peds, objects, and blips and markers only its player sees) and its timers, and
  cleans everything up when it ends: passed, failed, cancelled, wasted, quit or resource stop.
- **Starting:** vehicle jobs start like vanilla's R3 launcher: drive the right vehicle and press the
  sub-mission key (`sub_mission`, "2" on PC). Pressing it again during the job cancels it. Getting
  into such a vehicle shows vanilla's tutorial help once.
- **HUD** (`core/client.lua`): vanilla-style big titles, objectives (subtitles), the help box and
  on-screen counters (numbers, money, bars and timers). GXT formatting is rendered: colours, new
  lines and `~k~~CONTROL~` key names (mapped to MTA controls).
- **Text** (`core/gxt.lua`): reads `data/american.gxt` (see docs/setup.md), MAIN and the missions'
  own tables (e.g. `BURGLAR`), with `~1~` numbers filled in.
- **Progress and perks:** `vana-player`'s `getProgress` / `setProgress` keep levels, totals and
  earned perks (`perk.<name>`); earned perks are re-applied on every spawn.
- **Private dimensions:** instanced places (burglary houses) use a dimension per player
  (`privateDimensionBase` in `config/activities.lua`).
- `activitytest` (console) checks the text and each activity's data.

## Burglary

Vanilla `BURGJB` (the mission) and `BURG_BRAINS` (residents).

- **Start:** in a Boxville between 20:00 and 06:00, press the sub-mission key. CJ puts the
  balaclava on; counters show the time to daylight and the night's takings.
- **Houses:** 622 burglary doors lead into 20 furnished house interiors, seeded by
  `tools/seed/seed_burglary.py`. Most doors are "enex" effects inside the house models, not IPL
  entries. The seeder reads both and places the model ones through the models' IPL placements.
  The doors (yellow arrows) only work for a burglar, at night; `vana-interiors` no longer opens
  burglary-access doors (flag `0x1000`) to anyone. Each burglar's houses are in their own
  dimension. A house keeps its remaining loot (and resident) for the night.
- **Stealing:** walk up to an item and press enter/exit: CJ lifts it with the engine's own
  pickup-and-carry (Neon `pickUpPedObject`). Carry it to the back of the van (6 m behind its centre)
  and press enter/exit to load it.
- **Noise:** with someone asleep in the house, the noise bar fills from the engine's noise level at
  CJ (Neon `getPedNoiseLevel`) with vanilla's formula (level x 1.6, minus 20, decaying 1% a frame).
  Full, the resident wakes: men fight or put their hands up, women cower or put their hands up, gang
  members fight. CJ has 10 seconds to get out, or gets 3 stars.
- **Selling:** with goods in the van, the nearest lock-up (LS, SF, LV) shows on the radar; its
  garage opens as the van arrives. Parked inside with no wanted level, the load sells for $20 x
  items squared. At daylight the doors close; anything in the van must reach a lock-up within 5
  minutes.
- **Reward:** $10,000 in total takings earns vanilla's reward (`perk.burglar`). Vanilla's reward is
  never getting tired, which MTA already gives every player (see Not yet).

## Not yet

- **Burglary furniture:** vanilla furnishes these houses procedurally and steals from that
  furniture. MTA keeps the engine furniture on, but it isn't something scripts can pick up, so
  we place our own stealable furniture (TVs, hi-fis, the VCR, consoles) on free floor that the
  burglar's client finds by casting rays. It can sit next to the engine's own TVs, and spots may need
  tuning. The resident is also ours: they sleep on the floor, since there's no bed position to use.
- **Perks MTA already gives or can't hold:** MTA makes every player never tire, so "infinite
  sprint" rewards change nothing yet; armour is capped at 100, so "+50% armour" rewards are
  recorded but can't take effect.

## Dating

Vanilla `GF_MEETING`, `GFAGNT`, `GF_DATE` and `GF_SEX`, per player (`config/dating.lua`).

- **Meeting:** each girl waits at her vanilla meeting spot; Denise and Millie, met through the story
  in vanilla, wait at home. Walk up and answer yes or no. Vanilla's appraisal decides: sex appeal / 10
  (worked out by `vana-shops` from the "sexy" values of what CJ wears, x5; ours), her outfit, and fat
  and muscle against her taste.
- **Dates:** stop a car with a free seat at her house when she isn't busy. She picks food, a
  cruise or dancing as vanilla does. Food: stop at a diner, bar, restaurant or fast food place; she
  judges the kind. Cruise: vanilla's fun meter (areas, speed, jumps, crashes, her radio station,
  parking at night), per second. Dancing: a club and a timing minigame (ours until DANCE is ported).
- **After:** take her home for +5 liking; past 50 she asks you in for coffee (censored, as the
  release). Bad dates cost 4, abandoning or hurting her 10; at -15 she dumps you.
- **Rewards:** car keys at 50 (her car with its vanilla plate at her house, only yours), the gift
  outfit at 100 (worn from the closet: Special), and perks: Michelle repairs your car at her place,
  Helena's stash (ours: chainsaw, molotovs, flamethrower), Barbara and Katie get you out of jail and
  hospital free with your weapons (`vana-player`).
- **Not yet:** phone calls asking for dates (and missed-date penalties), two-timing, Michelle driving,
  Denise's drive-bys, the dance minigame proper, her walking to the car (she may warp in).

## Vehicle side jobs

Started from the vehicle with the sub-mission key, as vanilla's R3 launcher does; pressing it again
ends the job. Fares, patients and so on are placed on the retail path network (`vana-paths`), on the
same road network as you (`Activity.streetSpot`). Tuning in `config/jobs.lua`.

### Taxi driver (`TAXIODD`)

In a taxi (420, 438). Pick up the fare (blue blip), then drive to the destination (yellow) before the
clock runs out. Each fare adds distance x 100 ms to the clock, falling to 60 ms as the streak grows.
Pay is distance / 40, or / 16 if the tip bar is still up (SPEED BONUS!); damage eats the tip. Every
5 fares in a row pays $500, then $1000 and so on. A trashed taxi loses its fare until repaired. 50
fares in total (saved) earns vanilla's reward: nitro in every taxi you drive. Ours: fares spawn
60-180 m away and ride 300-1500 m; 10 s to get back in the taxi.

### Paramedic (`AMBULAN`)

In an ambulance (416). Level N has N patients (blue) around you; pick them up (as many as there are
free seats) and bring them to the nearest of vanilla's hospitals (yellow) before the clock runs out.
Hard bumps hurt everyone aboard; a patient who dies ends the job. Each level pays level x level x $50;
finishing level 12 pays $5000 and earns vanilla's reward, maximum health raised (to the top). Ours:
patients 100-600 m away; the clock gives each 15-45 s by route length, at least a minute.

### Firefighter (`FIRETRU`)

In a fire truck (407). Each level reports burning cars in a zone: one, two past level 4, three past
level 8, with their occupants on fire from level 3. Put every fire out with the water cannon in time
(Neon's element fires: the server lights them, your client reports them out). Pays like paramedic;
level 12 pays $5000 and makes you fireproof (fire damage is cancelled on your client). Ours: the
burning cars can't blow up, and the clock (distance x 120 ms + 30 s + 6 s per fire).

### Vigilante (`COPCAR`)

In a police vehicle (or the Hunter: "Brown Thunder"). Level N sends you after N criminals, four to a
car, from vanilla's list of getaway cars; they drive off, and bail out and fight when you close in
while they're slow or wrecked (their AI runs on your client). Kill them all in time: the clock is
distance / 6 m/s, at least 40 s, and carries over. Levels pay level x level x $50. Vanilla's level 12
reward is 150% maximum armour; MTA caps armour at 100, so ours is full armour on every spawn.
Criminals are fair game: killing them is no crime (`vana:fairGame`). Ours: their weapons by level.

### Pimping (`PIMP`)

In a Broadway (575). Pick up a girl (blue), drive her to a customer (yellow), collect her when she's
done. The clock starts at 3 minutes and gains one per job; the session pays $300 per job when it
ends. Ten jobs in a session earns vanilla's reward (`perk.pimp`, "prostitutes pay you": no
prostitute system yet). Ours: places are street spots named by zone (vanilla has a fixed list of
named areas), and her busy time. Not yet: vanilla's trouble events (rough customers, hospital).

### Freight train (`FREIGHT`)

Driving the freight train (537, 538). Stop at the five stations in turn (Unity, Market, Cranberry,
Yellow Bell, Linden), in whichever direction the train runs, each within vanilla's leg time (+15 s
per leg at level 1, +10 s at level 2). Each station pays the leg's time / 100 x level; all five pass
the level: $10000, then $50000 at level 2 (saved).

### Trucking (`TRUCK`)

Walk into the marker at RS Haul (Flint County). A truck and trailer wait at the depot: hook up and
take the load to one of vanilla's 39 drop-offs. The first loads follow vanilla's order of load
types: fragile (damage costs cash), timed (late halves the pay, very late halves it again), hot
(1-2 stars), fragile and fast, extremely fragile. You have 30 s to get back in the cab or re-hook the
trailer. Eight deliveries buy the depot (vanilla: "Asset acquired"), which then earns up to $2000 a
game day at the cash pickup by the office (`jobs/assets.lua`). Ours: cash = distance x 1.4, and the
timed deadline (distance x 140 ms).

### Quarry (`QUARRY`)

Walk into the marker at the Hunter Quarry site office. Seven missions in turn, paying $500, $1000,
$2000, $3000, $5000, $7500 and $10000: the cop's body (pushed to the crane's pick-up area, then
dumped in the lake), seven rocks over the edge, four bombs to safe areas (each on its own clock,
then it blows), the bombers' bodies burned on the quarry floor, explosives driven gently to the
desert airstrip and back, the spill cleared off the tracks before the train, and the thieves' dumper
wrecked. Pushed rocks and barrels only move on your client, which reports when they arrive. All
seven earn vanilla's reward: a dumper and a bulldozer at the quarry whenever you're around. Best
times are kept per mission. Ours: the crane (MTA has no crane controls, so the load goes aboard once
both are in the pick-up area), and the time limits.

### Courier (`BCOUR`)

Ride the city's courier bike (BMX in LS, Freeway in SF, Faggio in LV; one waits at each pick-up
point) into the pick-up marker. Hold look left or right and press fire to throw an item through
the drop-off coronas; get the quota delivered in time, then ride back for your cut: time left / 100
x level, plus $100 per item to spare. Four levels per city (vanilla's items and time limits). The
throwing is client-side physics, which reports hits. Ours: the quota per level.

## Schools

Vanilla `DSKOOL`, `BSKOOL`, `BOAT` and `DESERT5` (`config/schools.lua`, `schools/`). Walk into the
school's marker (the driving school's noticeboard inside the school, the bike school's board at the
stadium, the boat school's office, the Verdant Meadows pilot) to pick a test; tests unlock in order
(70% or better opens the next). Each test runs in your private dimension with vanilla's vehicle,
start and props (cones, buoys, ramps, parked cars, target trucks), and is judged by your client
(heading, position, wheels on the ground, roll and pitch, damage, knocked cones, rings, time), which
reports a score; the server keeps best scores and medals (vanilla 70 / 85 / 100%), skill gains, and
vanilla's reward vehicles for every test at bronze, silver and gold, parked at the school for you.

| School | Tests | Rewards (bronze / silver / gold) |
| --- | --- | --- |
| Driving | The 360, The 180, Whip and Terminate, Pop and Control, Burn and Lap, Cone Coil, The '90', Wheelie Weave, Spin and Go, P.I.T. Maneuver, Alley Oop, City Slicking | Super GT, Bullet, Hotknife "__GOLD__" |
| Bike | The 360, The 180, The Wheelie, The Stoppie, Jump & Stop, Jump & Stoppie | Freeway, FCR-900, NRG-500 |
| Boat | Basic Seamanship, Plot a Course, Fresh Slalom, Flying Fish, Land Sea and Air | Marquis, Squalo, Jetmax |
| Flight | Takeoff, Land Plane, Circle Airstrip, Circle and Land, Helicopter Takeoff, Land Helicopter, Destroy Targets, Loop-the-loop, Barrel Roll, Parachute onto Target | Rustler, Stuntplane, Hunter |

Vanilla: starts, vehicles, cone circles and test offsets, the boat medal times and Flying Fish
distances, the Land Sea and Air gates, the flight rings, runway, helipad, trucks and parachute drop.
Ours: how position, heading, damage and time combine into a score (`SchoolRules`), the boat courses
built by vanilla's loops (Plot a Course, Fresh Slalom) and the flight circuits, the ramps' placement,
and that scores are client-judged.

## Races and challenges

### Race tournament (`CPRACE`)

All 27 of vanilla's races, seeded from main.scm by `tools/seed/seed_races.py` into
`config/races.lua` (checkpoints, line-ups, laps, stadium grids). Walk into an entry marker and pick
a race: Los Santos (races 0-8), San Fierro (9-14), Las Venturas (15-18), the LV airport's air races
(19-24, against the clock), the LS stadium's 8-Track (12 laps) and the LV stadium's Dirt Track (6
laps; the same marker offers Kickstart). Races run in your private dimension, with vanilla's
countdown and disqualification for 10 s out of the vehicle or wrecking it. Opponents are driven by
your client with the engine's racing drive-to, checkpoint after checkpoint; the server tracks
checkpoints and positions. A first win pays $10000 (vanilla's exceptions: Lowrider Race $1000,
Badlands A $5000, Dirt Track $25000; the 8-Track also parks vanilla's Monster and Hotring at the LS
stadium); winning every race pays $1000000. Best results and times are saved.

### Stadium events (`KICKSTA`, `BLOOD`)

- **Kickstart** (LV stadium, from the Dirt Track marker): collect vanilla's 33 coronas on a Sanchez
  in four minutes (green 1, amber 2, red 3 points); paid score x $100; beat your best score.
- **Blood Ring** (SF stadium): in a Bloodring Banger, drive through checkpoints (+15 s each) to keep
  your clock above zero while eleven bangers ram you; get it above the target time (1 minute, plus a
  minute after each win) for $10000. Ours: checkpoints at random in vanilla's arena box.

### The Chiliad Challenge (`MTBIKER`)

Ride a mountain bike into the marker on the summit of Mount Chiliad and pick a route: Scotch Bonnet
Yellow Route, Birdseye Winder, Cobra Run (seeded from main.scm). Each opens when you win the one
before; wins pay $500, $1000, $2000. Five rival riders, on the race engine.

### BMX and NRG-500 stunt courses (`STUNT`)

Ride the BMX into the Glen Park skatepark marker, or the NRG-500 into the one at the San Fierro
docks, then collect every corona (vanilla's 19 and 18) before the clock runs out: 11 s to start,
+10 s per corona. First completion pays $1000; best times are kept.

### Beat the Cock! (`TRIA`)

Walk into the start on Santa Maria Beach or at Fleischberg: run into the sea, swim the course, take
the bicycle waiting at the shore, ride, then leave it and run to the finish (vanilla's checkpoints
and legs; 10 s to get on or off the bike when the leg changes). Winning pays $10000 / $20000.
Ours: you race the clock (each leg's length at a set pace) instead of vanilla's twelve athletes.

### Ammu-Nation shooting range (`SHRANGE`)

At the four Ammu-Nations with a range, walk into the range marker and take the next weapon
challenge: pistol, micro SMG, shotgun, AK47. Three rounds against two rivals in the side lanes:
first to destroy three targets, then the same with targets advancing, then one target at a time
where every part shot off is a point, first to 20. Passing raises the weapon's skill (+50, +100 more
the first time); all four earn vanilla's fast reload (recorded only: MTA has no control for it).
Ours: rivals score at a set pace, a target counts as destroyed with 5 of its parts shot off, and the
rounds are judged on your client.
