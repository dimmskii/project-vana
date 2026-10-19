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
