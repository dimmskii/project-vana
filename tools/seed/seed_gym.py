#!/usr/bin/env python3
"""Seeds vana-gym's equipment list from retail interior data.

Reads (never executes) models/gta_int.img (binary IPL placements) and data/maps/**/*.ide (model
names), and writes vana-gym/config/equipment.lua: every gym bike, treadmill, bench press and
fight mat with its interior, position and heading. Ours afterwards: edit freely.

usage: seed_gym.py <GTA San Andreas dir> <vana-gym/config dir>
"""
import math
import os
import struct
import sys

GTA, OUT = sys.argv[1], sys.argv[2]
KINDS = {"gym_bike": "bike", "gym_treadmill": "treadmill", "gym_bench1": "bench", "gym_mat1": "mat"}

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

equipment = []
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
            x, y, z, qx, qy, qz, qw, model, interior, _ = struct.unpack_from("<7f3i", data, at + 40 * k)
            kind = KINDS.get(names.get(model, ""))
            if kind:
                # IPL rotations are stored as the inverse quaternion; this is the object's yaw in degrees.
                heading = -math.degrees(2 * math.atan2(qz, qw)) % 360
                equipment.append((kind, interior & 0xFF, x, y, z, heading))

os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, "equipment.lua"), "w") as f:
    f.write("-- Seeded by tools/seed/seed_gym.py from models/gta_int.img. Edit freely: this file is ours now.\n")
    f.write("-- Gym equipment: kind (bike, treadmill, bench, mat), interior, position and the object's heading.\n")
    f.write("GymEquipment = {\n")
    for kind, interior, x, y, z, heading in sorted(equipment):
        f.write('    { kind = "%s", interior = %d, x = %.3f, y = %.3f, z = %.3f, heading = %.1f },\n' % (kind, interior, x, y, z, heading))
    f.write("}\n")
print("gym equipment: %d (%s)" % (len(equipment), ", ".join("%s %d" % (k, sum(1 for e in equipment if e[0] == k)) for k in KINDS.values())))
