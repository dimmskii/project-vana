#!/usr/bin/env python3
"""Seeds vana-activities' minigame spots from retail map data.

Reads (never executes) the text IPLs and the binary IPLs in models/gta3.img and models/gta_int.img,
and writes vana-activities/config/minigames.lua: every placed object vanilla attaches a minigame brain
to (slot machines, video poker, roulette and blackjack tables, the wheel of fortune, betting machines,
arcade machines and consoles, basketball hoops, pool tables), with its interior, position and heading.
Ours afterwards: edit freely.

usage: seed_minigames.py <GTA San Andreas dir> <vana-activities/config dir>
"""
import math
import os
import struct
import sys

GTA, OUT = sys.argv[1], sys.argv[2]
KINDS = {
    "kb_bandit_u": "slots", "neil_slot": "videopoker", "cj_slot_bank": "videopoker", "roulette_tbl": "roulette",
    "blck_jack": "blackjack", "wheel_o_fortune": "wheel", "otb_machine": "betting",
    "cj_coin_op": "arcade", "cj_coin_op_1": "arcade", "cj_coin_op_2": "arcade", "cj_coin_op_3": "arcade",
    "swank_console": "console", "snesish": "console", "low_console": "console",
    "bskball_lax": "hoop", "bskballhub_lax01": "hoop", "vgsxrefbballnet": "hoop", "vgsxrefbballnet2": "hoop",
    "k_pooltablesm": "pool",
}

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

spots, seen = [], set()


def add(model, interior, x, y, z, qz, qw):
    kind = KINDS.get(model)
    key = (model, round(x, 1), round(y, 1), round(z, 1))
    if kind and key not in seen:
        seen.add(key)
        heading = -math.degrees(2 * math.atan2(qz, qw)) % 360
        spots.append((kind, model, interior, x, y, z, heading))


for root, _, files in os.walk(os.path.join(GTA, "data", "maps")):
    for fn in files:
        if not fn.lower().endswith(".ipl"):
            continue
        section = None
        for line in open(os.path.join(root, fn), encoding="latin-1"):
            l = line.split("#")[0].strip()
            if l.lower() == "inst":
                section = "inst"
            elif l.lower() == "end":
                section = None
            elif section and l:
                f = [x.strip() for x in l.split(",")]
                if len(f) >= 10:
                    add(f[1].lower(), int(f[2]) & 0xFF, float(f[3]), float(f[4]), float(f[5]), float(f[8]), float(f[9]))

for archive in ("gta3.img", "gta_int.img"):
    with open(os.path.join(GTA, "models", archive), "rb") as img:
        _, count = struct.unpack("<4sI", img.read(8))
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
                add(names.get(model, ""), interior & 0xFF, x, y, z, qz, qw)

os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, "minigames.lua"), "w") as f:
    f.write("-- Seeded by tools/seed/seed_minigames.py from the map IPLs and gta3.img/gta_int.img. Edit freely: this file is ours now.\n")
    f.write("-- Minigame objects (vanilla attaches a script brain to each): kind, model, interior, position, heading.\n")
    f.write("MinigameSpots = {\n")
    for kind, model, interior, x, y, z, h in sorted(spots):
        f.write('    { kind = "%s", model = "%s", interior = %d, x = %.2f, y = %.2f, z = %.2f, heading = %.0f },\n' % (kind, model, interior, x, y, z, h))
    f.write("}\n")
counts = {}
for s in spots:
    counts[s[0]] = counts.get(s[0], 0) + 1
print("minigames: %d %s" % (len(spots), counts))
