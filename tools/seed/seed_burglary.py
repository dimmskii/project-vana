#!/usr/bin/env python3
"""Seeds vana-activities' burglary houses and doors from retail map data.

Reads (never executes) the text IPLs' enex sections, the models in models/gta3.img (their "enex" 2DFX
effects: most house doors live there, not in the IPLs) and the IPL placements of those models, and
writes vana-activities/config/burglary_houses.lua:

- BurglaryHouses: each furnished house interior the doors lead to (its hub entry: interior, trigger
  position and where you arrive inside).
- BurglaryDoors: every door with the burglary-access flag (0x1000), with the house it leads to and
  where you come back out. Ours afterwards: edit freely.

usage: seed_burglary.py <GTA San Andreas dir> <vana-activities/config dir>
"""
import math
import os
import struct
import sys

GTA, OUT = sys.argv[1], sys.argv[2]
BURGLARY = 0x1000


def img_entries(path):
    with open(path, "rb") as img:
        _, count = struct.unpack("<4sI", img.read(8))
        directory = img.read(32 * count)
        for i in range(count):
            offset, streaming, size = struct.unpack_from("<IHH", directory, 32 * i)
            name = directory[32 * i + 8:32 * i + 32].split(b"\0")[0].decode("latin-1").lower()
            img.seek(offset * 2048)
            yield name, img.read((size or streaming) * 2048)


def text_sections(section):
    for root, _, files in os.walk(os.path.join(GTA, "data", "maps")):
        for fn in sorted(files):
            if not fn.lower().endswith(".ipl"):
                continue
            current = None
            for line in open(os.path.join(root, fn), encoding="latin-1"):
                l = line.split("#")[0].strip()
                if l.lower() == section:
                    current = section
                elif l.lower() == "end":
                    current = None
                elif current and l:
                    yield [x.strip() for x in l.split(",")]


# Model names from the IDEs.
names = {}
for root, _, files in os.walk(os.path.join(GTA, "data", "maps")):
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

# IPL enex: x, y, z, angle, sizeX, sizeY, 8, exitX, exitY, exitZ, exitAngle, interior, flags, "name", ...
hubs, doors = {}, []
for f in text_sections("enex"):
    x, y, z, ex, ey, ez, ea = (float(f[i]) for i in (0, 1, 2, 7, 8, 9, 10))
    interior, flags, name = int(f[11]), int(f[12]), f[13].strip('"').strip()
    if interior != 0:
        hubs.setdefault(name, (interior, x, y, z, ex, ey, ez, ea % 360))
    elif flags & BURGLARY:
        doors.append((name, x, y, z, ex, ey, ez, ea % 360, "ipl"))

# 2DFX enex in the models (type 6, 44 bytes): enter angle, size x/y, exit offset, exit angle,
# interior, flags, name[8], hours, flags2.
effects = {}
for name, data in img_entries(os.path.join(GTA, "models", "gta3.img")):
    if not name.endswith(".dff"):
        continue
    p = 0
    while (p := data.find(struct.pack("<I", 0x253F2F8), p)) >= 0:
        size = struct.unpack_from("<I", data, p + 4)[0]
        body = data[p + 12:p + 12 + size]
        if len(body) >= 4:
            q = 4
            for _ in range(min(struct.unpack_from("<I", body, 0)[0], 200)):
                if q + 20 > len(body):
                    break
                x, y, z, kind, dsize = struct.unpack_from("<3fII", body, q)
                if kind == 6 and dsize == 44:
                    e = body[q + 20:q + 64]
                    _, _, _, ex, ey, ez, ea = struct.unpack_from("<7f", e, 0)
                    flags = e[30] | (e[42] << 8)
                    target = e[32:40].split(b"\0")[0].decode("latin-1").strip()
                    if flags & BURGLARY:
                        effects.setdefault(name[:-4], []).append((x, y, z, ex, ey, ez, ea, target))
                q += 20 + dsize
        p += 4

# Placements: text IPL inst lines and the binary IPLs in gta3.img.
placements = []
for f in text_sections("inst"):
    if len(f) >= 10:
        placements.append((f[1].lower(), *map(float, f[3:10])))
for name, data in img_entries(os.path.join(GTA, "models", "gta3.img")):
    if name.endswith(".ipl") and data[:4] == b"bnry":
        n, at = struct.unpack_from("<i", data, 4)[0], struct.unpack_from("<i", data, 28)[0]
        for k in range(n):
            x, y, z, qx, qy, qz, qw, model, _, _ = struct.unpack_from("<7f3i", data, at + 40 * k)
            placements.append((names.get(model, ""), x, y, z, qx, qy, qz, qw))

for model, x, y, z, qx, qy, qz, qw in placements:
    for fx, fy, fz, ex, ey, ez, ea, target in effects.get(model, []):
        h = -2 * math.atan2(qz, qw)  # IPL rotations are the inverse quaternion: this is the yaw
        c, s = math.cos(h), math.sin(h)
        doors.append((target, x + fx * c - fy * s, y + fx * s + fy * c, z + fz,
                      x + (fx + ex) * c - (fy + ey) * s, y + (fx + ex) * s + (fy + ey) * c, z + fz + ez,
                      (math.degrees(h) + ea) % 360, model))

known = [d for d in doors if d[0] in hubs]
dropped = sorted({d[0] for d in doors if d[0] not in hubs})
used = sorted({d[0] for d in known})

os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, "burglary_houses.lua"), "w") as out:
    out.write("-- Seeded by tools/seed/seed_burglary.py from the map IPLs and gta3.img. Edit freely: this file is ours now.\n")
    out.write("-- Houses: the furnished interiors burglary doors lead to (hub: interior, trigger x/y/z, arrival ex/ey/ez).\n")
    out.write("BurglaryHouses = {\n")
    for name in used:
        i, x, y, z, ex, ey, ez, ea = hubs[name]
        out.write('    %-7s = { interior = %d, x = %.2f, y = %.2f, z = %.2f, ex = %.2f, ey = %.2f, ez = %.2f, heading = %.0f },\n'
                  % (name, i, x, y, z, ex, ey, ez, ea))
    out.write("}\n\n")
    out.write("-- Doors with the burglary-access flag: trigger x/y/z, where you come back out (ex/ey/ez, heading), and\n")
    out.write("-- the house behind them. source: the IPL enex, or the house model whose 2DFX holds the door.\n")
    out.write("BurglaryDoors = {\n")
    for target, x, y, z, ex, ey, ez, ea, src in sorted(known, key=lambda d: (d[0], round(d[1]), round(d[2]))):
        out.write('    { house = "%s", x = %.2f, y = %.2f, z = %.2f, ex = %.2f, ey = %.2f, ez = %.2f, heading = %.0f }, -- %s\n'
                  % (target, x, y, z, ex, ey, ez, ea, src))
    out.write("}\n")
print("burglary: %d houses, %d doors (%d dropped: no interior named %s)"
      % (len(used), len(known), len(doors) - len(known), ", ".join(dropped)))
