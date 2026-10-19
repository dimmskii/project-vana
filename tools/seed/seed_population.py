#!/usr/bin/env python3
"""Seeds vana-population's popcycle group table from gta_sa.exe (US 1.0, sha256 a559aa77...cbd26):
groups.lua, each popcycle group's pedgrp.dat line (CPopulation::m_TranslationArray in the exe).

Zones (zones.lua) and gang weapons (gangs.lua) came from main.scm once and are canonical config now,
hand-maintained; nothing regenerates them.

usage: seed_population.py <GTA San Andreas dir> <vana-population/config dir>
"""
import hashlib
import os
import struct
import sys

GTA, OUT = sys.argv[1], sys.argv[2]
EXE = os.path.join(GTA, "gta_sa.exe")
EXE_SHA256 = "a559aa772fd136379155efa71f00c47aad34bbfeae6196b0fe1047d0645cbd26"

POPCYCLE_GROUPS = [
    "workers", "business", "clubbers", "farmers", "beachfolk", "parkfolk", "casual_rich", "casual_average",
    "casual_poor", "prostitutes", "criminals", "golfers", "servants", "aircrew", "entertainers",
    "out_of_town_factory", "desert_folk", "aircrew_runway",
    "ballas", "grove", "vagos", "rifa", "da_nang", "mafia", "triad", "aztecas", "unused_1", "unused_2",
    "dealers", "shopkeepers", "office_workers", "husbands", "wives",
]

# --- exe tables -------------------------------------------------------------------------------
exe = open(EXE, "rb").read()
assert hashlib.sha256(exe).hexdigest() == EXE_SHA256, "unexpected gta_sa.exe build"
pe = struct.unpack_from("<I", exe, 0x3C)[0]
nsec, optsz = struct.unpack_from("<H", exe, pe + 6)[0], struct.unpack_from("<H", exe, pe + 20)[0]
base = struct.unpack_from("<I", exe, pe + 52)[0]
sections = []
for i in range(nsec):
    o = pe + 24 + optsz + 40 * i
    vsize, va, rsize, raw = struct.unpack_from("<IIII", exe, o + 8)
    sections.append((base + va, max(vsize, rsize), raw))


def at(addr):
    return next(raw + addr - va for va, size, raw in sections if va <= addr < va + size)


translation = [struct.unpack_from("<3i", exe, at(0x8D2540) + 12 * i) for i in range(len(POPCYCLE_GROUPS))]

os.makedirs(OUT, exist_ok=True)
HEADER = "-- Seeded by tools/seed/seed_population.py from gta_sa.exe. Edit freely: this file is ours now.\n"

with open(os.path.join(OUT, "groups.lua"), "w") as f:
    f.write(HEADER)
    f.write("-- Popcycle groups in engine order, each with its pedgrp.dat line (0-based, non-comment lines)\n")
    f.write("-- for Los Santos, San Fierro and Las Venturas: CPopulation::m_TranslationArray (0x8D2540).\n")
    f.write("PopGroups = {\n")
    for name, (la, sf, lv) in zip(POPCYCLE_GROUPS, translation):
        f.write('    { name = "%s", pedgrp = { %d, %d, %d } },\n' % (name, la, sf, lv))
    f.write("}\n")

print("translation", translation[:3], "...", translation[-5:])
