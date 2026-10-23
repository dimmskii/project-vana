# Added vehicles (`vana-cars`)

Vehicles San Andreas never had: first where it should have (each city's own police cars, more
ambulances and fire trucks, school and tour buses, mail and delivery vans, more taxis and beaters),
then the rest of the pack: everyday, sports and race cars, bikes, boats, trailers, trains and
unarmed aircraft.
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
- **Files** (about 920 MB in all) aren't sent at join: a model's DFF and TXD are downloaded the first
  time a vehicle of it streams in (it shows as its parent until then), and the service vehicles'
  variants in the background, two at a time. MTA keeps them for next time. The shared textures
  (14 MB) come at join.
- **The ID budget:** Neon never reuses a model ID while the server runs (so a late packet can't be
  mistaken for a new model), and IDs go up to 65534: vana-cars can be restarted about 60 times
  (365 models each) before the server itself must be. Allocation failures are a warning in the log.

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

- **Trains:** none for now. **On hold (commented out):** the added train models (Streakliner, Mastodon and its wagons) crash
the client: Neon's `CPoolsSA::AddTrain` only creates the six vanilla train models, and an added one
reaches `CTrain::CreateMissionTrain` with no model (2026-10-23). Their entries in
`config/vehicles.lua`, their files in `meta.xml` and vana-trains' use of them are commented out,
waiting on a fix in Neon.
- **Aircraft** (vana-air): Little Willy and the Armadillo among the helicopters passing by, the
  Baron and AT-20 among the small planes overhead and the airliner among the big ones; the Blimp
  drifts over now and then.
- **Retextures** (`CarSkins`): now and then in place of the vanilla model where it's picked as a
  service vehicle or variant (Flame Infernus 15%, Big Boy's Toys monster truck 50%).
- **`/car <name>`** spawns any of them by name or model name (`/car brigham lspd`, `/car taco`).

## What's added

363 vehicles from the Extended Vanilla Vehicles Pack Reboot 2.0 and two retextures. First the
service vehicles, liveries and everyday types San Andreas lacks:

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

Then the rest of the pack: 272 cars (everyday, sports, race, muscle, utility), 22 bikes, a bicycle
(Whippet), a trike, 6 monster trucks, 4 boats, 6 trailers players can hook, the trains (Streakliner,
Mastodon, tank, scrap and container wagons) and the unarmed aircraft (Baron, AT-20, the airliner,
Blimp, Little Willy, Armadillo). Parents: the vanilla model whose handling it uses, or the pack's
own parent hint, else a vanilla one of its type.

Left out: the pack's armed military aircraft (Valkyrie, KH-1, Molotok, Peregrine, Tula, Mogul: the
pack arms them with its scripts); Kubota (a real brand); the Long Bus and its trailer (traffic
doesn't tow); the Issi (MTA finds its DFF broken); the Seville, Skateboard and Blista GPX (no data
or files in the pack); every model that replaces a vanilla one, and the pack's scripts, plugins,
tuning parts and paintjobs.

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
- **Tuning parts and paintjobs** the pack gives some cars (bumpers, spoilers, paintjob TXDs).
- **Aircraft in game:** the added aircraft flown by vana-air are untested.

## Commands

| Command | What |
| --- | --- |
| `carstest` (console) | Every added model made, its files there, a name, colours and a credit; every variant names an added vehicle |
