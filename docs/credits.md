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
