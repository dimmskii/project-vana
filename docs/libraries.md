# Shared code (`vana-lib`) and game text (`vana-text`)

## Importing from `vana-lib`

MTA loads scripts only from inside a resource and has no code import, so shared code lives once in
`vana-lib/lib/` and is imported at runtime (the pattern big MTA libraries like DGS use):
`vana-lib` exports `import(name)`, which returns a module's source, and the importing resource runs
it in its own Lua state. It behaves exactly like a local copy: no per-call cost, its globals (`SA`,
`Gxt`, `MapData`...) live in the importer.

- **How:** a resource's `lib.lua`, listed first in its `meta.xml`, names the modules it imports on
  each side (`localPlayer and { client modules } or { server modules }`).
- **Start order:** `vana-lib` starts first (top of the startup list in `mtaserver.conf`). Restarting
  it reaches importers only when they restart. Never restart `vana-lib` alone on a running server: a
  player joining later gets resources started in the order the server last started them, so every
  importer would start before `vana-lib` on their client, fail its imports (`SATxd`, `MenuInput`,
  map data all nil) and break (no garage icons, menus, vendors). Restart everything in order instead:
  `tools/srv.sh restartall`.
- **ACL:** `loadstring` is restricted on the server, so each resource importing on the server asks
  for it (`<aclrequest>` in its meta); approve once from the console (see [setup.md](setup.md)).
  Clients aren't restricted (`vana-lib` serves the module files to them).
- **Lint:** `tools/lint.sh` reads each `lib.lua` and counts the imported modules' globals as defined.
- **Offline tools** (`tools/convert/`) load the same files with `dofile("vana-lib/lib/...")`; the
  game-file modules run in plain Lua 5.1 too.

### Modules

| Module | What | Imported by |
| --- | --- | --- |
| `sa_reader` (`SA`) | Little-endian integers and floats, fixed strings, bit operations; text lines, comments (`#`, `//`), fields (commas count as whitespace) | the `sa_*` importers |
| `sa_gxt` (`Gxt`) | `american.gxt`: every table (MAIN and the mission tables), lazily; `raw` keeps formatting tokens, `get` strips colour tokens, `format` fills `~1~` | vana-text |
| `sa_ide` (`SAIde`) | `.ide` sections as rows of fields; id and name indexes | vana-population |
| `sa_dat` (`SADat`) | Line-based data: plain rows (`pedgrp`/`cargrp`/`pedstats`), `popcycle.dat` sections, `.zon` boxes, `section ... end` nesting (`shopping.dat`) | vana-population, vana-shops |
| `sa_txd` (`SATxd`) | RenderWare `.txd` (PC, D3D8/D3D9) to DDS data for `dxCreateTexture`: DXT1/3/5 copied, 32/16-bit with their masks, paletted expanded | vana-vehicles (client: dashboards), vana-shops (client: marker icons), vana-map (client: radar tiles, blip sprites) |
| `map_data` (`MapData`) | Placement data in map resources: element schemas, records, `At` / `Spots` | the owners of `[data]/vana-data-*` |
| `map_points` (`MapPoints`) | Publishing radar points to vana-map | vana-interiors, vana-activities |
| `prompts` (`Prompts`) | On-foot markers that start something on `/use` ("Press F to ..."), or at once with `walkIn`; offers to vana-controls' /use; the server checks you're still on it | vana-shops, vana-gym, vana-activities |
| `actions` (`Actions`) | Actions: what a player does to something, as a command (server); the exports vana-controls collects ([controls.md](controls.md)) | vana-controls, vana-vehicles, vana-shops |
| `menu_input` (`MenuInput`) | One way through every menu: keys, pad, mouse (client) | vana-controls, vana-shops, vana-activities |
| `menu_list` (`MenuList`) | A list menu in our style: headings the selection skips, choices changed in place, keys/pad/mouse and the scroll fix (client; needs `menu_input`) | vana-controls (preferences) |
| `debug` (`Debug`) | Debug switches: `Debug.on(topic)`, `Debug.log(topic, text)` to the server log from either side ([debug.md](debug.md)) | vana-controls, vana-core, vana-peds, vana-traffic |
| `text` (`Gxt`) | The game's text, answered by `vana-text` | vana-shops, vana-activities |

When these replaced each resource's own readers, the old and new readers were run side by side on the
retail files and gave identical results.

### Still copied

`edf_lines_client.lua` (Map Editor lines for paths, links and exit points): the editor runs EDF
scripts from the defining resource's own folder, so `tools/sync-libs.sh` copies it into
`vana-interiors`, `vana-activities` and `vana-wildlife`; the lint fails if a copy differs.

## Game text (`vana-text`)

`vana-text` owns `data/american.gxt` (copied from your install, see [setup.md](setup.md)), reads it
once with `sa_gxt`, and answers every other resource through its exports (`isReady`, `rawText`,
`plainText`); importers of `text` get the usual `Gxt.raw` / `Gxt.get` / `Gxt.format` / `Gxt.load`
over them. Server-side only (clients get text from their resource's server).

The path graph (`NODES*.DAT`) is still read by vana-paths' own `paths_format.lua`; it moves to
`vana-lib` if another resource ever needs it. Map placements (IPL) aren't read at runtime at all.
