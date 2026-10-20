# Encounters (`vana-encounters`)

Creatures and NPCs that appear at their places each day, one of each: Bigfoot so far, from a
community mod (credits in [credits.md](credits.md)); its assets are in `vana-encounters/mods/`. The
shape is meant for more of them later (slashers, aliens...). (The animals, simple spawners at their
places, are [vana-wildlife](wildlife.md).)

## Encounters

One `encounter` element per encounter (Map Editor, `vana-encounters` definitions, in
`[data]/vana-data-encounters`). Each is a single instance: place several elements for several of a
kind.

| Attribute | Meaning |
| --- | --- |
| `id` | Its name, unique: how it's tracked (one of it, ever) |
| position, `rotZ` | Where it appears, facing |
| `kind` | What it is: a key in `config/encounters.lua` (`EncounterKinds`: `bigfoot`), as shop points name their kind. The kind gives the defaults below and its script |
| `name` | Shown on the map and in messages ("Bigfoot"; none: the kind's) |
| `startHour`, `endHour` | It appears at `startHour` every game day and is cleaned up at `endHour` (across midnight allowed; equal: a whole day from that hour) |
| `blip` | The vana-map category of its icon while it's out (`bigfoot`: `icons/radar_bigfoot.png`); `none`: no icon |
| `health` | In GTA's units (Bigfoot 1000); our clients scale damage to MTA's 100-health peds |
| `reward` | Cash for killing it, shared by the damage each player did |
| `model`, `walkingStyle`, `fightingStyle`, `weapon` | The ped (a kind with its own DFF and TXD shows that on its model) |
| `anim` | Idle animation while it stands, `block/name` |
| `ex`, `ey`, `ez` | Where it walks after appearing (drawn as a line in the editor) |
| `params` | Anything else its script reads, free-form (`key=value;...`) |
| `note` | Free-form |

Every attribute but `id`, `kind` and the hours falls back to the kind's value.

## How they run

- **The day:** at `startHour` the encounter appears (if it isn't out already), at its place, whether
  or not anyone is near; at `endHour` it's cleaned up, wherever it is, in a fight or not. If the
  resource starts within its hours, it appears at once.
- **Killed:** it stays dead (the body for 30 s) until the next `startHour`. Anything else that removes
  it (an admin, a crash) and it comes back at once: each encounter is tracked by its `id`, so there
  is never a second one of it, and the one in a fight is the one that's there.
- **Its script** (the kind's `script`, `EncounterScripts` in `server.lua`): `creature`, the only one
  so far, stands (playing its `anim`) or walks to its target, and goes for whoever hurts it (GTA's
  kill-on-foot task, run by that player's client) until they're dead, gone or 150 m away, then goes
  back to what it was doing. The nearest player within 250 m simulates it otherwise.
- **The reward:** every hit a player lands is reported in its health units (at most 250 a hit) and
  kept per player; when it dies, its `reward` is split by each one's share of all that damage
  ("Bigfoot is down. Your share: $3200 (64% of the damage)"). Players who left get nothing.
- **On the map:** while it's out (and alive), its `blip` category's icon follows it, on the map and on
  the radar.
- Killing one is no crime and calls no ambulance (`vana:fairGame`).

`encountertest` (console) checks every encounter's kind, id and model files and lists their hours
and state (out, waiting, killed today). `/vanadebug encounters encounters` logs each one appearing,
being cleaned up, going for someone, giving up and being killed.

## Bigfoot

From Bigfoot v1.2 by Tysman (`mods/bigfoot/Bigfoot.txt` is the decompiled script the port followed):
the mod's model, the old man's walk (`walkingStyle` 120), boxing (`fightingStyle` 5) and 1000 health.
The rest is ours: a $5000 reward, the map icon, and where and when he is (the mod spawned him at random
at one of its 38 spots, out of sight, in fog or not).

- **Model on clients:** each client requests a ped model of its own (`engineRequestModel`), loads
  the mod's DFF and TXD onto it and shows it on the server's ped (`vana:creature` = `bigfoot`).
- **Placed:** one, `bigfoot.whetstone` in Shady Creeks (Whetstone), all day from midnight (the first
  test). The mod's 38 spots are kept, commented out, in `encounters.map` for placing more.

## Not verified in game

The model on the ped (a 2009 special-actor DFF on a requested ped model), his walk, the attack, the
damage scaling and the reward split.
