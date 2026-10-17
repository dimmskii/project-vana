#!/usr/bin/env python3
"""Seeds vana-population's editable Lua config from retail game data.

Reads (never executes) the decompiled main.scm and gta_sa.exe (US 1.0, sha256 a559aa77...cbd26):
  - zones.lua:  zone population types, races, dealer strengths and gang territories, from main.scm's
                INITIAL block plus the LA1FIN2 ("Home Coming") territory changes
  - gangs.lua:  gang weapons, from CGangs::Initialise's table in the exe plus main.scm overrides
  - groups.lua: popcycle group -> pedgrp.dat line table (CPopulation::m_TranslationArray in the exe)

The generated files are ours afterwards: edit them freely, re-run this only to start over.

usage: seed_population.py <GTA San Andreas dir> <vana-population/config dir>
"""
import os
import re
import struct
import sys

GTA, OUT = sys.argv[1], sys.argv[2]
MAIN = os.path.join(GTA, "data", "script", "main.txt")
EXE = os.path.join(GTA, "gta_sa.exe")
EXE_SHA256 = "a559aa772fd136379155efa71f00c47aad34bbfeae6196b0fe1047d0645cbd26"

ZONE_TYPES = {
    "Business": "business", "Desert": "desert", "Entertainment": "entertainment", "Countryside": "countryside",
    "ResidentialRich": "residential_rich", "ResidentialAverage": "residential_average",
    "ResidentialPoor": "residential_poor", "Gangland": "gangland", "Beach": "beach", "Shopping": "shopping",
    "Park": "park", "Industry": "industry", "EntertainmentBusy": "entertainment_busy",
    "ShoppingBusy": "shopping_busy", "ShoppingPosh": "shopping_posh",
    "ResidentialRichSecluded": "residential_rich_secluded", "Airport": "airport", "GolfClub": "golf_club",
    "OutOfTownFactory": "out_of_town_factory", "AirportRunway": "airport_runway",
}
GANGS = ["ballas", "grove", "vagos", "rifa", "da_nang", "mafia", "triad", "aztecas"]
GANG_TYPES = {"Ballas": "ballas", "Grove": "grove", "Vagos": "vagos", "Rifa": "rifa", "DaNangBoys": "da_nang",
              "Mafia": "mafia", "Triad": "triad", "Aztecas": "aztecas"}
RACES = {"Black": ["black"], "BlackHispanic": ["black", "hispanic"], "HispanicWhite": ["hispanic", "white"],
         "OrientalWhite": ["oriental", "white"]}
WEAPON_NAMES = {0: "unarmed", 4: "knife", 22: "pistol", 24: "desert eagle", 28: "micro smg", 29: "mp5",
                30: "ak47", 32: "tec9"}
WEAPON_TYPES = {"Unarmed": 0, "Knife": 4, "Pistol": 22, "DesertEagle": 24, "MicroUzi": 28, "Mp5": 29,
                "Ak47": 30, "Tec9": 32}
POPCYCLE_GROUPS = [
    "workers", "business", "clubbers", "farmers", "beachfolk", "parkfolk", "casual_rich", "casual_average",
    "casual_poor", "prostitutes", "criminals", "golfers", "servants", "aircrew", "entertainers",
    "out_of_town_factory", "desert_folk", "aircrew_runway",
    "ballas", "grove", "vagos", "rifa", "da_nang", "mafia", "triad", "aztecas", "unused_1", "unused_2",
    "dealers", "shopkeepers", "office_workers", "husbands", "wives",
]

lines = open(MAIN, encoding="latin-1").read().split("\n")


def block(script):
    """Every line under a label of this script (labels are named <SCRIPT>_<offset>)."""
    result, current = [], None
    for l in lines:
        if m := re.match(r"^:([A-Za-z0-9_]+)_\d+\s*$", l):
            current = m[1]
        elif current == script:
            result.append(l)
    return result


zones = {}


def zone(name):
    return zones.setdefault(name, {"type": None, "races": None, "dealers": 0, "noCops": False, "gangs": {}})


def apply(block_lines):
    for l in block_lines:
        l = l.strip()
        if m := re.match(r"set_zone_population_type '(\w+)' \{type\} ZoneType\.(\w+)", l):
            zone(m[1])["type"] = ZONE_TYPES[m[2]]
        elif m := re.match(r"set_zone_population_race '(\w+)' \{races\} RaceSet\.(\w+)", l):
            zone(m[1])["races"] = RACES[m[2]]
        elif m := re.match(r"set_zone_dealer_strength '(\w+)' \{strength\} (\d+)", l):
            zone(m[1])["dealers"] = int(m[2])
        elif m := re.match(r"set_zone_gang_strength '(\w+)' \{gangId\} GangType\.(\w+) \{density\} (\d+)", l):
            zone(m[1])["gangs"][GANG_TYPES[m[2]]] = int(m[3])
        elif m := re.match(r"set_zone_no_cops '(\w+)' \{state\} (\w+)", l):
            zone(m[1])["noCops"] = m[2] == "true"


def label(name):
    """Lines under exactly one label, e.g. one branch of a mission."""
    start = lines.index(":%s" % name)
    end = next(i for i in range(start + 1, len(lines)) if re.match(r"^:[A-Za-z0-9_]+", lines[i]))
    return lines[start + 1:end]


apply(block("INITIAL"))
apply(block("LA1FIN2"))
# Grove takes Grove Street back in the final arc (MANSIO3 "Grove 4 Life", winning branch).
apply(label("MANSIO3_6740"))

# --- exe tables -------------------------------------------------------------------------------
import hashlib
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

# CGangs::Initialise (0x5DE680 calls SetGangWeapons with immediates); the values are stable across
# US 1.0 and documented in gta-reversed, so they are recorded here, then main.scm overrides apply.
gang_weapons = {"ballas": [22, 28, 0], "grove": [22, 0, 0], "vagos": [22, 0, 0], "rifa": [22, 28, 0],
                "da_nang": [22, 28, 0], "mafia": [24, 0, 0], "triad": [22, 30, 0], "aztecas": [22, 28, 0]}
for l in block("RYDER2"):
    if m := re.match(r"\s*set_gang_weapons GangType\.(\w+) \{weaponType1\} WeaponType\.(\w+) \{weaponType2\} WeaponType\.(\w+) \{weaponType3\} WeaponType\.(\w+)", l):
        gang_weapons[GANG_TYPES[m[1]]] = [WEAPON_TYPES[m[2]], WEAPON_TYPES[m[3]], WEAPON_TYPES[m[4]]]

# --- write ------------------------------------------------------------------------------------
os.makedirs(OUT, exist_ok=True)
HEADER = "-- Seeded by tools/seed/seed_population.py from retail game data. Edit freely: this file is ours now.\n"


def lua_list(items):
    return "{ " + ", ".join('"%s"' % i for i in items) + " }"


with open(os.path.join(OUT, "zones.lua"), "w") as f:
    f.write(HEADER)
    f.write("-- Zone population settings keyed by info.zon zone name: main.scm's INITIAL block, the LA1FIN2\n")
    f.write("-- (\"Home Coming\") gang territories, and Grove retaking Grove Street (MANSIO3_6740).\n")
    f.write("-- type: popcycle.dat zone type. races: allowed civilian races (nil = all). dealers: dealer strength.\n")
    f.write("-- gangs: gang strength per gang (main.scm density).\n")
    f.write("PopZones = {\n")
    for name in sorted(zones):
        z = zones[name]
        parts = ['type = "%s"' % z["type"]] if z["type"] else []
        if z["races"]:
            parts.append("races = " + lua_list(z["races"]))
        if z["dealers"]:
            parts.append("dealers = %d" % z["dealers"])
        if z["noCops"]:
            parts.append("noCops = true")
        gangs = {g: v for g, v in z["gangs"].items() if v > 0}
        if gangs:
            parts.append("gangs = { " + ", ".join("%s = %d" % (g, gangs[g]) for g in GANGS if g in gangs) + " }")
        f.write("    %-9s = { %s },\n" % ('["%s"]' % name, ", ".join(parts)))
    f.write("}\n")

with open(os.path.join(OUT, "gangs.lua"), "w") as f:
    f.write(HEADER)
    f.write("-- weapons: weapon IDs a member may carry (CGangs::Initialise defaults; Grove from the RYDER2 mission.\n")
    f.write("-- Spraying all 100 tags upgrades Grove to desert eagle, mp5, knife in main.scm's COLLS script).\n")
    f.write("-- armedChance: chance a spawned member carries one of them (CPopulation::AddPed: 33%).\n")
    f.write("-- drawnChance: chance the weapon starts in hand rather than holstered (ours; vanilla varies).\n")
    f.write("Gangs = {\n")
    for i, g in enumerate(GANGS):
        w = gang_weapons[g]
        f.write('    %-8s = { id = %d, weapons = { %s }, armedChance = 0.33, drawnChance = 0.5 }, -- %s\n'
                % (g, i, ", ".join(str(x) for x in w), ", ".join(WEAPON_NAMES[x] for x in w)))
    f.write("}\n")

with open(os.path.join(OUT, "groups.lua"), "w") as f:
    f.write(HEADER)
    f.write("-- Popcycle groups in engine order, each with its pedgrp.dat line (0-based, non-comment lines)\n")
    f.write("-- for Los Santos, San Fierro and Las Venturas: CPopulation::m_TranslationArray (0x8D2540).\n")
    f.write("PopGroups = {\n")
    for name, (la, sf, lv) in zip(POPCYCLE_GROUPS, translation):
        f.write('    { name = "%s", pedgrp = { %d, %d, %d } },\n' % (name, la, sf, lv))
    f.write("}\n")

typed = sum(1 for z in zones.values() if z["type"])
print("zones %d (%d typed), gangs %s" % (len(zones), typed, gang_weapons["grove"]))
print("translation", translation[:3], "...", translation[-5:])
