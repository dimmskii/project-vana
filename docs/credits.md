# Credits and third-party content

## How mod content is handled

- **Community mods** we port or use content from (models, textures, scripts, text) are copied into
  a `mods/<mod>/` folder in the resource that uses them, and committed. The usual `.gitignore` rule
  against game files has an exception for `vana-*/mods/**`.
- **Rockstar's files** (the retail game data: IMG, IPL, IDE, DAT, GXT, SCM...) are never committed.
  They're copied from your own install at setup (see [setup.md](setup.md)), or extracted into our own
  config.
- Every mod gets an entry below: author, where it came from, its license or terms as far as known,
  and what we use. **None of the mods below states a license.** Before the project is distributed
  publicly, ask each author for permission (the contact is listed where the mod's readme gives one),
  or replace their content with our own.

## Mods

### Bigfoot v1.2

- **Author:** Tysman (model and script; the readme credits help from the GTA Forums community).
  Contact from the readme: tysrocks@hotmail.com.
- **Source:** a local copy of the CLEO mod (`gtaref/mta_modded`): `cleo/Bigfoot.cs`,
  `models/Bigfoot.img`, `docs/bigfoot.txt`, `docs/bigfoot map.jpg`. Original download site unknown.
- **License:** none stated.
- **In the project:** `vana-encounters/mods/bigfoot/`
  - `bigfoot.dff`, `bigfoot.txd`: the model, extracted from `Bigfoot.img`
  - `Bigfoot.cs`: the compiled CLEO script; `Bigfoot.txt`: its decompile (Sanny Builder, GTAG opcode
    database, 2013), the reference for our Lua port
  - `readme.txt`, `bigfoot_map.jpg`: the original readme and spawn-area map
  - Ported in `vana-encounters` (see [encounters.md](encounters.md)); the spawn spots are
    `encounter` elements in `[data]/vana-data-encounters`

### Gasoline (fuel gauge and speedometer)

- **Author:** unconfirmed. The script and textures (`SPEEDOM`, `STRELK`, `SCALEF`/`SCALEE`, `NITRO`)
  match the speedometer-and-fuel CLEO mods of the late 2000s, most likely "CraZZZy Speedometer v.2.2
  Full + Limited Fuel" by CraZZZy GameRRR, or the "Yelmi Speedometer", which ships a
  `gasoline.txd` ([libertycity.net](https://libertycity.net/files/gta-san-andreas/3231-crazzzy-speedometer-v.2.2-full.html),
  [Yelmi](https://libertycity.net/files/gta-san-andreas/28022-yelmi-speedometer.html)). To confirm
  against those archives.
- **Source:** a local copy (`gtaref/mta_modded`): `cleo/gasoline.cs`, `models/txd/gasoline.txd`.
- **License:** none known.
- **In the project:** `vana-vehicles/mods/gasoline/`: `gasoline.txd` (the gauge textures, for the
  dashboard), `gasoline.cs` (the compiled script; our fuel rules in `vana-vehicles/fuel.lua` are a
  port of it, read through a disassembly with Sanny Builder's `SASCM.INI`) and `gasoline.txt` (its
  decompile, the source of the pumps' exact positions).

## Ours

- **Gas station icons** (`vana-vehicles/icons/`: `radar_gasstn`, `radar_gasair`, `radar_gaswater`,
  PNG with their Paint.NET `.pdn` sources): drawn for ProjectVana by Dimmskii.

### Myths Maker 2.7 ("Animal World")

- **Authors:** a Russian-Brazilian team; the readme (`Files/Описание.txt`, in Russian) names Nadalao
  for the settings menu and doesn't give the others' names. Models credited inside the pack where
  they name their own makers (a texture is named `germanshepherdbymcmillan`).
- **Source:** a local copy (`gtaref/Myths_Maker 2.7 Animal World`): the CLEO scripts
  (`Myths_Maker.cs` decompiled, `Myths_Maker2.cs` doesn't: "Unknown parameter type 4Dh at offset
  17868"), and `cleo/Animals/AnimN`: each animal's ini, models, animations and sounds.
- **License:** none stated.
- **In the project:** `vana-wildlife/mods/myths_maker/<species>/`: the animals' models, textures,
  animations and sounds, de-duplicated (`tools/seed/seed_wildlife.py`); their locations and settings
  became `[data]/vana-data-wildlife`. Not its myths (the hunter) or its menus. See
  [wildlife.md](wildlife.md).

## Available, not used yet

In `gtaref/mta_modded`, with their readmes' credits:

- **Bear** v1.0 by Tysman (script help: ZAZ; model rigging and animation: Leatherface89, dtd mods).
- **COP** by 2pac.
- **Real Tram** by Doomed_Space_Marine (Devan_LT). Its readme asks that the mod not be taken
  ("ANY attempts to steal this mod..."), so don't use it without the author's permission.
- **ATP** aircraft scripts (Andromada, AT-400, Nevada, Shamal): decompiles in `cleo/ATP *.txt`,
  author not given.
- **volcano.cs**: no readme.

## Tools and references

- **gta-reversed** (<https://github.com/gta-reversed/gta-reversed>): engine behaviour and tables
  (vehicle audio settings, lane width, radio IDs), recorded as data in our configs.
- **Sanny Builder**'s opcode database (`SASCM.INI`), used to read compiled CLEO scripts.
- **MTA Neon** (<https://github.com/Dryxio/mtasa-neon>): the engine fork, and the API lists in
  `tools/luacheck/`.

### Extended Vanilla Vehicles Pack Reboot 2.0 (EVVPR)

- **Authors:** many; per model below, from the pack's `Mod Authors (Vehicles).txt` (copied as
  `authors-vehicles.txt`; scripts and other parts in `authors-other.txt`). The pack itself is a
  compilation; its readme names no single author.
- **Source:** a local copy (`gtaref/vehicle skins/extended-vanilla-vehicles-pack-reboot_1762020974_583960`).
- **License:** none stated.
- **In the project:** `vana-cars/mods/evvpr/` ([cars.md](cars.md)): 363 added vehicles (cherry-picked:
  their `.dff` and `.txd`; the pack's models that replace vanilla ones, its scripts and plugins are
  not used), and `generic/vehicle.txd`, the shared vehicle textures, credited in the pack as **Proper
  Vehicle Retex** by Miguel Araújo, Jéssica Natália, Nick Oliveira, Meck, Junior_Djjr and
  CassadorEterno. Their data (handling, colours, car groups, names) is in `vana-cars/config/vehicles.lua`.

  | Model | Name | Author |
  | --- | --- | --- |
  | `polbrg` | Brigham LSPD | GCT |
  | `polsol` | Solair SFPD | XG417 |
  | `polbet` | Beaufort LVPD | Crack Yo' Neck |
  | `polvel` | Velox SAPD | DirtyImpala |
  | `ranger` | RANGER | TheGhostWheels12 |
  | `polpat` | Sheriff Patriot | Son Of Big Boss |
  | `cheetuc` | CHEETAH | unknown (the pack lists it as "Cheetah UC (?)"; base Cheetah by Spartan 112) |
  | `fbistn` | FBI Stanier SL | Mit_subi92 |
  | `fbibrg` | FBI Brigham | GCT |
  | `fbiprm` | FBI Premier | LyoSHeX |
  | `enforcr2` | ENFORCR | Bob_Marley |
  | `steeda` | AMBULAN | Son Of Big Boss |
  | `burrita` | AMBULAN | XG417 |
  | `firebrg` | Firebrigade | Calvin.linardi |
  | `firehk` | Firehook | unknown (the pack lists it as "Firehook (?)") |
  | `oldfire` | Biff FDSA | Stella |
  | `school` | School Bus | Calvin.linardi |
  | `tourbus` | Tour Bus | Calvin.linardi |
  | `mailtruk` | Mail Truck | Calvin.linardi |
  | `trasha` | TRASHM | Burbalade |
  | `sweepeb` | SWEEPER | Calvin.linardi |
  | `utilityb` | UTILITY | XG417 |
  | `towheavy` | Heavy Tow Truck | KST |
  | `towtrukb` | TOWTRUK | Calvin.linardi |
  | `securic` | SECURI | TheGhostWheels12 |
  | `lguard` | Lifeguard | TheF3nt0n |
  | `taxib` | TAXI | GCT |
  | `taxic` | TAXI | Boss |
  | `cabshit` | Cabbie Beater | direct |
  | `pzchmp` | Pizza Chimp | Blakfire |
  | `taco` | Taco Van | TheF3nt0n |
  | `chilwagn` | Chilli Wagon | Calvin.linardi |
  | `rusty` | Rusty Browns | Cerberus Harrier |
  | `messen` | Messenger | XG417 |
  | `dolva` | Dolva | Calvin.linardi |
  | `bastion` | Bastion | StarGTS |
  | `empshit` | Grand Beater | Crack Yo' Neck |
  | `chumshit` | Chumash Beater | Crack Yo' Neck |
  | `montshit` | Montoya Beater | Crack Yo' Neck |
  | `skulshit` | Skulker Beater | Crack Yo' Neck |
  | `avarb` | Avaritia Beater | Crack Yo' Neck |
  | `stinger` | Stinger | blaue |
  | `baller` | Baller | Spartan 112 |
  | `beaufort` | Beaufort | Crack Yo' Neck |
  | `cloveb` | Clover | not in the pack's authors list |
  | `virgob` | Virgo Classic | Thiben |
  | `hotrod` | Hotrod | PROspekt |
  | `stallgt` | Stallion GT | Balcer |
  | `dft20` | DFT-20 | universetwisters |
  | `sab550` | Sabre 550SS | GCT |
  | `oceancup` | Oceanic Custom | Maladoy |
  | `zxf400` | ZXF400 Custom | Yonebayashi |
  | `matrch` | Matriach | Crack Yo' Neck |
  | `hustlera` | Hustler Deluxe | not in the pack's authors list |
  | `campbel` | Campbell | universetwisters |
  | `semfront` | Seminole | Calvin.linardi |
  | `admiralb` | Admiral Estate | miracle |
  | `yardie` | Yardie Lobo | Spartan112 |
  | `duneload` | Duneloader | not in the pack's authors list |
  | `coqueg4` | Coquette G4 | LyoSHeX |
  | `turgto` | Turismo GTO | Star GTS, Stella |
  | `coquette` | Coquette G3 | direct |
  | `frunner` | Freightrunner | Crack Yo' Neck |
  | `vamos` | Vamos | not in the pack's authors list |
  | `mirado` | Mirado | not in the pack's authors list |
  | `lokus` | Lokus | Piccardi |
  | `trophy` | Trophy Truck | Calvin.linardi |
  | `savanc` | Savanna Coupe | TheGhostWheels12 |
  | `ruiner` | Ruiner | direct |
  | `slamwest` | Slamvan West | JD-225 |
  | `dunerid2` | DUNE | not in the pack's authors list |
  | `baron` | Baron | Noah_Antilles |
  | `behemo` | Behemoth | Calvin.linardi |
  | `torcst` | Tornado Custom | Claude GTA III |
  | `polbase` | Mobile Police Base | Calvin.linardi |
  | `monsterc` | Hellraiser | not in the pack's authors list |
  | `monsterd` | Marshall | Spartan 112 |
  | `waltson` | Walton Truck | vanchik92 |
  | `sultrs` | Sultan RS | Piccardi |
  | `rowley` | Rowley | direct |
  | `bodhi` | Bodhi | Calvin.linardi |
  | `steed` | Steed | Son Of Big Boss |
  | `s230` | S-230 | 13Stewartc |
  | `vigero` | Vigero | 13Stewartc |
  | `admiralc` | Admiral Classic | Crack Yo' Neck |
  | `joratur` | Jora Turbo | Calvin.linardi |
  | `skidste` | Skid | Calvin.linardi |
  | `rauber` | Schrauber | joepesci69 |
  | `hvyapc` | APC | Calvin.linardi |
  | `stanrs` | Stanier ST | Blue |
  | `champio` | Champion | Helomyname |
  | `dante` | Dante | yonebayashi |
  | `cartr` | Car Trailer | emexD |
  | `artict4` | Trailer | not in the pack's authors list |
  | `manancl` | Manana Custom | direct |
  | `crusally` | Crusader 4x4 | TheGhostWheels12 |
  | `4fdraf` | 4F Drafter | joepesci69 |
  | `astron` | Astron | joepesci69 |
  | `archer` | Archer GXP | not in the pack's authors list |
  | `espresso` | Espresso | Crack Yo' Neck |
  | `lildvl` | Lil Devil | direct |
  | `vigle` | Vigero LE | joepesci69 |
  | `vigzx` | Vigero ZX | joepesci69 |
  | `staffcl` | Stafford Classic | TechnoGamerPH |
  | `defiant` | Defiant | JWJ |
  | `tulip` | Tulip | TheGhostWheels12 |
  | `dirtbike` | Enduro | TheGhostWheels12 |
  | `bf400b` | BF-400 MK2 | daniltk2 |
  | `stanier` | Stanier SL | Mit_subi92 (listed as "Stanier SL (& FBI)") |
  | `sprnova` | Supernova | TechnoPH |
  | `feltzrs` | Feltzer SR | Onik |
  | `deimos` | Deimos | Onik |
  | `mozza` | Mozzanica | StarGTS |
  | `sabot` | Sabotage | StarGTS |
  | `voyager` | Voyager | Calvin.linardi |
  | `bandita` | Baja Bandito | not in the pack's authors list |
  | `airtrain` | Airtrain | not in the pack's authors list |
  | `float` | Float | TheGhostWheels12 |
  | `roller` | Roller | TheGhostWheels12 |
  | `trike` | Trike | Calvin.linardi |
  | `airbt` | Leonida | Calvin.linardi |
  | `at20` | AT-20 | Calvin.linardi |
  | `trager` | Trager | Calvin.linardi |
  | `rtrainta` | Road Trailer | not in the pack's authors list |
  | `rtraintb` | Road Trailer | not in the pack's authors list |
  | `rectruk` | PACKER | not in the pack's authors list |
  | `clovr2` | Clover Primera | (Little) D |
  | `faction` | Faction TwinTurbo | not in the pack's authors list |
  | `hotrinf` | Hotring Faction | Puzi_Krem |
  | `tommy` | Tommy | Crack Yo' Neck |
  | `ensign` | Admiral Cabrio | XG417 |
  | `vertice` | Vertice | StarGTS |
  | `violat` | Violator | not in the pack's authors list |
  | `pr4` | PR4 | Spartan 112 |
  | `falcon` | Falcon | Spartan 112 |
  | `warthog` | Warthog | Spartan 112 |
  | `mjolnir` | Mjolnir | Spartan 112 |
  | `angel` | Angel | not in the pack's authors list |
  | `elevat` | Elevator | not in the pack's authors list |
  | `firetr` | Fire Trailer | not in the pack's authors list |
  | `lbdonk` | Lobo Donk | not in the pack's authors list |
  | `patmk` | Patriot MK1 | Son Of Big Boss |
  | `yola` | Yola | not in the pack's authors list |
  | `arbiter` | Arbiter | (Little) D |
  | `presid` | Presidente | Son Of Big Boss |
  | `glendcup` | Glendale Coupe | not in the pack's authors list |
  | `bullcl` | Bullet Classic | Crack Yo' Neck |
  | `bloodrb` | BLOODRA | not in the pack's authors list |
  | `imperat` | Imperator | not in the pack's authors list |
  | `centl` | Centella | (Little) D |
  | `viseris` | Viseris | TecnhoPH |
  | `ss800` | SS800 | Washek |
  | `savest` | Savestra | joepesci69 |
  | `streetf` | Streetfighter | MrFinger |
  | `armad` | Armadillo | Son Of Big Boss |
  | `blimp` | Blimp | Calvin.linardi |
  | `strizh` | Strizh | Dmitry Raven |
  | `shogun` | Shogun | TheMadeMan |
  | `brigham` | Brigham | GCT |
  | `empercl` | Emperor Classic | Burbalade |
  | `fort3` | Fortune Eryth | (Little) D |
  | `bug` | Bug | direct |
  | `monstro` | Monstrosity | tigerlim |
  | `deluxo` | Deluxo | Calvin.linardi |
  | `diamondc` | Diamond | Stierlitz |
  | `dukes` | Dukes | Spartan 112 |
  | `estate` | Brigham Estate | GCT |
  | `perens` | Perenedan | direct |
  | `burritb` | Burrito XL | Qwerty Van Hallen |
  | `pounder` | Pounder | Son Of Big Boss |
  | `rhapsody` | Rhapsody | matinat0r |
  | `bufcl` | Buffalo Classic | Crack Yo' Neck |
  | `puma` | Puma | joepesci69 |
  | `stanle` | Stanier LE | Son Of Big Boss |
  | `staber` | Staber | m1racle |
  | `silver` | Silver | Stierlitz |
  | `burritc` | Burrito XLB | Maladoy |
  | `ranchpck` | Rancher Pickup | L.D.G. |
  | `cambrid` | Cambridge | Calvin.linardi |
  | `sadlera` | Sadler MT | TheGhostWheels12 |
  | `jeeper` | Jeeper | AiExcel |
  | `corsac` | Corsac | by Crack Yo' Neck |
  | `letrune` | Letrune | Crack Yo' Neck |
  | `brioso` | Brioso | Helomyname |
  | `cerrano` | Cerrano | Maladoy |
  | `bnxlb` | Benson XLB | Son Of Big Boss |
  | `schafter` | Schafter | Crack Yo' Neck |
  | `ellatino` | El Latino | Spartan 112 |
  | `zion` | Zion | Son Of Big Boss |
  | `vanguard` | Vanguard | Crack Yo' Neck |
  | `verdana` | Verdana | Crack Yo' Neck |
  | `interst` | Interstate | Fuze |
  | `warwick` | Warwick | Crack Yo' Neck |
  | `zartex` | Zartex | Maladoy |
  | `emperg` | Grand Emperor | Crack Yo' Neck (listed as "Grand Emperor (+ beater version)") |
  | `dft40` | DFT-40 | SergeDV |
  | `bulli` | Bullion | Spartan 112 |
  | `esper2` | Esperanto LT | not in the pack's authors list |
  | `mesagr` | Mesa Grande | Calvin.linardi |
  | `cruiser` | Cruiser | Crack Yo' Neck |
  | `bison` | Bison | Crack Yo' Neck |
  | `stromgt` | Stromberg GT | Crack Yo' Neck |
  | `chumash` | Chumash | Crack Yo' Neck (listed as "Chumash (+ beater version)") |
  | `longb` | Longbridge | Crack Yo' Neck |
  | `montoya` | Montoya | Crack Yo' Neck (listed as "Montoya (+ beater version)") |
  | `zircon` | Zircon CX | Crack Yo' Neck |
  | `hauler` | Hauler | Puzi_krem |
  | `waltbed` | Waltbed | Spartan 112 |
  | `waltvan` | Waltvan | Spartan 112 |
  | `saxon` | Saxon | Calvin.linardi |
  | `idaho` | Idaho | TommyAssassin |
  | `linerufx` | Linerunner FX | Calvin.linardi |
  | `anchor` | Anchor | TheMadeMan |
  | `futo` | Futo | joepesci69 |
  | `ranchxl` | Rancher XL | SergeDV |
  | `fagaloa` | Fagaloa | direct |
  | `ventura` | Ventura | Maladoy |
  | `mesab` | Mesa Off-Road | Bobby & Spartan 112 |
  | `granger` | Granger 2400LX | Son Of Big Boss |
  | `zircondx` | Zircon DX | Crack Yo' Neck |
  | `catalina` | Catalina | Crack Yo' Neck |
  | `farmer` | Farmer | direct |
  | `bifta` | Bifta | direct |
  | `faggia` | Faggio Turbo | 1Hellen |
  | `vivant` | Vivant | direct |
  | `rnhart` | Rinehart | Crack Yo' Neck |
  | `skulker` | Skulker | Crack Yo' Neck (listed as "Skulker (+ beater version)") |
  | `moonbmc` | Moonbeam Classic | Crack Yo' Neck |
  | `rsvelt` | Roosevelt | Spartan 112 |
  | `avari` | Avaritia | Crack Yo' Neck (listed as "Avaritia (+ beater version)") |
  | `faggib` | Faggio Sport | 1Hellen |
  | `hellenb` | Hellenbach | Spartan 112 |
  | `daggr` | Dagger GTX | Maladoy |
  | `speedcl` | Speedo Classic | Crack Yo' Neck |
  | `rg21` | RG21 | Crack Yo' Neck |
  | `thunder` | Thunder | Crack Yo' Neck |
  | `d855` | D855 | Crack Yo' Neck |
  | `wx55` | WX55 | Crack Yo' Neck |
  | `fieldm` | Fieldmaster | Calvin.linardi |
  | `rio` | Rio | MrFinger |
  | `critt` | Critter | JWJ |
  | `morton` | Morton | Puzi_Krem |
  | `kalah` | Kalahari | XG417 |
  | `whippet` | Whippet | not in the pack's authors list |
  | `mrap` | Barricade | StarGTS |
  | `solairs` | Solair LM | XG417 |
  | `bobtail` | Bobtail | direct |
  | `grestat` | Greenwood Estate | Boss (listed as "Greenwood Estate (& Taxi)") |
  | `blackst` | Blackline ST | Maladoy |
  | `viento` | Viento | Colday Vss |
  | `streakl` | Streakliner | eliz0918 |
  | `splitz6` | Splitz-6 ATV | not in the pack's authors list |
  | `mastd` | Mastodon | eliz0918 (listed as "Mastodon (& Wagons)") |
  | `trailmas` | Trailmaster | XG417 |
  | `wcheese` | Cheese | Calvin.linardi |
  | `tuffb` | Tuff | Calvin.linardi (listed as "Tuff (& Towtruck)") |
  | `freitank` | Tank Vagon | eliz0918 (listed as "Mastodon (& Wagons)") |
  | `freigon` | Scrap Vagon | eliz0918 (listed as "Mastodon (& Wagons)") |
  | `freicont` | Contanier | eliz0918 (listed as "Mastodon (& Wagons)") |
  | `huntlsp` | Huntley Sport | Spartan 112 |
  | `karace` | Karinace | not in the pack's authors list |
  | `landstlb` | Landstalker JK | XG417 |
  | `grangsp` | Granger 2500SX | Son Of Big Boss |
  | `milano` | Milano | TheMadeMan |
  | `ocelotti` | Ocelotti | TheMadeMan |
  | `blistas` | Blista Skyview | YOCHIThMaster333 |
  | `sabgt` | Sabre 550GT | Dirty Impala |
  | `leotwn` | Leotown K90 | Crack Yo' Neck |
  | `speedo` | Speedo | Calvin.linardi |
  | `riata` | Riata | TheMadeMan |
  | `electron` | Electron | TheMadeMan |
  | `xp1` | XP1 | TheGhostWheels12 |
  | `coyote` | Coyote | Calvin.linardi |
  | `tailgate` | Tailgater | TheMadeMan |
  | `sightsee` | Sightseer | Calvin.linardi |
  | `rebel` | Rebel | TheMadeMan |
  | `impalcl` | Impaler SS | XG417 |
  | `sabtu` | Sabre Turbo | (Little) D |
  | `jb700` | JB 700 | DirtyImpala |
  | `gaung` | Gaunglet | Son Of Big Boss |
  | `blstcl` | Blista Classic | joepesci69 |
  | `thawk` | Thunderhawk | DirtyImpala |
  | `elegt` | Elegy RH6 | Crack Yo' Neck |
  | `callst` | Callista | Crack Yo' Neck |
  | `astrale` | Astrale | Crack Yo' Neck |
  | `jestei` | Jester Inferno | Crack Yo' Neck |
  | `peacekp` | Peacekeeper | Qwerty Van Hallen, Calvin.linardi |
  | `razor` | Razor | Calvin.linardi |
  | `impaler` | Impaler SZ | LyoSHeX |
  | `kuruma` | Kuruma | Qwerty Van Hallen |
  | `kamacho` | Kamacho | XG417 |
  | `lebonham` | Lebonham | Calvin.linardi |
  | `remus` | Remus | Mit_subi92 |
  | `peyote` | Peyote | XG417 |
  | `deviant` | Deviant | Cerberus Harrier |
  | `lilwill` | Little Willy | Calvin.linardi |
  | `torrat` | Rat Rod | Stella |
  | `sentinb` | Sentinel Classic | tigerlim |
  | `hercules` | Hercules | Calvin.linardi |
  | `hotrind` | Hotring Dukes | not in the pack's authors list |
  | `blistab` | Blista | Helomyname |
  | `asbo` | Asbo | Onik |
  | `nrgdrag` | NRG-DRAG600 | DirtyImpala |
  | `bellevue` | Bellevue | DirtyImpala |
  | `seraph` | Seraph XS | joepesci69 |
  | `velox` | Velox | DirtyImpala |
  | `ironbolt` | Ironbolt GTP | Crack Yo' Neck |
  | `dr1` | DR1 | StarGTS |
  | `monroe` | Monroe | DirtyImpala |
  | `ztype` | Z-Type | QuanAnhGaming, Techno G. PH, ssolar (solair) |
  | `phobos` | Phobos VT | BenefactorSchysterCo |
  | `vincexs` | Vincent XS | joepesci69 |
  | `cometsp` | Comet SP | joepesci69 |
  | `typ29` | Type 29 | Helomyname |
  | `z100xs` | Z-100 XS | Helomyname |
  | `shini` | Shinigami | Helomyname |
  | `shinobi` | Shinobi | Washek |
  | `asuka` | Asuka | QuanAnhGaming, ssolar (solair), DJ Atomika |
  | `eurocl` | Euros Classic | joepesci69 |
  | `lurani` | Lurani | direct |
  | `ghost` | Ghost V8 | Cerberus Harrier |
  | `rattler` | Rattler | Cerberus Harrier |
  | `magnus` | Magnus | XG417 |
  | `dienst` | Diensta | Colday Vss |
  | `rauberev` | Schrauber Evo | joepesci69 |
  | `papag` | Papagayo | Chloe |
  | `adder` | Adder | Calvin.linardi |
  | `akuma` | Akuma | StarGTS |
  | `samurai` | Samurai | StarGTS |
  | `pegar4` | R4 | StarGTS |
  | `p1001r` | 1001R | StarGTS |
  | `natter` | Natter | Colday Vss |
  | `garcia` | Garcia | Colday Vss |
  | `eleganc` | Elegant Classic | TecnhoPH (listed as "Elegant Classic (& Stretch)") |
  | `eleglim` | Elegant Stretch | TecnhoPH (listed as "Elegant Classic (& Stretch)") |
  | `domgtc` | Dominator GTC | Mit_subi92 |
  | `berserka` | Berserker | Calvin.linardi |
  | `odin` | Odin | Calvin.linardi |
  | `valger` | Valger | MrFinger |
  | `dune` | Dunemaster | TheGhostWheels12 |
  | `abydos` | Abydos | XG417 |
  | `signori` | Signori | Chloe |
  | `zinger` | Zinger | Calvin.linardi |
  | `ludend` | Ludendorff | tigerlim |
  | `stomper` | Stomper | tigerlim |
  | `sadlxl` | Sadler XL | jim_1989 |
  | `darling` | Darlington | direct |
  | `marylan` | Maryland | direct |
  | `faria` | Faria | direct (listed as "Faria (& Beater)") |
  | `farshit` | Faria Beater | direct (listed as "Faria (& Beater)") |
  | `marion` | Marion | direct |
  | `mananb` | Manana Classic | direct |
  | `communr` | Communisator | Qwerty Van Hallen |
  | `oxford` | Oxford | DirtyImpala |
  | `retinue` | Retinue | Cerberus Harrier |
  | `stretchb` | Stafford Stretch | XG417 |
  | `silvdart` | Silver Dart | Crack Yo' Neck |
  | `insur` | Insurrection | not in the pack's authors list |
  | `stardst` | Stardust GT | StarGTS |
  | `marina` | Marina | TheMadeMan |
  | `gct` | GCT | joepesci69 |
  | `spectr` | Spectre | TecnhoPH |
  | `calico` | Calico | Tepig |

### Flame Infernus v4.0

- **Authors:** original model and textures by Silver3o5; edited model and new textures by FunGt
  (readme). Source: gta-modding.com (readme), a local copy (`gtaref/vehicle skins/131_flame_infernus4`).
- **License:** none stated ("You can edit this Infernus as you want").
- **In the project:** `vana-cars/mods/flame_infernus/`: `infernfl.dff` (the "DFF primary color"
  version: stripes take the primary colour), `infernfl.txd`, the readme. A model of its own; the
  vanilla Infernus is untouched.

### Big Boy's Toys monster truck

- **Author:** not given (readme, from gta-modding.it). Source: a local copy (`gtaref/vehicle skins/124_bad_boy_toys_monster_truck`).
- **License:** none stated.
- **In the project:** `vana-cars/mods/bigboys_monster/`: `monstbbt.txd` (the mod's `monsterb.txd`),
  on a model of its own built on the vanilla Monster (557); the readmes.
