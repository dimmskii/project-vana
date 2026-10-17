# Emergency services and parked cars

## Wanted levels and police (`vana-services`)

Values are seeded from `CWanted` (gta-reversed `Wanted.cpp`) into `vana-services/config/wanted.lua`.
Edit freely.

- **Chaos points:** crimes add chaos points (hurting a ped 5, hurting a cop 45, stabbing a cop 100,
  stealing a car 15, running someone over 18, damaging a cop car 80, and so on).
- **Stars:** at 50, 180, 550, 1,200, 2,400 and 4,600 chaos. Each level sends the vanilla pursuit:
  1 to 3 cop cars, 1 to 10 cops.
- **Decay:** chaos drops by 1 per second while no cop is within 18 m, 2 in the countryside and
  desert. Dying clears it.
- **Witnesses:** a crime a cop sees within 14 m (vanilla `CCrime`) counts at once and makes the
  player wanted (at least one star). Otherwise a civilian calls it in with 50% chance after 6 s;
  bumping cars never gets called in.
- **Crimes against the police** count at once with a minimum (`minStars`): hitting a cop means
  at least one star; stabbing a cop, damaging a cop car or killing a cop at least two. Every hit
  counts, including hits on pursuing crews (their clients report them), which is how players climb
  past two stars.
- **Where crimes come from:**
  - pedestrians and service crews being hurt (`vana-peds`, `vana-services`)
  - traffic incidents (`vana-traffic`)
  - killing cops, running peds over, and taking a car from its driver (`vana-services`)
- **Arrest or fight (`getCopMode`):** while the player is under two stars with nothing in hand
  (melee weapons count), cops arrest: nightstick out (every cop carries one), beat the player
  down. Otherwise they shoot. Crews and walking cops switch as soon as that changes.
- **Busted:** only in arrest mode. A cop on his feet within 1.8 m for 1.5 s, while the player is
  on foot, up, and nearly still. The clients report who is knocked down or getting up (the local
  player, and the cops they simulate), so nobody busts or gets busted from the ground. This is a
  baseline to build on (surrendering is planned).
- **Patrols join in:** police cars already in traffic within 80 m of a wanted player become part of
  the chase.
- **Units by level** (weights in `Wanted.units`, crews in `Wanted.crews`):

  | Stars | Units | Crew weapons |
  | --- | --- | --- |
  | 1-3 | city police (county or desert sheriff out of town) | pistol, shotgun from 3 stars |
  | 4 | police or SWAT (Enforcer, 4 SWAT) | MP5 |
  | 5 | police, SWAT or FBI (FBI Rancher, 4 agents) | MP5 |
  | 6 | FBI, army (Barracks, 4 soldiers) or a Rhino | M4 |

  Units start out of sight 140-200 m away with sirens on. They get out within 25 m of an on-foot
  player and get back in when the player gets 70 m away. Rhinos never get out; they keep driving
  at the player.
- **Police helicopter, from 3 stars:**
  - A Maverick with a pilot and a gunner, flown by the owning client: it circles the player
    28 m out and 22 m up, nose toward them.
  - The gunner fires drive-by (`setPedDriveBy`, MP5).
  - It has a searchlight at night.
  - It flies off once the level drops below 3.
- **Roadblocks, from 3 stars:**
  - While the player drives, every 15 s there's a 12/18/24/30% chance (vanilla
    `m_ChanceOnRoadBlock`) of two police cars across the road 120-160 m ahead, out of sight.
  - A cop behind each car shoots when the player comes within 60 m.
  - They're cleared once passed and out of range, or after 90 s.
- **When the chase ends,** because the stars are gone or the player is dead, crews get back in
  and drive off. A crew that can't get back in stays on as walking cops.
- `/wanted <0-6> [player]` sets a wanted level (restricted: `command.wanted`). `wantedtest`
  (console) checks the thresholds and that every unit resolves.

Not yet: heli-rappelling SWAT, spike strips, tank cannon fire.

## Ambulances

A body near a player gets an ambulance half the time, at most one per area per minute
(`Medics` in `config/wanted.lua`):

1. The ambulance drives in from out of sight.
2. Two medics (LAEMT, SFEMT or LVEMT by city) run to the body and perform CPR for 8 s.
3. Half the time the person gets back up and walks on as a pedestrian.
4. The medics get back in and drive off.

Medics are the crew of a responder, like the police crews. If they're attacked or lose their
vehicle, they become ordinary pedestrians.

## Fire trucks

An exploded vehicle near a player gets a fire truck 70% of the time, at most one per area per
minute; the player's own car doesn't count (`Firefighters` in `config/wanted.lua`):

1. The fire truck drives in from out of sight.
2. Two firefighters (LAFD, SFFD or LVFD by city) walk up to the wreck and hose it with
   extinguishers for 10 s (`setPedShootAt`).
3. They get back in and drive off.

Not yet: fires that aren't wrecks (burning peds, molotovs, grass).

## Parked cars (`vana-parked`)

Vanilla car generators (`CCarGenerator`), seeded by `tools/seed/seed_cargens.py` into
`vana-parked/config/cargens.lua`:

- 1,043 from the binary streaming IPLs inside `gta3.img` (`CFileCarGenerator`, 48 bytes each;
  headings converted from radians).
- 179 from `main.scm`'s `create_car_generator` calls: rewards such as the Rhino and Hydra at Grove
  Street, airport aircraft, the girlfriends' cars, the go-kart, NASCAR rewards. All are enabled,
  since open-world content is always available. Disable any with `enabled = false`.
- Duplicate spots (same position and model) are dropped, and placeholders at 0,0,0 skipped.

Rules follow vanilla:

- **When:** a car appears only out of sight. A player must be 120-160 m away, within 50 m of
  height, and not heading toward it. Forced generators ignore that.
- **How many:** at most 5 parked cars around a player by day, 10 at night.
- **Model −1:** a car suited to the zone (no boats, nothing in the big class), picked once and
  kept.
- **Colours and locks:** colour −1 is random, and the door-lock chance is applied.
- **Despawning:** untouched cars disappear when no player is within 220 m. A car a player has
  driven is theirs; it only goes after 5 minutes empty with nobody within 300 m.
- **Respawning:** each generator respawns after its own min/max delay.

`parkedtest` (console) spawns the generators around Grove Street and checks the data.

### Known issue: lots fill late

Seen in game: a car park you drive toward stays empty until you turn around. This is the vanilla
rule copied exactly: a generator only spawns while the player is 120-160 m away **and not heading
toward it**, and despawning at 220 m keeps the window narrow.

Candidate fixes, for later:

- Pre-fill generators in a ring well beyond view distance (for example 250-350 m), regardless of
  heading.
- Widen the window, and drop the heading rule for spots a player can't see. That needs a
  client-side visibility check, such as `isLineOfSightClear` from the camera.

### Known issue: a cop crouching instead of arresting

Seen in game at one star: one cop crouched in front of the player instead of closing in, while a
freshly arrived cop made the bust. Left as is for now. Likely suspects: the native attack task
taking a crouched stance with the nightstick, or an attack order held back by the route-pool guard
(`docs/traffic.md`).
