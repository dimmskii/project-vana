#!/usr/bin/env python3
"""Seeds vana-shops' spoiler fits from MTA Neon's upgrade table (read, never compiled):

  - Server/mods/deathmatch/logic/CVehicleUpgrades.cpp, CVehicleUpgrades::IsUpgradeCompatible: before
    its per-model switch it passes every spoiler on every car, so getVehicleCompatibleUpgrades never
    rules one out (bought, it doesn't show: the model has nowhere to put it). The switch itself still
    lists, per vanilla model, the spoilers that model takes (as carmods.dat does).

Writes vana-shops/config/spoilers_data.lua: the spoiler IDs, and each model's spoilers.

usage: seed_spoilers.py <CVehicleUpgrades.cpp> <vana-shops/config dir>
"""
import os
import re
import sys

SRC, OUT = sys.argv[1], sys.argv[2]
text = open(SRC, errors="ignore").read()

body = text[text.index("bool CVehicleUpgrades::IsUpgradeCompatible"):]
body = body[:body.index("\n}\n")]

# The blanket rule: the spoiler IDs it lets through.
blanket = re.search(r"if \((us == 1000 [^{]*?)\)\s*\{\s*return true;", body, re.S)
spoilers = sorted(int(n) for n in re.findall(r"us == (\d+)", blanket.group(1)))

# The switch: case labels (several may share one return), then the IDs their return names.
switch = body[body.index("switch (usModel)"):]
fits, pending = {}, []
for m in re.finditer(r"case (\d+):|return \((.*?)\);", switch, re.S):
    if m.group(1):
        pending.append(int(m.group(1)))
    else:
        ids = sorted({int(n) for n in re.findall(r"us == (\d+)", m.group(2))} & set(spoilers))
        for model in pending:
            fits[model] = ids
        pending = []
assert len(spoilers) == 20 and len(fits) > 60, (len(spoilers), len(fits))

os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, "spoilers_data.lua"), "w") as f:
    f.write("-- Origin: MTA Neon's CVehicleUpgrades.cpp via tools/seed/seed_spoilers.py; rerunning it overwrites edits.\n")
    f.write("-- Spoilers (getVehicleCompatibleUpgrades passes every one on every car): their IDs, and the ones\n")
    f.write("-- each vanilla model takes (a model not listed takes none).\n")
    f.write("CarSpoilerIds = { %s }\n" % ", ".join(str(n) for n in spoilers))
    f.write("CarSpoilers = {\n")
    for model in sorted(fits):
        if fits[model]:
            f.write("    [%d] = { %s },\n" % (model, ", ".join(str(n) for n in fits[model])))
    f.write("}\n")
print("spoilers %d, models %d (%d with spoilers)" % (len(spoilers), len(fits), sum(1 for v in fits.values() if v)))
