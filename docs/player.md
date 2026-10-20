# Players (`vana-player`)

## Persistence

Players are identified by their MTA serial (no accounts or logins yet). Everything is read from
and applied on the server; clients never report their own values.

| Saved | How |
| --- | --- |
| Money | `getPlayerMoney` / `setPlayerMoney` |
| Fat, stamina, muscle, max health | ped stats 21, 22, 23 and 24 (max health 569-1000 = 100-176 HP) |
| Clothes | every clothes slot (0-17): texture and model |
| Weapons | per slot: weapon, total ammo, ammo in the clip, and which weapon is in hand |
| Fighting style | `getPedFightingStyle` (learned at the gyms) |
| Position | where the player left, if `spawnAtLastPosition` is on |
| Owned items | by kind, e.g. every clothing item ever bought (`isOwned`, `grantOwned`, `getOwned` exports) |

Records live in `vana-player/players.db` (SQLite, one JSON record per serial, gitignored). They
are saved every 60 s, when the player leaves, when the resource stops, and on request from other
resources through the `savePlayer(player)` export (for example after a purchase).

New players start with `config/player.lua`'s values: $250, fat 200, max health 100, at Grove
Street.

## Accounts and admin rights

Every player is logged in automatically to an MTA account named after their serial. Its password
is derived from a random secret kept in `players.db`, so there's nothing to remember.

ACL groups are assigned by serial in `config/player.lua` (`groups`, e.g. `Admin = { "<serial>" }`).
`vana-player` adds those accounts to their groups whenever it starts and saves the ACL. Don't add
them to `acl.xml` by hand: the server rewrites that file from memory and hand edits made while it
runs get lost.

`vana-player` requests the rights it needs (`addAccount`, `aclGroupAddObject`, `aclSave`) through
`<aclrequest>`. Approve them once in the server console with `aclrequest allow vana-player all`.
The Admin group has MTA's authorized-serial protection, which matches here since the account is
the serial. If a login is refused, the server log says so.

## Admin commands

Restricted to the `Admin` ACL (`adminRights` in `config/player.lua`). Without a player name they
act on you; from the console a name is required. Changes are saved at once.

- `/setmoney <amount> [player]`
- `/addmoney <amount> [player]`: a negative amount takes money.
- `/setstat <fat|stamina|muscle|maxhealth|stat ID> <0-1000> [player]`: setting max health also fills
  health to the new maximum. Any stat ID can be set, but only fat, stamina, muscle and max health
  are saved; others (weapon skills, driving) last until you leave.

### Warps (`warp.lua`)

- `/warp <where> [player]`: you (or the player) to a place, a player, or `x y z [interior]`. A
  driver takes the car and its passengers along; a passenger gets out first. To a player: beside
  them, in their interior and dimension.
- `/warphere <player>`: the player to you.
- `/warps [filter]`: the place names containing the filter (chat shows 30; the console all).
- `/pos [player]`: where you (or the player) are: coordinates and heading, interior, dimension, zone and city, the car, the nearest place in the same interior and a `/warp` line back to the exact spot (restricted, `command.pos`).

Names are case-insensitive, and a unique start of one is enough (`/warp hospital.jef`). Players
are matched the same way (or `me`); an exact player name wins over a place, a place over a partial
player name. The places:

| Names | Where |
| --- | --- |
| spot ids, e.g. `playerconfig.start.spawn`, `games.dance.floors.1`, `jobs.trucking.start` | every `spot` in the `vana-data-*` maps (the ids are their config paths) |
| `hospital.1`-`8`, `police.1`-`7`; by zone, e.g. `hospital.jefferson`, `police.pershingsquare` | the restart points; `hospital` or `police` alone: the nearest one |
| `ls`, `sf`, `lv` | that city's police station |
| vanilla's entrance names, e.g. `carls`, `ammun1`, `gym1`; `carls.in` | outside an interior's door, or `.in` inside it (where its marker puts you); `name.2`, `name.3` when there are several |
| `start`, `spawn`, `cj`, `home`, `sweet`, `ryder`, `ogloc`, `binco`, `ammu`, `gym` | extra names in `config/player.lua` (`warps`): another name, or `{ x, y, z [, interior] }` |

`warptest` (console) checks that the list builds and every extra name points at a place.

## Placing on the ground

Places from vanilla's data (restart points, the start spawn, spots, entrances' exits, the mod
garages' spots) are points on the ground, but MTA positions a ped's or car's centre. So a player
or car put at one starts a bit above it, and `settle` (exported) asks that player's client for the
floor below once its collision has loaded, plus the model's centre-to-base height; the server then
sets the height. Used for wasted/busted restarts, the first spawn, `/warp` to places and
coordinates, and the mod garages. Positions saved from the game are centres already and aren't
settled.

## Wasted and busted

As in vanilla, both cost the player's weapons and $100. The player comes back at the nearest
restart point, seeded from `main.scm`'s `add_hospital_restart` / `add_police_restart` (8 hospitals,
7 police stations) into `[data]/vana-data-player/player.map`, without the story's city gating.

- **Wasted:** "wasted" on screen, then respawn at the nearest hospital at full health.
- **Busted (`bustPlayer` export, called by `vana-services`):** the player is frozen, "busted"
  appears on screen, and they respawn at the nearest police station with their wanted level
  cleared.
- **When a player gets busted:** see `services.md` (arrest mode, nobody knocked down).

`playertest` (console) round-trips a record through the database and checks the restart points.

## Not yet

- Body stats only change through our own activities (gym, eating, and so on, still to come). The
  game's own stat progression from running, cycling and swimming isn't tracked yet.
- A vanilla stats screen; respawn perks such as the girlfriends' (keeping weapons).
