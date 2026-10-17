#!/usr/bin/env python3
"""Seeds vana-activities' races from a decompiled main.scm (Sanny Builder text).

Reads (never executes) the CPRACE mission's race table: each race's checkpoints, racer count and
cars, laps, start position for the stadium races, and the race names' GXT keys, and writes
vana-activities/config/races.lua. Ours afterwards: edit freely.

usage: seed_races.py <main.scm decompiled text> <vana-activities/config dir>
"""
import os
import re
import sys

SRC, OUT = sys.argv[1], sys.argv[2]
lines = open(SRC, encoding="latin-1").read().split("\n")
start = next(i for i, l in enumerate(lines) if "switch_start $race_selection {numCases} 27" in l)
block = " ".join(lines[start:start + 6])
labels = re.findall(r"\{caseNum\d\} (\d+) \{caseLabel\d\} @(CPRACE_\d+)", block)
labels += re.findall(r"switch_continued (\d+) \{caseLabel1\} @(CPRACE_\d+)", block)
index = {l.strip()[1:]: i for i, l in enumerate(lines) if l.startswith(":CPRACE_")}

races = {}
for num, label in labels:
    i = index[label] + 1
    vals, ints = {}, {}
    while i < len(lines) and not lines[i].startswith("goto @CPRACE_46262") and not lines[i].startswith(":CPRACE"):
        l = lines[i]
        m = re.match(r"\s*(\d+)@ = (-?\d+(?:\.\d+)?)$", l)
        if m:
            vals[int(m.group(1))] = float(m.group(2))
        m = re.match(r"set_lvar_float_to_lvar_float (\d+)@ = (\d+)@", l)
        if m and int(m.group(2)) in vals:
            vals[int(m.group(1))] = vals[int(m.group(2))]
        m = re.match(r"set_lvar_int_to_constant (\d+)@ = (-?\d+)", l)
        if m:
            ints[int(m.group(1))] = int(m.group(2))
        i += 1
    n = int(vals.get(250, 0))
    races[int(num)] = {
        "checkpoints": [(vals[454 + k], vals[536 + k], vals[618 + k]) for k in range(n) if 454 + k in vals],
        "racers": int(vals.get(256, 1)),
        "cars": [ints[716 + k] for k in range(12) if 716 + k in ints],
        "laps": int(vals.get(224, 1)) if 224 in vals else 1,
        "start": (vals[732], vals[733], vals[734], vals[735]) if 732 in vals else None,
    }

with open(os.path.join(OUT, "races.lua"), "w") as f:
    f.write("-- Seeded by tools/seed/seed_races.py from main.scm's CPRACE race table. Edit freely: this file is ours now.\n")
    f.write("-- index: vanilla's race number (names are GXT RACE00..RACE24). racers: including you. cars: yours first,\n")
    f.write("-- then the opponents'. start: where the grid is (the stadiums; street races start at checkpoint 1).\n")
    f.write("RaceTable = {\n")
    for k in sorted(races):
        r = races[k]
        f.write("    [%d] = { racers = %d, laps = %d, cars = { %s },\n" % (k, r["racers"], r["laps"], ", ".join(str(c) for c in r["cars"])))
        if r["start"]:
            f.write("        start = { %.2f, %.2f, %.2f, %.1f },\n" % r["start"])
        f.write("        checkpoints = {\n")
        for c in r["checkpoints"]:
            f.write("            { %.2f, %.2f, %.2f },\n" % c)
        f.write("        } },\n")
    f.write("}\n")
print("races: %d, %d checkpoints" % (len(races), sum(len(r["checkpoints"]) for r in races.values())))
