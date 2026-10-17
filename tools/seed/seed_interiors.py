#!/usr/bin/env python3
"""Seeds vana-interiors' entrances and vana-shops' counter points from retail map data.

Reads (never executes):
  - data/maps/**/*.ipl: the "enex" sections (entry/exit markers, 376 lines)
  - data/maps/**/*.ide + models/gta_int.img: interior object placements, to find shop counters

Writes, ours afterwards (edit freely):
  - vana-interiors/config/entrances.lua
  - vana-shops/config/points.lua: where a customer stands to shop, per shop interior. Found from a
    counter/till object near the shop's inside door; otherwise a few metres inside the door. Refine
    in game with /shoppoint.

usage: seed_interiors.py <GTA San Andreas dir> <vana-interiors/config> <vana-shops/config>
"""
import math
import os
import struct
import sys

GTA, OUT_INTERIORS, OUT_SHOPS = sys.argv[1], sys.argv[2], sys.argv[3]
MAPS = os.path.join(GTA, "data", "maps")

# --- enex ------------------------------------------------------------------------------------------
entrances, seen = [], set()
for root, _, files in os.walk(MAPS):
    for fn in sorted(files):
        if not fn.lower().endswith(".ipl"):
            continue
        section = None
        for line in open(os.path.join(root, fn), encoding="latin-1"):
            l = line.split("#")[0].strip()
            if not l:
                continue
            if l.lower() in ("enex", "inst", "cull", "pick", "path", "occl", "mult", "grge", "cars", "jump", "tcyc", "auzo"):
                section = l.lower()
                continue
            if l.lower() == "end":
                section = None
                continue
            if section != "enex":
                continue
            f = [x.strip() for x in l.split(",")]
            name = f[13].strip('"').upper()
            if not name:
                continue
            e = {"name": name, "x": float(f[0]), "y": float(f[1]), "z": float(f[2]), "angle": math.degrees(float(f[3])),
                 "sx": float(f[4]), "sy": float(f[5]), "ex": float(f[7]), "ey": float(f[8]), "ez": float(f[9]),
                 "heading": float(f[10]) % 360, "interior": int(float(f[11])), "flags": int(f[12]),
                 "open": int(f[16]), "close": int(f[17])}
            key = (name, round(e["x"], 1), round(e["y"], 1), round(e["z"], 1))
            if key in seen:
                continue
            seen.add(key)
            entrances.append(e)

# --- interior objects (gta_int.img binary IPLs), for shop counters ---------------------------------
names = {}
for root, _, files in os.walk(MAPS):
    for fn in files:
        if fn.lower().endswith(".ide"):
            section = None
            for line in open(os.path.join(root, fn), encoding="latin-1"):
                l = line.split("#")[0].strip()
                if l in ("objs", "tobj", "anim"):
                    section = l
                elif l == "end":
                    section = None
                elif section and l:
                    f = [x.strip() for x in l.split(",")]
                    if f[0].isdigit():
                        names[int(f[0])] = f[1].lower()
objects = []
with open(os.path.join(GTA, "models", "gta_int.img"), "rb") as img:
    magic, count = struct.unpack("<4sI", img.read(8))
    directory = img.read(32 * count)
    for i in range(count):
        offset, streaming, size = struct.unpack_from("<IHH", directory, 32 * i)
        fname = directory[32 * i + 8:32 * i + 32].split(b"\0")[0].decode("latin-1")
        if not fname.lower().endswith(".ipl"):
            continue
        img.seek(offset * 2048)
        data = img.read((size or streaming) * 2048)
        if data[:4] != b"bnry":
            continue
        n, at = struct.unpack_from("<i", data, 4)[0], struct.unpack_from("<i", data, 28)[0]
        for k in range(n):
            x, y, z, _, _, _, _, model, interior, _ = struct.unpack_from("<7f3i", data, at + 40 * k)
            objects.append((names.get(model, ""), x, y, z, interior & 0xFF))

SHOPS = {
    "weapons": ["AMMUN1", "AMMUN2", "AMMUN3", "AMMUN4", "AMMUN5"],
    "food": ["FDCHICK", "FDPIZA", "FDBURG"],
    "clothes": ["CSCHP", "CSSPRT", "LACS1", "CLOTHGP", "CSDESGN", "CSEXL"],
    "misc": ["X7_11B", "X7_11C", "X7_11D", "X7_11S", "X711S2", "X711S3"],
}
COUNTERS = {
    "weapons": ("gun_counter", "mpgun_counter"),
    "food": ("cj_ff_till",),
    "clothes": ("cj_urb_counter", "gap_counter", "shop_counter", "counterb"),
    "misc": ("shop_counter", "counterb"),
}

points = []
for kind, shop_names in SHOPS.items():
    for name in shop_names:
        inside = [e for e in entrances if e["name"] == name and e["interior"] != 0]
        if not inside:
            continue
        door = inside[0]
        candidates = [o for o in objects if o[4] == door["interior"] and o[0].startswith(COUNTERS[kind])
                      and math.dist((o[1], o[2], o[3]), (door["x"], door["y"], door["z"])) < 40]
        # Into the room: from the inside trigger toward where the door puts the player.
        ix, iy = door["ex"] - door["x"], door["ey"] - door["y"]
        il = math.hypot(ix, iy) or 1
        ix, iy = ix / il, iy / il
        if candidates:
            c = min(candidates, key=lambda o: math.dist((o[1], o[2]), (door["x"], door["y"])))
            dx, dy = door["x"] - c[1], door["y"] - c[2]
            dl = math.hypot(dx, dy) or 1
            px, py, pz, how = c[1] + dx / dl * 1.4, c[2] + dy / dl * 1.4, door["ez"], "counter " + c[0]
        else:
            px, py, pz, how = door["ex"] + ix * 4, door["ey"] + iy * 4, door["ez"], "4 m inside the door (no counter found)"
        points.append((name, kind, door["interior"], px, py, pz, how))

os.makedirs(OUT_INTERIORS, exist_ok=True)
with open(os.path.join(OUT_INTERIORS, "entrances.lua"), "w") as f:
    f.write("-- Seeded by tools/seed/seed_interiors.py from the map IPLs' enex sections. Edit freely: this file is ours now.\n")
    f.write("-- Each entry is one marker: stepping into it takes you to a same-named entry in another area, placed at\n")
    f.write("-- that entry's exit point (ex, ey, ez, heading). interior: the area the marker is in. open/close: hours.\n")
    f.write("-- size: the IPL's full trigger widths. Set enabled = false to close an entrance.\n")
    f.write("-- flags bit 4 (\"create linked pair\"): a door, leading to the same-named entry without it (the hub);\n")
    f.write("-- a hub leads back to the door the player came through (e.g. every safehouse closet shares one room).\n")
    f.write("Entrances = {\n")
    for e in entrances:
        f.write('    { name = "%s", x = %.3f, y = %.3f, z = %.3f, size = { %.2f, %.2f }, ex = %.3f, ey = %.3f, ez = %.3f, heading = %.1f, '
                'interior = %d, flags = %d, open = %d, close = %d, enabled = true },\n'
                % (e["name"], e["x"], e["y"], e["z"], e["sx"], e["sy"], e["ex"], e["ey"], e["ez"], e["heading"], e["interior"], e["flags"], e["open"], e["close"]))
    f.write("}\n")

os.makedirs(OUT_SHOPS, exist_ok=True)
with open(os.path.join(OUT_SHOPS, "points.lua"), "w") as f:
    f.write("-- Seeded by tools/seed/seed_interiors.py. Edit freely: this file is ours now.\n")
    f.write("-- Where a customer stands to shop, per shop interior (enex name). Found from a counter object where the\n")
    f.write("-- interior has one, else a few metres inside the door. Refine in game with /shoppoint <name>.\n")
    f.write("ShopPoints = {\n")
    for name, kind, interior, x, y, z, how in points:
        f.write('    %-10s = { kind = "%s", interior = %d, x = %.2f, y = %.2f, z = %.2f }, -- %s\n'
                % (name, kind, interior, x, y, z, how))
    f.write("}\n")

found = sum(1 for p in points if p[6].startswith("counter"))
print("entrances %d (%d names); shop points %d (%d from counters)" % (len(entrances), len({e['name'] for e in entrances}), len(points), found))
