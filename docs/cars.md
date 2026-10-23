# Added vehicles (`vana-cars`)

Vehicles San Andreas never had where it should have: each city's own police cars, more
ambulances and fire trucks, school and tour buses, mail and delivery vans, more taxis and beaters.
They come from mods, cherry-picked ([credits.md](credits.md)), and are always **added**: each is a
model of its own, built on a vanilla parent, and no vanilla model, name or ID is ever replaced. The
same goes for retextures (the Flame Infernus is a model of its own; the vanilla Infernus is
untouched). Only the shared vehicle textures (dirt, lights, tyres, plates) are swapped for a clean,
higher-resolution set, as the pack does.

## How

- **Models:** at start the server asks Neon for a model per vehicle (`engineRequestModel("vehicle",
  parent, name)`: IDs from 42341 up, the same on every client), and sets its handling from the
  pack's `handling.cfg` line (`setModelHandling`; the value and lights' shapes aren't settable and
  stay the parent's). Clients load its TXD and DFF onto that model only (`client.lua`).
- **IDs change** each time vana-cars starts (Neon doesn't reuse freed IDs), so other resources ask
  it by name (`getModel`), and kept cars are saved by model name (`modelName` in vana-vehicles'
  snapshot) and rebuilt by it.
- **Dressing:** a vehicle of an added model made by any resource gets one of the model's own colour
  sets (the pack's `carcols.dat`), and, for an emergency vehicle, sirens (the game only gives its
  own models theirs): two lights on the roof, positions a first guess (`CarSirens`, to tune in
  game). vana-vehicles' `tuneRandomly` (traffic, parked cars, events), `/car`, kept cars rebuilt
  (colours kept) and vana-services' responders and roadblocks all call it.
- **Shared textures:** `mods/evvpr/generic/vehicle.txd` (19 textures, 14 MB) is imported into every
  vehicle model, vanilla and added.
- **Files** go to clients when they join (about 120 MB, cached by MTA after the first time).

## Where they appear

- **Traffic and parked cars:** vana-population adds each to the car groups the pack puts it in
  (`groups`, the popcycle groups of `cargrp.dat`: taxis with workers, business people, park and
  beach folk; delivery vans with workers; beaters with the poor), whenever vana-cars (re)starts.
- **Services** (`CarVariants`, from the pack's `ModelVariations_Vehicles.ini`): the vanilla service
  vehicle or one of its variants, at random:

| Vanilla | Variants |
| --- | --- |
| LSPD cruiser (596) | Brigham LSPD |
| SFPD (597) | Solair SFPD |
| LVPD (598) | Beaufort LVPD |
| Police Ranger (599) | Ranger, Sheriff Patriot, Velox SAPD |
| FBI Rancher (490) | FBI Stanier SL, FBI Brigham, FBI Premier, Cheetah (unmarked) |
| Enforcer (427) | Enforcer (second model) |
| Ambulance (416) | Ambulance (Steed), Ambulance (Burrito) |
| Fire Truck (407) | Firehook, Biff FDSA; at the airports only the Firebrigade |
| Securicar (428) | in Las Venturas only the casino Securicar |

- **Retextures** (`CarSkins`): now and then in place of the vanilla model where it's picked as a
  service vehicle or variant (Flame Infernus 15%, Big Boy's Toys monster truck 50%).
- **`/car <name>`** spawns any of them by name or model name (`/car brigham lspd`, `/car taco`).

## The batch

41 vehicles from the Extended Vanilla Vehicles Pack Reboot 2.0, chosen for what San Andreas lacks
(service vehicles, liveries, everyday types), and two retextures:

| Group | Vehicles |
| --- | --- |
| Police | Brigham LSPD, Solair SFPD, Beaufort LVPD, Velox SAPD, Ranger, Sheriff Patriot, Cheetah (unmarked) |
| FBI, SWAT | FBI Stanier SL, FBI Brigham, FBI Premier, Enforcer |
| Ambulance, fire | Ambulance (Steed), Ambulance (Burrito), Firebrigade, Firehook, Biff FDSA |
| City services | School Bus, Tour Bus, Mail Truck, Trashmaster, Sweeper, Utility Van, Heavy Tow Truck, Tow Truck, Securicar, Lifeguard |
| Taxis | Taxi (Brigham), Taxi (Greenwood), Cabbie Beater |
| Delivery | Pizza Chimp, Taco Van, Chilli Wagon, Rusty Browns, Messenger, Dolva, Bastion |
| Beaters | Grand Beater, Chumash Beater, Montoya Beater, Skulker Beater, Avaritia Beater |
| Retextures | Flame Infernus, Big Boy's Toys monster truck |

Their data (`config/vehicles.lua`: parent, label, handling, colours, groups, credit) was seeded once
from the pack's `vehicles.ide`, `handling.cfg`, `carcols.dat`, `cargrp.dat` and `vehicle names.fxt`,
and is ours from here on. Names: the pack's (`display`), or the game's own text where the pack
reuses a vanilla label (Taxi, Ambulance, Securicar, Ranger...).

## Not yet

- **In game:** every model as it looks (and a check for real-world branding on each), siren
  positions, handling, the HD shared textures.
- **Names in the game's own HUD** (entering a vehicle shows its parent's name).
- **The Flame Jester:** a paintjob TXD, which the game applies to the car's remap materials from
  its paintjob slots, not the model's TXD; needs its own handling.
- **Left for later:** what needs trailers (the Long Bus, semis), the new trains, planes and
  helicopters, and the pack's everyday cars beyond these gaps.

## Commands

| Command | What |
| --- | --- |
| `carstest` (console) | Every added model made, its files there, a name, colours and a credit; every variant names an added vehicle |
