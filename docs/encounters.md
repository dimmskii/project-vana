# Encounters (`vana-encounters`)

Creatures and NPCs you may run into at their spots: each has its own script and rules, and its spots
are `encounter` elements in `[data]/vana-data-encounters`. Bigfoot so far, from a community mod
(credits in [credits.md](credits.md)), ported to Lua from its decompiled script; its assets are in
`vana-encounters/mods/`. (The animals, simple spawners at their places, are
[vana-wildlife](wildlife.md).)

## Encounter spots

One element type for everything that appears: `encounter` (Map Editor, `vana-encounters`
definitions), with:

| Attribute | Meaning |
| --- | --- |
| `creature` | Who appears (a key in `config/encounters.lua`: `bigfoot`) |
| `startHour`, `endHour` | Game hours it can appear in (end exclusive, across midnight allowed; equal: any time) |
| `weather` | Vanilla weather IDs it needs, comma-separated (`9`: fog); none: the creature's own rule |
| `ex`, `ey`, `ez` | Where it walks to after appearing; none: it stays (drawn as a line in the editor) |
| `params` | Anything one creature needs that the others don't, free-form (`key=value;...`) |
| `note` | Free-form |

## Bigfoot

From Bigfoot v1.2 by Tysman (`mods/bigfoot/Bigfoot.txt` is the decompiled script the port follows):

- **Where:** a player on foot or driving in the south-west countryside (Back o' Beyond, Whetstone:
  the mod's rectangle, `area`) may meet him, at one of the mod's 38 spots more than `spawnAway`
  (160 m) from every player, so he's never seen appearing.
- **Weather:** in fog (vanilla weather 9) one of the 28 fog spots, from where he walks to a point and
  stands; otherwise one of the 10 others, where he stands. (The mod's script gives those 10 no walk
  target and reuses stale values; standing is what its readme describes.)
- **Him:** the mod's model, the old man's walk, boxing; vanilla 1000 health (our clients scale damage
  to him down, as MTA peds have 100). Gunfire doesn't scare him.
- **Hurt him** and he goes for you (the mod's kill task, run by your client).
- **Gone** (fading out) once he's `despawnFromSpawn` (400 m) from where he appeared or
  `despawnFromPlayer` (350 m) from every player. One at a time, server-wide; after he dies or fades,
  the next chance is `respawnMs` away. Ours: each check (`checkMs`) has a `chance` of him appearing
  (the mod spawns him whenever it can).
- **Model on clients:** each client requests a ped model of its own (`engineRequestModel`), loads
  the mod's DFF and TXD onto it and shows it on the server's ped (`vana:creature` = `bigfoot`).

Spots: the `encounter` elements with `creature="bigfoot"` (the fog spots have `weather="9"`). Rules:
`config/encounters.lua`.

`/bigfoot` (restricted: `command.bigfoot`) puts him 20 m in front of you; `encountertest` checks the
spots and files.

## Not verified in game

The model on the ped (a 2009 special-actor DFF on a requested ped model), his walk, the attack, and
the damage scaling.
