#!/usr/bin/env python3
"""Seeds vana-player's hospital and police restart points from the decompiled main.scm
(add_hospital_restart / add_police_restart). Story gating (citiesPassed) is dropped: every city
is always open. The generated config/restarts.lua is ours afterwards: edit freely.

usage: seed_restarts.py <GTA San Andreas dir> <vana-player/config dir>
"""
import os
import re
import sys

GTA, OUT = sys.argv[1], sys.argv[2]
pattern = re.compile(r"^\s*add_(hospital|police)_restart ([-\d.]+) \{y\} ([-\d.]+) \{z\} ([-\d.]+) \{heading\} ([-\d.]+)")
points = {"hospital": [], "police": []}
for line in open(os.path.join(GTA, "data", "script", "main.txt"), encoding="latin-1"):
    m = pattern.match(line)
    if m:
        points[m[1]].append((float(m[2]), float(m[3]), float(m[4]), float(m[5])))

os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, "restarts.lua"), "w") as f:
    f.write("-- Seeded by tools/seed/seed_restarts.py from main.scm. Edit freely: this file is ours now.\n")
    f.write("-- Where players come back after being wasted (hospitals) or busted (police stations): the nearest one.\n")
    f.write("Restarts = {\n")
    for kind in ("hospital", "police"):
        f.write("    %s = {\n" % kind)
        for x, y, z, h in points[kind]:
            f.write("        { x = %.2f, y = %.2f, z = %.2f, heading = %.1f },\n" % (x, y, z, h))
        f.write("    },\n")
    f.write("}\n")
print("restarts: %d hospitals, %d police stations" % (len(points["hospital"]), len(points["police"])))
