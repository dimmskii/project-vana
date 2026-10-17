#!/usr/bin/env python3
"""Seeds vana-parked's editable car generator list from retail game data.

Reads (never executes):
  - models/gta3.img: the binary streaming IPLs' parked car sections (CFileCarGenerator, 48 bytes)
  - data/script/main.txt (decompiled main.scm): create_car_generator / _with_plate calls

The generated config/cargens.lua is ours afterwards: edit freely (toggle `enabled`, change models).

usage: seed_cargens.py <GTA San Andreas dir> <vana-parked/config dir>
"""
import math
import os
import re
import struct
import sys

GTA, OUT = sys.argv[1], sys.argv[2]
IMG = os.path.join(GTA, "models", "gta3.img")
MAIN = os.path.join(GTA, "data", "script", "main.txt")

gens = []

# --- binary IPLs in gta3.img (VER2: 8-byte header, 32-byte directory entries, 2048-byte sectors) ----
with open(IMG, "rb") as f:
    magic, count = struct.unpack("<4sI", f.read(8))
    assert magic == b"VER2"
    directory = f.read(32 * count)
    for i in range(count):
        offset, streaming, size = struct.unpack_from("<IHH", directory, 32 * i)
        name = directory[32 * i + 8:32 * i + 32].split(b"\0")[0].decode("latin-1")
        if not name.lower().endswith(".ipl"):
            continue
        f.seek(offset * 2048)
        data = f.read((size or streaming) * 2048)
        if data[:4] != b"bnry":
            continue
        counts = struct.unpack_from("<6i", data, 4)
        offsets = struct.unpack_from("<12i", data, 28)
        cars, at = counts[4], offsets[8]
        for c in range(cars):
            x, y, z, heading, model, prim, sec, flags, alarm, lock, mn, mx = struct.unpack_from("<4f8i", data, at + 48 * c)
            # IPL headings are radians; script ones (and our config) are degrees.
            gens.append({"x": x, "y": y, "z": z, "heading": math.degrees(heading), "model": model, "colors": (prim, sec),
                         "force": bool(flags & 1), "ignoreLimit": bool(flags & 2), "alarm": alarm, "lock": lock,
                         "delay": (mn, mx), "source": name.lower()})

# --- main.scm script generators --------------------------------------------------------------------
pattern = re.compile(
    r"^\s*(\$[\w\[\]]+) = create_car_generator(?:_with_plate)? ([-\d.]+) \{y\} ([-\d.]+) \{z\} ([-\d.]+) \{heading\} ([-\d.]+) "
    r"\{modelId\} (-?\d+) \{primaryColor\} (-?\d+) \{secondaryColor\} (-?\d+) \{forceSpawn\} (\w+) \{alarmChance\} (\d+) "
    r"\{doorLockChance\} (\d+) \{minDelay\} (\d+) \{maxDelay\} (\d+)")
seen = set()
for line in open(MAIN, encoding="latin-1"):
    m = pattern.match(line)
    if not m:
        continue
    var, x, y, z = m[1], float(m[2]), float(m[3]), float(m[4])
    if x == 0 and y == 0:
        continue  # placeholders whose position a mission sets later (import/export)
    key = (var, round(x), round(y))
    if key in seen:
        continue
    seen.add(key)
    gens.append({"x": x, "y": y, "z": z, "heading": float(m[5]), "model": int(m[6]), "colors": (int(m[7]), int(m[8])),
                 "force": m[9] == "True", "ignoreLimit": False, "alarm": int(m[10]), "lock": int(m[11]),
                 "delay": (int(m[12]), int(m[13])), "source": "main.scm " + var})

# The script sometimes keeps two generators at one spot (e.g. a girlfriend's car locked and unlocked);
# one parked car per spot and model.
unique, positions = [], set()
for g in gens:
    key = (round(g["x"]), round(g["y"]), round(g["z"]), g["model"])
    if key not in positions:
        positions.add(key)
        unique.append(g)
gens = unique

os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, "cargens.lua"), "w") as f:
    f.write("-- Seeded by tools/seed/seed_cargens.py from retail game data. Edit freely: this file is ours now.\n")
    f.write("-- Parked car generators: the streaming IPLs in gta3.img, then main.scm's script generators (rewards,\n")
    f.write("-- airport aircraft, garages...), all enabled: open-world content is always available.\n")
    f.write("-- model -1: a car suited to the zone, chosen on first spawn and kept. colors -1: random.\n")
    f.write("-- force: spawns regardless of the parked-car limit. alarm/lock: percent chances. delay: respawn ms range.\n")
    f.write("CarGenerators = {\n")
    for g in gens:
        f.write('    { x = %.2f, y = %.2f, z = %.2f, heading = %.1f, model = %d, colors = { %d, %d }, force = %s, ignoreLimit = %s, '
                'alarm = %d, lock = %d, delay = { %d, %d }, enabled = true, source = "%s" },\n'
                % (g["x"], g["y"], g["z"], g["heading"], g["model"], g["colors"][0], g["colors"][1],
                   str(g["force"]).lower(), str(g["ignoreLimit"]).lower(), g["alarm"], g["lock"],
                   g["delay"][0], g["delay"][1], g["source"]))
    f.write("}\n")

ipl = sum(1 for g in gens if not g["source"].startswith("main.scm"))
print("car generators: %d from IPLs, %d from main.scm" % (ipl, len(gens) - ipl))
