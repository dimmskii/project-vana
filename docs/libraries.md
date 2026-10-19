# Shared libraries (`tools/lib`)

MTA only loads scripts from inside a resource, so shared code lives once in `tools/lib/` and is
copied into the resources that use it by `tools/sync-libs.sh` (its list says which go where).
`tools/lint.sh` fails when a copy differs from its source: edit the source, then run the sync.

## Game files (retail GTA:SA formats)

All of these run in MTA and in plain Lua 5.1 (for tools and offline checks).

| Module | Reads | Used by |
| --- | --- | --- |
| `sa_reader.lua` (`SA`) | Little-endian integers and floats, fixed strings, bit operations; text lines, comments (`#`, `//`), fields (commas count as whitespace) | everything below |
| `sa_gxt.lua` (`Gxt`) | `american.gxt`: every table (MAIN and the mission tables), lazily. `raw` keeps formatting tokens, `get` strips colour tokens, `format` fills `~1~` | vana-shops, vana-activities |
| `sa_ide.lua` (`SAIde`) | `.ide` sections as rows of fields; id and name indexes | vana-population |
| `sa_dat.lua` (`SADat`) | Line-based data: plain rows (`pedgrp`/`cargrp`/`pedstats`), `popcycle.dat` sections, `.zon` boxes, `section ... end` nesting (`shopping.dat`) | vana-population, vana-shops |
| `sa_txd.lua` (`SATxd`) | RenderWare `.txd` (PC, D3D8/D3D9) to DDS data for `dxCreateTexture`: DXT1/3/5 copied, 32/16-bit with their masks, paletted expanded | vana-vehicles (dashboards) |

The path graph (`NODES*.DAT`) is still read by vana-paths' own `paths_format.lua`; it moves here if
another resource ever needs it. Map placements (IPL) aren't read at runtime at all: they live in map
resources (see [editor.md](editor.md)); only the seed scripts read IPLs, offline.

When these replaced each resource's own readers, the old and new readers were run side by side on
the retail files and gave identical results.

## MTA formats and helpers

| Module | What | Used by |
| --- | --- | --- |
| `map_data.lua` (`MapData`) | Placement data in map resources: element schemas, records, `At` / `Spots` | the owners of `[data]/vana-data-*` |
| `edf_lines_client.lua` | Map Editor lines for paths, links and exit points | the EDFs that link elements |
| `map_points.lua` (`MapPoints`) | Publishing radar points to vana-map | vana-interiors, vana-activities |
