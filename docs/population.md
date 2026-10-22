# Population

`vana-population` decides **who** appears where: which kind of ped (civilian, gang member, dealer,
cop), which model, which car, which driver and which weapon. It follows the vanilla rules from
`CPopCycle` and `CPopulation` (gta-reversed). `vana-peds` and `vana-traffic` decide *where* and
*how* they move, and ask `vana-population` what to spawn.

## Data sources

Read at runtime from `vana-population/data/`, copied from the retail disc (see `setup.md`):

| File | Used for |
| --- | --- |
| `popcycle.dat` | Per zone type, per 2-hour slot, weekday and weekend: max peds and cars, dealer/gang/cop/other percentages, and the mix of 18 civilian groups |
| `pedgrp.dat` / `cargrp.dat` | Model lists per group (LA, SF and LV variants for peds) |
| `peds.ide` / `vehicles.ide` | Model IDs, ped type and stat (personality), vehicle type and class |
| `info.zon` / `map.zon` | Navigation zones (smallest containing zone wins) and city regions |
| `pedstats.dat` / `ped.dat` | Personalities and ped-type relationships (loaded for upcoming work) |

Seeded once into **our own editable Lua** in `vana-population/config/` by
`tools/seed/seed_population.py`. The tool reads the decompiled `main.scm` and `gta_sa.exe` as
data. These files are committed and free to diverge from vanilla.

| File | Seeded from |
| --- | --- |
| `zones.lua` | `main.scm`: zone population types, races, dealer strengths and gang territories |
| `gangs.lua` | `CGangs::Initialise` defaults, plus Grove from the `RYDER2` mission. Weapons and armed chance (33%) |
| `groups.lua` | `CPopulation::m_TranslationArray` at `0x8D2540` in the exe: popcycle group to `pedgrp.dat` line per city |

### Fixed story state

Gang territories change throughout the story; we use one fixed state:

- `INITIAL` (game start): zone types, races, dealers, starting gangs.
- `LA1FIN2` ("Home Coming"): the post-LA-story territory map.
- `MANSIO3_6740` ("Grove 4 Life", won): Grove holds Grove Street (`GAN1`, `GAN2`).

Grove's weapons are the `RYDER2` set (pistol, TEC-9). Spraying all 100 tags in `main.scm`
(`COLLS`) upgrades them to desert eagle, MP5 and knife; that's a candidate for a gameplay reward.

## Rules

- **Targets:** for the zone at the spawn point, at the in-game hour, with real-world Saturday and
  Sunday as the weekend, `CPopCycle::UpdatePercentages`:
  - dealers: 10% minimum where the zone has dealers
  - gangs: zone gang strength, capped at 50%
  - cops: from gang presence
  - other: the rest

  Each is multiplied by the popcycle row's maximum and its per-kind percentage.
- **Kind:** the largest deficit around the player, randomised when small
  (`CPopCycle::FindNewPedType`). When every kind is at its target, nothing spawns, so vanilla
  density is the cap.
- **Gang:** the one furthest below its share of the zone's gang strength.
- **Civilian:** a group by the popcycle percentages, then a model from that group's city variant,
  filtered by the zone's races. A model's race comes from its name, as
  `CPopulation::FindPedRaceFromName` does.
- **Cars:** the same kinds and groups from `cargrp.dat`, road vehicles only. The driver comes from
  the same group, so golf clubs get golfers in Caddies.
- **Cops:** LAPD, SFPD and LVPD by city, and the county sheriff in countryside and desert. On foot
  they get Neon's `ambient-cop-safe` profile: they react, but never escalate.
- **Weapons:** gang members get one of their gang's weapons with the gang's `armedChance`.

### Deviations

- Dealers only spawn in zones with a dealer strength. Vanilla floors the dealer share at 10%
  everywhere, but only streams dealer models where they deal.
- Weekday versus weekend follows the real-world calendar (MTA has no in-game weekday).

## Personalities

Each ped's personality is its model's `pedstats.dat` type (named in `peds.ide`): fear, temper,
lawfulness, attack strength, defend weakness, shooting rate and default decision maker. Each ped
gets per-ped random variance on top (`config/personalities.lua`, hand-written). The variance and
the encounter thresholds below are constants there.

## Encounters

The server decides from kind and personality; the owning client runs Neon's native tasks:
`setPedKillOnFoot` for fights, a `smart_flee` task sequence for fleeing, `setPedEnterVehicle`
for jacking. While an encounter lasts, the ped gets no walk targets. Afterwards it walks on from
the nearest sidewalk node.

- **A player hits, kicks or shoots a traffic car or its occupants** (reported by the car's owner,
  and by a player ramming one): collision severity is the force divided by `forcePerSeverity`;
  kicks and punches count `meleeSeverity`; shots count 100. When shot at, gang and cop crews pile
  out and fight back, while civilians bail out and run (fear `bailFear` or more) or panic and floor
  it. For collisions and kicks:
  - small bumps: ignored
  - fearful driver: panics, driving fast with `avoid_cars` and running lights
  - bad-tempered driver: gets out and fights (a gang crew piles out with them)
  - very bad-tempered driver: by chance, drags the player out of their car and drives off in it
    (the car becomes a traffic unit)
  - anyone else: honks
  Civilian passengers of a driver who gets out to fight decide for themselves: bad-tempered ones
  join in, fearful ones get out and run, the rest stay put.
- **A player takes a traffic car** (drags the driver out, or gets in once the driver has gone):
  everyone in it answers. Cops and gang members fight; civilians fight if bad-tempered and not
  fearful, otherwise get out and run. Dragging a cop out is a crime (`jack_cop`, at least one star),
  and a police unit whose car is taken fights the thief, then stays behind as walking cops.
- **A player aims a gun at a car:** cop and gang crews get out and fight; civilian drivers abandon
  the car and run (fear `bailFear` or more), fight (temper `jackTemper` or more) or speed off.
- **A player or a ped attacks a pedestrian:**
  - cops fight back, drawing their holstered pistol
  - gang members fight (or flee if fearful), and same-gang members within `gangBackupRadius` join in
  - civilians flee if fearful, fight if bad-tempered, or otherwise keep GTA's own event response
    ("react")
- **A ped jacking a player's car** that drives off or gets away from them: cops and gang members go
  for whoever has the car; civilians give up and walk on.
- **Holdups: a player aims a gun at a pedestrian** (`holdup` in `config/personalities.lua`):
  - cops fight back, and it's a crime (`threaten_cop`, at least one star)
  - gang members fight (fearful ones run) and their gang joins in; the player's own gang ignores it
  - civilians fight if bad-tempered and armed, put their hands up if fearful enough, or run
  - hold the aim on a hands-up victim for `cashSeconds` and they drop cash (a `holdup` crime,
    reported like any other); stop aiming and they run

## Gangs and players

Every player counts as a member of `playerGang` (vanilla CJ: Grove Street), with gang rivalries in
`rivals`:

- Rival gang members within `initiateRadius` of a player on foot (or barely moving in a car) start
  fights, by chance (`initiateChance` per second), at most once per `initiateCooldown` per player.
- Members of the player's gang nearby defend a player a ped attacks, and join a player's fight
  against a rival gang member. A homie hit by the player fights back, but nobody else joins in.

## Weapons and drops

- **Holstered or drawn:** gang members' weapons start in hand or holstered (`drawnChance` in
  `gangs.lua`). Cops' pistols start holstered.
- **On death:** ambient peds and traffic occupants drop each carried weapon as a pickup, and
  sometimes cash by kind (`config/drops.lua`). Pickups vanish after 30 s.

## Groups

Couples and gang groups walk together (`config/companions.lua`):

- **Couples:** 12% of civilians walk with a partner of the opposite sex from the same group.
- **Gang groups:** 60% of gang members walk with 1-2 more of their gang.

The leader walks the planned route and decides road crossings. Companions keep a slot beside it
(alternating right and left, further rows slightly behind) and stand when it waits at a kerb.
When the leader fights, a gang fights alongside, while a civilian partner runs. A companion whose
leader is gone walks on alone. Neon's native couple presentation (holding hands) is a later
refinement.

## One population

Traffic occupants (driver and passengers) who end up on foot, whether pulled out, fleeing, after
a crash or getting out to fight, are adopted by `vana-peds` (`adoptPed`). They keep their kind,
gang, personality and any encounter, leave mission-actor mode, get the ambient event profile, and
walk on as ordinary pedestrians. In the other direction, a ped who jacks a car is handed to
`vana-traffic` (`adoptVehicle`).

Cars carry passengers: gang cars 1-3 more members of the gang, cop cars a partner half the time,
civilian cars a passenger from the same group 15% of the time.

## Testing

`poptest [hour]` (console) validates the data:

- every popcycle table is complete
- every group and model name resolves
- every configured zone exists

It then fills five known places 100 times and reports the kinds, gangs, peds and cars that
appear: Grove Street, El Corona, the LS airport, the SF golf club and SF downtown.

## Next

- **Groups:** Neon's native couple presentation, and occupants by car type (taxis, buses).
- **Tuning in game:** collision severity scale, jack chance, and how the native fight, flee and
  jack tasks behave.
- **Emergency services:** medics, firefighters, police response.
- **Data:** zone-specific car generators and parked cars; boats, aircraft. Trains: [trains.md](trains.md).
- **Storage:** move config and data to XML and elements (long-term).
