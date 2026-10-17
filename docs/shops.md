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
| Barbers (`BARBERS`, `BARBER2`, `BARBER3`) | shopping.dat's haircuts per shop | `addPedClothes` on the head (CJ only), paid each time |
| Tattoo parlours (`TATTOO`, `TATTO2`, `TATTO3`) | shopping.dat's tattoos per shop | By body part (`tattooCategories`), paid each time; "Remove tattoo" per body part |

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
- **Trying on:** in clothes shops, the closet, barbers and tattoo parlours, the highlighted item is
  put on while browsing. Leaving (or dying) puts back what the player came in wearing; a purchase
  becomes the new outfit. The server applies previews only for items on that menu.
- **Purchases:** every purchase is checked on the server (still at the counter, item really sold
  there, enough money). The server applies it, takes the money and saves the player.

### Closet

Every safehouse closet door leads into one shared changing room (the `CHANGER` hub, see
Entrances). Arriving there opens the closet: every clothing item the player owns, from all chains,
by the same categories, free to put on, plus "Take off" per category. `vana-interiors` reports
arrivals with the `onPlayerUseEntrance` event (name, from interior, to interior, arrived at a hub).

### Shop points

`tools/seed/seed_interiors.py` finds the customer point from a counter object in the interior
(`gta_int.img`). That works for the fast-food tills, most clothes shops and two Ammu-Nations; the
rest start a few metres inside the door. Vanilla keeps the real points inside the compiled shop
scripts in `script.img`.

To correct one in game, stand where customers should and use `/shoppoint <NAME>` (restricted:
`command.shoppoint`). The marker moves at once, and the server log prints the line to paste into
`config/points.lua`.

`shoptest` (console) checks that every shop has stock, every weapon maps to a game weapon and every
vendor has a known kind.

### Vending machines and food carts

`tools/seed/seed_vendors.py` places them from the map IPLs and both IMGs into
`vana-shops/config/vendors.lua` (104: soda and candy machines, hot dog, noodle and ice cream carts).
Walk up to one and press enter/exit (F) to buy. The server checks the distance and money, then takes
the money, adds health and fat and plays the vanilla `VENDING` animation. Prices and effects are in
`config/vendorkinds.lua`; they're ours, since vanilla's are inside the compiled vendor scripts.

## Gym (`vana-gym`)

The equipment is seeded from `gta_int.img` by `tools/seed/seed_gym.py` into
`vana-gym/config/equipment.lua`: 4 bikes, 4 treadmills, 5 benches and 4 mats in the three public
gyms and Madd Dogg's home gym. Vanilla's gym scripts (`gym*.scm`) are script brains on those
objects.

- **Working out:** walk into a machine's marker to get on (vanilla `GYMNASIUM` and `benchpress`
  animations). Tap the sprint key to fill the bar; a full bar is one rep. F or Backspace gets off.
- **Gains per rep** (`vana-gym/config/gym.lua`):

  | Machine | Trains | Fat |
  | --- | --- | --- |
  | Exercise bike, treadmill | stamina +2 | -1 |
  | Bench press | muscle +3 | -1 |

  The server checks the pace (a rep takes at least 0.9 s) and caps gains at 60 points per stat per
  real hour (vanilla caps a day's workout). `vana-player` saves the stats.
- **Placement:** the player is put at the machine's position and heading, with per-machine offsets
  in `placement` for fine-tuning in game.
- **Fighting styles:** the mats are `fighting` shop points (`GYM1`-`3` in
  `vana-shops/config/points.lua`). Ganton teaches boxing, Cobra in San Fierro kung fu, Below the
  Belt in Las Venturas kickboxing.
  - Learning a style needs 35% muscle (`fightingMinMuscle`).
  - Learned styles are owned for good, and any mat lets you switch between them or back to the
    default. The current style is saved with the player.

`gymtest` (console) checks the equipment data and the hourly cap.

## Not yet

- **Dumbbells:** vanilla's `gymdumb.scm` free weights aren't placed objects in the map data.
- **Vanilla shop behaviour:** item preview (trying clothes on, weapon close-ups).

- **Other shops:** car mod shops (TransFender, Loco Low Co., Wheel Arch Angels).
