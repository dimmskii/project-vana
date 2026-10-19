# Wildlife (`vana-wildlife`)

Creatures from community mods (credits in [credits.md](credits.md)), ported to Lua from their
decompiled scripts; their assets are in `vana-wildlife/mods/`.

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

Spawn spots: `bigfootspawn` elements in `[data]/vana-data-wildlife` (editable in the Map Editor; the
walk target is `ex`, `ey`, `ez`, drawn as a line). Rules: `config/wildlife.lua`.

`/bigfoot` (restricted: `command.bigfoot`) puts him 20 m in front of you; `wildlifetest` checks the
spots and files.

## Not verified in game

The model on the ped (a 2009 special-actor DFF on a requested ped model), his walk, the attack, and
the damage scaling.
