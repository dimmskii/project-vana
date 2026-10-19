#!/usr/bin/env python3
"""Seeds vana-shops' mod garage facts from the retail data files (read, never executed):

  - data/maps/veh_mods/veh_mods.ide: each vehicle upgrade's model ID by name (as shopping.dat names
    them: the mod garages' stock and prices are read from shopping.dat at runtime)
  - data/carcols.dat: the car colour palette (RGB of colours 0-126), for the garages' colour menus

Writes vana-shops/config/carmods_data.lua: facts only (IDs, colours).

usage: seed_carmods.py <GTA San Andreas dir> <vana-shops/config dir>
"""
import os
import re
import sys

GTA, OUT = sys.argv[1], sys.argv[2]

ids = {}
for line in open(os.path.join(GTA, "data", "maps", "veh_mods", "veh_mods.ide"), errors="ignore"):
    m = re.match(r"\s*(\d+),\s*(\w+),", line)
    if m and 1000 <= int(m.group(1)) <= 1193:
        ids[m.group(2).lower()] = int(m.group(1))

palette, section = [], None
for line in open(os.path.join(GTA, "data", "carcols.dat"), errors="ignore"):
    body = line.split("#")[0].strip()
    if body in ("col", "car", "car4", "end"):
        section = body if body != "end" else None
        continue
    if section == "col" and body:
        # Colour 98 is written "77.93,96" in the retail file: a dot for a comma.
        r, g, b = (int(v) for v in re.split(r"[,.\s]+", body)[:3])
        palette.append((r, g, b))
assert len(ids) == 194 and len(palette) == 127, (len(ids), len(palette))

os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, "carmods_data.lua"), "w") as f:
    f.write("-- Origin: veh_mods.ide and carcols.dat via tools/seed/seed_carmods.py; rerunning it overwrites edits.\n")
    f.write("-- Vehicle upgrades' model IDs by name (shopping.dat's names).\n")
    f.write("CarModIds = {\n")
    for i, (name, mid) in enumerate(sorted(ids.items(), key=lambda kv: kv[1])):
        f.write("    %s = %d,\n" % (name, mid))
    f.write("}\n")
    f.write("-- The car colour palette: colour N is entry N + 1, { r, g, b }.\n")
    f.write("CarPalette = {\n")
    for i in range(0, len(palette), 8):
        f.write("    " + " ".join("{ %d, %d, %d }," % c for c in palette[i:i + 8]) + "\n")
    f.write("}\n")
print("upgrades %d, colours %d" % (len(ids), len(palette)))
