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
play skeletal animations, so they have to be peds: a `wildlife` ped per animal, its model a requested
ped model with the species' DFF and TXD (as Bigfoot's), its walk, run and idle replaced by the
species' own animations (`engineLoadIFP` + `engineReplaceAnimation`, per ped). "Dumb" is the
behaviour, not the element: no paths, no traffic rules, a small brain run by the server.

## Not yet

The spawning itself: waking spawners near players, the animals wandering round their spot, idling and
calling (the sounds), fleeing, and predators (bears, wolves, big cats) going for people when their
spawner says so; downloading a species' files only when one is near (they're 74 MB). Species without
their own animations stand wrong on GTA's human ones (the pack says as much).
