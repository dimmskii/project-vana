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
