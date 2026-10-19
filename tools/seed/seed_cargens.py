#!/usr/bin/env python3
"""Seeds vana-parked's editable car generator list from retail game data.

Reads (never executes) models/gta3.img: the binary streaming IPLs' parked car sections
(CFileCarGenerator, 48 bytes). The script generators (main.scm's create_car_generator calls) were
extracted once into cargens_script.lua, which is canonical and never regenerated.

The generated config/cargens.lua is ours afterwards: edit freely (toggle `enabled`, change models).

usage: seed_cargens.py <GTA San Andreas dir> <vana-parked/config dir>
"""
import math
import os
import struct
import sys

GTA, OUT = sys.argv[1], sys.argv[2]
IMG = os.path.join(GTA, "models", "gta3.img")

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

# One parked car per spot and model.
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
    f.write("-- Parked car generators from the streaming IPLs in gta3.img, all enabled (script generators: cargens_script.lua).\n")
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

print("car generators: %d from IPLs" % len(gens))
