# Interiors and shops

## Entrances (`vana-interiors`)

MTA disables GTA's own entry/exit manager, so the 370 vanilla entrances are reproduced server-side.
`tools/seed/seed_interiors.py` seeds them from the map IPLs' `enex` sections into
`config/entrances.lua`.

- **Markers:** each entry is one marker: a yellow arrow over the doorway and a trigger box (the
  IPL's full widths, at least 1.2 m).
- **Pairing:** vanilla pairs entries by name and flags. An entry with flag bit 4 ("create linked
  pair") is a door: stepping into it on foot takes you, after a fade, to the same-named entry
  without that bit (the hub). A hub takes you back out through the door you came in by, or the
  first door if you didn't come in by one.
  - This covers street doors, interiors shared by several doors (every pizza shop shares one), and
    safehouse closets (14 houses, one shared changing room).
  - Names without a door/hub split pair by area: outside leads in, inside leads back out the way
    you came.
  - You land at the destination entry's exit point, 1 m up (GTA's entry-exit conversion, matching
    Neon's verified Binco data), facing its heading.
- **Arrows:** they hover 1.5 m above the trigger.
- **Opening hours:** taken from the IPL. A closed door says when it opens; set
  `respectOpeningHours` off to ignore hours.
- **Unpaired names:** 58 names have only one side. They're interiors that vanilla reaches by
  script: the girlfriends' houses (`GF1`-`6`), burglary houses (`LAHS*`, `SFHS*`, `VGHS*`), the
  dam (`DAMIN`/`DAMOUT`) and similar. They'll come with the activities that use them.

`interiortest` (console) checks that entrances pair up.

## Shops (`vana-shops`)

Prices and stock come from the retail `shopping.dat`, and names from the retail text file
`american.gxt`; both are read at runtime (copy them from the disc; see `setup.md`).

- **Names:** each item's nametag in `shopping.dat` is a GXT key (`VESTA` is "Black Tank", `PISTOL`
  is "9mm"). `vana-shops/gxt.lua` reads the GXT's MAIN table, whose keys are JAMCRC32 hashes, so
  menus show exactly the vanilla names.
- **Prices:** `shopping.dat`'s, overridable per item in `config/shops.lua` (`prices`). Each shop interior has a point where customers stand (`config/points.lua`): walk into
its orange marker to open the menu.

| Shop | Stock | Effect |
| --- | --- | --- |
| Ammu-Nation (`AMMUN1`-`5`) | shopping.dat's per-shop list | Weapon with the listed ammo; armour sets 100 |
| Cluckin' Bell, Well Stacked Pizza, Burger Shot | the three meal sizes and a salad | `calories N`: +N health (up to max) and fat; `health N`: +N health |
| Binco, Pro-Laps, SubUrban, ZIP, Victim, Didier Sachs | shopping.dat's clothes per shop | `addPedClothes` (CJ only) |
| 24/7 counters | ours: camera, flowers, cane, brass knuckles, spraycan, extinguisher, parachute | Weapon item |

The 24/7 stock is not vanilla; edit it in `config/shops.lua`, along with the weapon ID mapping,
price overrides and `fatPerCalorie`.

- **The menu:** vanilla-style, top-left. Arrow keys choose, Enter buys, Backspace goes back or
  leaves; game controls are off while it's open.
- **Clothes shops:** each chain sells exactly its own `shopping.dat` range (246 items are sold by
  only one chain).
  - The menu opens on apparel categories (`clothesCategories` in `config/shops.lua`: torso, legs,
    shoes, hats, glasses, necklaces, watches); each category lists its items, plus "Take off".
  - Clothes are bought once and owned for good (saved with the player by `vana-player`). Owned
    items show OWNED instead of a price, and choosing one just puts it on.
- **Purchases:** every purchase is checked on the server (still at the counter, item really sold
  there, enough money). The server applies it, takes the money and saves the player.

### Shop points

`tools/seed/seed_interiors.py` finds the customer point from a counter object in the interior
(`gta_int.img`). That works for the fast-food tills, most clothes shops and two Ammu-Nations; the
rest start a few metres inside the door. Vanilla keeps the real points inside the compiled shop
scripts in `script.img`.

To correct one in game, stand where customers should and use `/shoppoint <NAME>` (restricted:
`command.shoppoint`). The marker moves at once, and the server log prints the line to paste into
`config/points.lua`.

`shoptest` (console) checks that every shop has stock and every weapon maps to a game weapon.

## Not yet

- **Gym:** equipment works through script brains on `GYM_BIKE`, `GYM_BENCH1`, `GYM_TREADMILL` and
  `GYM_MAT1` objects (positions from the interior IPLs), with a minigame.
- **Vanilla shop behaviour:** item preview (trying clothes on, weapon close-ups).
- **Closet:** safehouse wardrobes offering every owned clothing item, all chains combined, by the
  same categories (`getOwned(player, "clothes")` in `vana-player` already lists them).
- **Other shops:** barbers, tattoos, car mod shops, vending machines and food carts (script
  brains on objects).
