# Wildlife (`vana-wildlife`)

Animals at their places in the countryside (and strays in town), from Myths Maker 2.7's animal pack
("Animal World", credits in [credits.md](credits.md)): its animals only, never its myths (the
hunter). Encounters with individual creatures (Bigfoot) are [vana-encounters](encounters.md).

## The data

`tools/seed/seed_wildlife.py` read the pack once (each animal folder, `cleo/Animals/AnimN`):

- **Spawners:** every location in each folder's ini, with the folder's settings, became a
  `wildlifespawner` in `[data]/vana-data-wildlife/wildlife.map` (1454; ours now, edit them in the Map
  Editor): `species`, `angle`, `quantity` (how many at once), `startHour`/`endHour`, `findRadius`
  (a player this close wakes the spot), `spawnRadius`, `health`, `damage`, `attacksPeds`,
  `attacksAnimals`, `respawn` (s), `weather`, `note` (the pack's folder). The pack's own weather
  values (100, 201, 403, 504) aren't vanilla weather IDs and its second script doesn't decompile, so
  every spawner is any-weather, with the raw value in its note.
- **Files:** each species' models (the base and its variants: `{ dff, txd }` pairs), its own
  animations (IFP and `animgrp.dat`, where it has them) and its sounds (random calls, a hurt sound),
  without the pack's duplicates (276 MB of copies down to 74 MB), in
  `vana-wildlife/mods/myths_maker/<species>/`, listed in `config/species.lua` (generated).

| Species | Spawners | Own animations |
| --- | --- | --- |
| Dog | 347 | yes |
| Hare | 344 | yes |
| Cat | 257 | yes |
| Boar | 119 | yes |
| Deer | 103 | yes |
| Bird | 54 | no |
| Cow | 39 | no |
| Puma | 38 | yes |
| Fox | 32 | no |
| Pig | 26 | no |
| Capybara | 20 | no |
| Sheep | 19 | no |
| Wolf | 19 | yes |
| Chicken | 13 | no |
| Leopard / panther | 8 | yes |
| Brown bear | 6 | yes |
| Black bear | 5 | yes |
| Gorilla | 3 | no |
| Ostrich | 2 | no |
| Lioness | 0 (models only) | yes |

`wildlifetest` (console): every spawner's species is known and every listed file is here.

## Peds, not objects

Every model in the pack is skinned to GTA's own ped skeleton (`Root`, `Bip01 ...`, even the finger
and breast bones), re-weighted for four legs, and moves by the pack's IFP animations. Objects can't
play skeletal animations, so they have to be peds: a ped per animal, its model a requested ped model
with the species' DFF and TXD (as Bigfoot's), its walkcycle replaced by the species' own animations
(`engineLoadIFP` + `engineReplaceAnimation`, per ped, as the pack's `animgrp.dat` maps them: its
`_run` is the walk, its `_sprint` the run). "Dumb" is the behaviour, not the element: no paths, no
traffic rules, a small brain run by the server.

Each species has a **driver** (`config/wildlife.lua`): `ped` for models rigged like these, `object`
for a later pack whose models aren't (a plain model the server moves with `moveObject`: it wanders
and flees, it can't attack).

## The animals

Only the species `config/wildlife.lua` knows spawn, and of those the ones named in the `species`
setting: for now those with animations of their own (hare, deer, boar, cat, dog, wolf, brown bear),
and the black bear, puma and leopard on the brown bear's and the lioness's. The rest (pig, cow, bird...)
would stand on GTA's human animations.

- **Waking:** each second, near each player outdoors: a spawner within its `findRadius`, at its
  hours, keeps up to `quantity` times `density` alive, one every 3 s, never within
  `minSpawnDistance` of a player, within the caps (`maxPerPlayer` within 200 m, `maxTotal`). Gone
  once every player is `findRadius + despawnMargin` from its spot (or 250 m from the animal); a body is removed after 20 s and its spawner
  waits its `respawn`.
- **Behaviour** (per species): **prey** (hare, deer, cat) runs from anyone within `fleeRange`;
  **neutral** (boar, dog) ignores people; **predators** (wolf, bears, puma, leopard) see a player
  within `aggroRange` and go for them with `aggroChance` every `aggroCheckMs` (50% every 5 s by
  default). Hurt, prey runs and the rest go for whoever hurt them. Otherwise an animal idles and
  wanders round where it appeared (the pack scatters them up to `spawnRadius` round the spot), and walks back from `leash` away.
- **Attacks:** a chase and a bite (the pack has no attack animations; GTA's fist fight would be a bear
  throwing punches): within 2 m, a bite every 1.4 s of the spawner's `damage` times `damageScale`,
  checked by the server. A chase gives up after 25 s, or 50 m away.
- **Toughness:** the spawner's `health` (a hare 60, a bear 650) on MTA's 100-health peds: damage is
  scaled down where the animal is simulated, as Bigfoot's.
- **Sounds:** a call now and then from each animal streamed in within 70 m, a cry when hurt.
- **Who runs them:** the nearest player's client (the syncer) runs the orders, the chased player's
  during an attack. Killing one is no crime and calls no ambulance (`vana:fairGame`).
- **Files:** downloaded at connect (`<file>` in meta.xml, only the species `config/wildlife.lua`
  knows: `python3 tools/seed/wildlife_files.py` after changing it). Models and animations load the
  first time one shows.

`/animal <species>` (restricted, `command.animal`): one 8 m ahead of you, for testing.
`/vanadebug wildlife brains`: chases and their ends, and orders a client couldn't give.

## Settings

Through `/vanaset wildlife <name> <value>` (or the admin panel's resource settings; kept in the
server's `settings.xml`, see [setup.md](setup.md)):

| Setting | Default | |
| --- | --- | --- |
| `enabled` | `true` | animals spawn at all (off removes them) |
| `species` | the ten above | which spawn, comma-separated |
| `density` | `1` | scales each spawner's quantity |
| `maxPerPlayer` / `maxTotal` | `12` / `60` | the caps |
| `minSpawnDistance` | `30` | m |
| `despawnMargin` | `60` | m beyond the find radius |
| `aggroChance` / `aggroCheckMs` / `aggroRange` | `0.5` / `5000` / `25` | predators' aggression |
| `fleeRange` | `14` | m |
| `leash` | `60` | m |
| `damageScale` | `0.5` | scales the pack's bite damage on players |

## Not yet

Drops (meat, pelts, money); hunting peds and animals (`attacksPeds`, `attacksAnimals` are kept but
unused); the species without their own animations; weather (the pack's values unknown); a ped's
collision is still a person's size, even a hare's; downloading a species only when one is near.
