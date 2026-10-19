# Interiors and shops

## Entrances (`vana-interiors`)

MTA disables GTA's own entry/exit manager, so the 370 vanilla entrances are reproduced server-side.
`tools/seed/seed_interiors.py` seeds them from the map IPLs' `enex` sections into
`[data]/vana-data-interiors/entrances.map`.

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
- **Prices:** `shopping.dat`'s, overridable per item in `config/shops.lua` (`prices`). Each shop interior has a point where customers stand (`[data]/vana-data-shops/shops.map`): press enter/exit in
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

### Shopkeepers

`vana-shops/keepers.lua` ports the vanilla shop scripts' staff (`BARB`, `TATTO`, `AMUNAT`, `JFUD` and
`CLOTH` in `main.scm`). Shop points for these shops are vanilla's customer spots.
Each shop type has one layout in interior coordinates (keeper, customer seat, camera) and each shop
an offset from it, in `config/keepers.lua`; the keeper models are vanilla's.

- **Barbers:** the barber idles beside the chair. The marker is the chair: sitting down
  (`BRB_Sit_In`) opens the menu under vanilla's camera; browsing has the barber cut, buying has CJ
  check the result in the mirror (a beard animation for beard styles), leaving gets CJ up.
- **Tattoo parlours:** the artist sits at the kit. Choosing a body part has CJ and the artist take
  that part's pose (`TAT_<part>_In/Pose/Out`); leaving gets CJ up. Vanilla also animates the kit
  object, which MTA can't do yet, so the kit stays still.
- **Ammu-Nation:** the clerk lifts the highlighted weapon (`SHP_1H/2H/Ar_Lift`, as vanilla picks
  per weapon) and puts it back to show the next.
- **Fast food:** the server lifts the highlighted meal on its tray. As in vanilla, CJ eats on the way
  out after buying (`EAT_Burger/Pizza/Chicken`, 5 s) and gets thanked. From the 11th item in a game
  day he throws up instead (`EAT_Vomit_P` with the `puke` effect, 8 s; the keeper recoils with
  `EAT_Vomit_SK`): that visit's health and fat are undone and 10 more health is lost.
- **Clothes:** CJ steps into the changing room (`CLO_In`), poses per apparel category, `CLO_Buy` on
  a purchase and steps out when done; hats and glasses use vanilla's hat camera. Each chain's
  changing room door is placed as vanilla does and hidden while CJ passes it (vanilla animates it).
- What a keeper holds is the ped's `vana:holding` model; `keepers_client.lua` keeps it in the hand.
- One customer per shop at a time; anyone else is told the shop is busy. A killed keeper comes back
  after a minute. `shoptest` checks that every keeper is in place.

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
`[data]/vana-data-shops/shops.map`.

`shoptest` (console) checks that every shop has stock, every weapon maps to a game weapon and every
vendor has a known kind.

### Robbery

Threatening a shopkeeper (aiming a gun at them, shooting in the shop, or hurting them) closes the
shop, as in vanilla: whoever is being served is let go, and nobody is served until no player has
been near (`resetRadius`) for `resetMs`, when the keeper is back at the counter (or a new one, if
they died). By shop (vanilla's scripts):

- **Ammu-Nation** (`AMUNAT`): the clerk draws a pistol (vanilla: pro skill, accuracy 80) and shoots
  from behind the counter (Neon `setPedStayInSamePlace` + `setPedKillOnFoot`).
- **Barbers, tattoo parlours, clothes shops, fast food** (`BARB`, `TATTO`, `CLOTH`, `SKBRAIN`): the
  keeper puts their hands up.
- **Ours:** keep the aim on a hands-up keeper for `cashSeconds` and they hand over the till (cash by
  shop type, `cash`), a `holdup` crime; once per shop per `cooldownMs`. Vanilla pays nothing.

All of it is `robbery` in `config/shops.lua`. Not yet: vanilla's panicking customers (`FFPNC`: about
half duck, the rest put their hands up); our shops have no customer peds yet.

### Vending machines and food carts

`tools/seed/seed_vendors.py` places them from the map IPLs and both IMGs into
`[data]/vana-data-shops/shops.map` (104: soda and candy machines, hot dog, noodle and ice cream carts).
Walk up to one and press enter/exit (F) to buy. The server checks the distance and money, then takes
the money, adds health and fat and plays the vanilla `VENDING` animation. Prices and effects are in
`config/vendorkinds.lua`; they're ours, since vanilla's are inside the compiled vendor scripts.

### Mod garages

Vanilla's `CARMOD` (`garages.lua`, `config/garages.lua`): the three Transfenders (LS, SF, LV), Loco
Low Co. (LS) and Wheel Arch Angels (SF), all open.

- **Getting in:** the garage doors stay up (`setGarageOpen` with each garage's game index, `door`);
  drive in and stop on the marker just inside (vanilla's spot, 4 m). Coming back out puts you on it,
  so you're only taken in again after driving off it. It's taken into the garage
  (vanilla's interior and spot for that garage), alone: each customer gets their own dimension.
  With `exclusive` on (it is), one customer per doorway at a time; anyone else is told "Somebody is
  already in the garage." Backspace at the top of the menu drives out, back in the doorway facing
  out (vanilla's headings). Quitting, dying or the car being destroyed ends it at once.
- **What gets in (ours):** any car, monster truck or quad, at any garage, emergency and big vehicles
  included. Vanilla refuses those, and sends lowriders only to Loco Low Co. and street racers only to
  Wheel Arch Angels. Bikes, boats, aircraft and trains get "You cannot mod this vehicle." (`MODNO2`).
- **Stock:** each garage's `shopping.dat` list (`carmod1` normal cars, `carmod2` lowriders,
  `carmod3` street racers), priced from its `CarMods` section, named by the game's text (each item's
  name tag). Ours, at every garage: all 17 wheels, nitro (2x, 5x, 10x), hydraulics, the stereo, and
  the 20 spoilers MTA fits to any car. Categories are MTA's upgrade slots. Parts this vehicle can't
  take (`getVehicleCompatibleUpgrades`) are shown greyed out, `N/A`.
- **Trying on:** the highlighted part, colour or paintjob is put on the car (server-side, so the car
  really changes); leaving takes off whatever wasn't bought. The camera frames the category's part
  of the car (front, rear, side, roof).
- **Performance parts (ours):** after the vanilla categories, Engine, Turbo, Brakes, Suspension,
  Tyres, Armour, Lightweight and Drivetrain, from vana-vehicles ([vehicles.md](vehicles.md)); tried
  on like the rest.
- **Colours and paintjobs:** $150 each (vanilla). Colour 1 and 2 from the 127-colour palette
  (`carcols.dat`, seeded) in a grid; paintjobs for the 13 models that have them (vana-vehicles'
  `paintjobs`).
- **Messages:** the game's: "You don't have enough money to buy this item." (`SHOPNO`), "Your
  vehicle is already this color." (`COLORNO`), "You have already bought this item!" (`CLTHNO2`).
- **Kept:** bought parts, colours and paintjobs stay on the car, and `vana-vehicles` persists them
  with the rest of it. A car saved while in a garage is saved as it will leave: in the doorway, with
  what was bought (element data `vana:garage`), not in the garage's dimension with a part on trial.
- **Data:** `config/carmods_data.lua` (part IDs from `veh_mods.ide`, the palette from `carcols.dat`)
  is seeded by `tools/seed/seed_carmods.py`; stock and prices are read from `data/shopping.dat`.
- `garagetest` (console): the stock resolves, a Blade's menu builds, a police car takes the
  universal parts. Warp names for the doorways: `transfender`, `transfender.sf`, `transfender.lv`,
  `locolow`, `waa`.
- **Not done:** the door closing behind you as vanilla's does, vanilla's per-part camera moves, the bonnet ornaments 1111/1112
  (MTA refuses them on every model).

### Pay 'n' Spray

Vanilla's ten respray garages (`sprays.lua`, `config/sprays.lua`: the map files' `grge` entries of
type 5, their game indices for `setGarageOpen`), with vanilla's radar icon (63). Drive in and stop
(inside the garage's box): the door comes down, vanilla's respray sound plays (frontend event 16),
and the vehicle comes out fixed for $100 (`fixVehicle` on the server, so every client gets the same
car). Ours: it only repairs (no new colour, no change to the wanted level), and only when there's
something to fix (health, or any panel, door, light or tyre not as new); without the money,
vanilla's `GA_3` and its no-cash sound. The doors stay up otherwise. Boats, aircraft and trains
aren't served. `spraytest` (console) checks the boxes and the damage test.

The mod garages repair too: **Repair** at the top of their menu, $100, greyed out when there's
nothing to fix.

## Gym (`vana-gym`)

The equipment is seeded from `gta_int.img` by `tools/seed/seed_gym.py` into
`[data]/vana-data-gym/gym.map`: 4 bikes, 4 treadmills, 5 benches and 4 mats in the three public
gyms and Madd Dogg's home gym. Vanilla's gym scripts (`GYMBIKE`, `GYMBENC`, `GYMTREA`, `GYMDUMB` in
`main.scm`) are script brains on those objects; the mats are the dumbbell stations.

- **Working out:** press enter/exit on a machine's marker to get on (vanilla `GYMNASIUM`, `benchpress` and
  `freeweights` animations, played for their full length). Tap the sprint key to fill the power
  bar; a full bar is one rep. F or Backspace gets off.
- **Props** (`props.lua`, `props` in `gym.lua`): as in vanilla, the barbell rests on the bench and
  the dumbbells by the mat until the hands pick them up partway through getting on, and go back
  partway through getting off; the bike's pedals turn while someone rides. Every client draws them,
  following the user's hand bones each frame.
- **Gains per rep** (`vana-gym/config/gym.lua`):

  | Machine | Trains | Fat |
  | --- | --- | --- |
  | Exercise bike, treadmill | stamina +2 | -1 |
  | Bench press | muscle +3 | -1 |
  | Dumbbells | muscle +2 | -1 |

  The server checks the pace (a rep takes at least 0.9 s) and caps gains at 60 points per stat per
  real hour (vanilla caps a day's workout). `vana-player` saves the stats.
- **Placement:** the player starts in front of the machine (`placement`: the inverse of how far
  each get-on animation carries the root), and the marker sits there.
- **Fighting styles:** `fighting` shop points at the vanilla trainers' spots (`GYM1`-`3` in
  `[data]/vana-data-shops/shops.map`). Ganton teaches boxing, Cobra in San Fierro kung fu, Below the
  Belt in Las Venturas kickboxing.
  - Learning a style needs 35% muscle (`fightingMinMuscle`).
  - Learned styles are owned for good, and any trainer lets you switch between them or back to the
    default. The current style is saved with the player.

`gymtest` (console) checks the equipment data and the hourly cap.

## Not yet

- **Gym reps:** the bar only fills on taps; vanilla scrubs the lift animation (`*_up_smooth`) by the
  power bar, so the lift height follows how fast you tap.
- **Object animations:** vanilla animates the tattoo kit (`TAT_*_O`) and the changing room doors
  (`CLO_Pose_In_O`/`Out_O`); MTA can't play animations on objects, so the kit stays still and the
  doors are hidden while CJ passes them.
- **Clothes shop sequence:** the order of CJ's changing room animations (`CLO_In`, the per-category
  poses, `CLO_Buy`, `CLO_Out`) is partly guessed; vanilla also goes in and out of the room between
  items.
- **Placement to check in game:** keepers and seated customers stand at the script's ground z + 1
  (vanilla's convention); held items sit exactly on the hand bone with no offset. The food tray
  preview is rotated 90 degrees for at least the Well Stacked Pizza meals.
- **24/7 stores:** no vanilla shop script, so no keeper yet.
- **Wardrobe:** vanilla's safehouse wardrobe script (`WARROBE`) isn't ported; our closet is the
  menu in the shared changing room.
- **Hostile keepers:** keepers can be killed (back after a minute) but don't react; vanilla's react
  when attacked (the Ammu-Nation clerk fights back).
- **Other shops:** car mod shops (TransFender, Loco Low Co., Wheel Arch Angels).
