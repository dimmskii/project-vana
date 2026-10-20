#!/usr/bin/env python3
"""Seeds vana-wildlife from Myths Maker 2.7's animal pack (Animal World, by Nadalao and partners; see
docs/credits.md): the animals only, never its myths (the hunter, Anim0).

Reads each animal folder (cleo/Animals/AnimN) once:
- its ini: every location (x, y, z, angle) with the folder's settings (how many, hours, radii, health,
  damage, aggression, respawn, weather) -> one wildlifespawner each, written as a Lua table
  (WildlifeSpawners) for tools/convert/to_maps.lua to turn into [data]/vana-data-wildlife/wildlife.map;
- its files: the model (AnimN.dff/.txd and the A<N>_k variants), its animations (.ifp, animgrp.dat)
  and its sounds (random*.mp3, damage.mp3), copied into vana-wildlife/mods/myths_maker/<species>/
  without duplicates (the pack repeats them across folders), and listed in
  vana-wildlife/config/species.lua.

Usage (from the repo root):
  python3 tools/seed/seed_wildlife.py "/path/to/Myths Maker/cleo/Animals" /tmp/seed
  lua5.1 tools/convert/to_maps.lua --from /tmp/seed wildlife
"""
import hashlib
import os
import re
import shutil
import sys

# Folder -> species, from the pack's description and the marker files in its folders (Russian names:
# заяц hare, олень deer, кабан boar, львица lioness, леопард-пантера leopard, волк wolf, медведь бурый
# brown bear, медведь черный black bear, собака dog, кот cat, пума puma); 2-14 by their textures.
SPECIES = {
    "pig": [2, 3], "cow": [4, 5], "ostrich": [6], "sheep": [7], "bird": [8], "gorilla": [9],
    "capybara": [10], "fox": [11, 12], "chicken": [14], "hare": [27, 28, 29, 30, 31],
    "deer": [32, 33, 34, 35, 36], "boar": [37, 38, 39, 40, 41], "lioness": [42, 43, 44, 45, 46],
    "leopard": [47, 48, 49, 50, 51], "wolf": [52, 53, 54, 55, 56], "brownbear": [57, 58, 59, 60, 61],
    "blackbear": [62, 63, 64, 65, 66, 67], "dog": [68, 69, 70, 71, 72, 85, 86], "cat": [73, 74, 75, 76, 77, 83],
    "puma": [78, 79, 80, 81, 82],
}
NAMES = {
    "pig": "Pig", "cow": "Cow", "ostrich": "Ostrich", "sheep": "Sheep", "bird": "Bird", "gorilla": "Gorilla",
    "capybara": "Capybara", "fox": "Fox", "chicken": "Chicken", "hare": "Hare", "deer": "Deer", "boar": "Boar",
    "lioness": "Lioness", "leopard": "Leopard", "wolf": "Wolf", "brownbear": "Brown bear", "blackbear": "Black bear",
    "dog": "Dog", "cat": "Cat", "puma": "Puma",
}


def md5(path):
    with open(path, "rb") as f:
        return hashlib.md5(f.read()).hexdigest()


def read_ini(path):
    """Section -> {key: value} (keys as written, with spaces)."""
    out, section = {}, None
    with open(path, encoding="latin-1") as f:
        for line in f:
            line = line.strip()
            m = re.match(r"^\[(.+)\]$", line)
            if m:
                section = out.setdefault(m.group(1).upper(), {})
            elif "=" in line and section is not None:
                k, v = line.split("=", 1)
                section[k.strip().lower()] = v.strip()
    return out


def num(sec, key, default=0.0):
    try:
        return float(sec.get(key, default))
    except ValueError:
        return default


def lua_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(round(v, 4)) if isinstance(v, float) else str(v)
    return '"%s"' % str(v).replace('"', '\\"')


class Store:
    """Unique files of one species: the same bytes are one file, named <species>_<n>.<ext>."""

    def __init__(self, root, species):
        self.dir = os.path.join(root, species)
        self.species = species
        self.by_hash, self.count = {}, {}
        os.makedirs(self.dir, exist_ok=True)

    def add(self, path, kind):
        h = md5(path)
        if h in self.by_hash:
            return self.by_hash[h]
        ext = os.path.splitext(path)[1].lower()
        counter = kind + ext  # models and textures numbered apart: deer_1.dff, deer_1.txd ...
        n = self.count.get(counter, 0) + 1
        self.count[counter] = n
        name = "%s_%s%d%s" % (self.species, kind, n, ext) if kind != "model" else "%s_%d%s" % (self.species, n, ext)
        shutil.copyfile(path, os.path.join(self.dir, name))
        rel = "mods/myths_maker/%s/%s" % (self.species, name)
        self.by_hash[h] = rel
        return rel


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    animals, seed_out = sys.argv[1], sys.argv[2]
    repo = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
    mods = os.path.join(repo, "vana-wildlife", "mods", "myths_maker")
    if os.path.isdir(mods):
        shutil.rmtree(mods)
    os.makedirs(seed_out, exist_ok=True)

    spawners, species_lua = [], []
    for species, folders in SPECIES.items():
        store = Store(mods, species)
        variants, ifps, sounds = [], [], {"random": [], "damage": []}
        seen_pairs, own_anims = set(), False
        for n in folders:
            d = os.path.join(animals, "Anim%d" % n)
            if not os.path.isdir(d):
                continue
            files = {f.lower(): os.path.join(d, f) for f in os.listdir(d)}
            # The model and its variants: (dff, txd) pairs; a variant without its own dff uses the base one.
            base_dff, base_txd = files.get("anim%d.dff" % n), files.get("anim%d.txd" % n)
            pairs = [(base_dff, base_txd)]
            for f in sorted(files):
                m = re.match(r"^a%d_(\d+)\.txd$" % n, f)
                if m:
                    pairs.append((files.get("a%d_%s.dff" % (n, m.group(1)), base_dff), files[f]))
            for dff, txd in pairs:
                if dff and txd:
                    pair = (store.add(dff, "model"), store.add(txd, "model"))
                    if pair not in seen_pairs:
                        seen_pairs.add(pair)
                        variants.append(pair)
            for f, p in sorted(files.items()):
                if f.endswith(".ifp"):
                    own_anims = True
                    rel = store.add(p, "anim")
                    if rel not in ifps:
                        ifps.append(rel)
                elif f == "animgrp.dat":
                    store.add(p, "animgrp")
                elif f.endswith(".mp3"):
                    kind = "damage" if f.startswith("damage") else "random"
                    rel = store.add(p, kind)
                    if rel not in sounds[kind]:
                        sounds[kind].append(rel)
            ini = files.get("anim%d.ini" % n)
            if not ini:
                continue
            c = read_ini(ini)
            radius, time, scen, attr, misc = (c.get(s, {}) for s in ("RADIUS", "TIME", "SCENARIO", "ATRIBUTES", "MISC"))
            loc = c.get("LOCATIONS", {})
            i = 1
            while ("location %d x" % i) in loc or ("location %d angle" % i) in loc:
                x, y, z = num(loc, "location %d x" % i), num(loc, "location %d y" % i), num(loc, "location %d z" % i)
                if x != 0 or y != 0:
                    spawners.append({
                        "pos": (x, y, z), "species": species, "angle": num(loc, "location %d angle" % i),
                        "quantity": int(num(attr, "myth quantity", 1)), "startHour": int(num(time, "starting hour")),
                        "endHour": int(num(time, "ending hour")), "findRadius": round(num(radius, "find radius", 80), 2),
                        "spawnRadius": round(num(radius, "spawn radius", 10), 2), "health": int(num(attr, "health", 100)),
                        "damage": int(num(attr, "damage")), "attacksPeds": num(misc, "attacks peds") == 1,
                        "attacksAnimals": num(misc, "attacks animals") == 1, "respawn": int(num(time, "respawn time", 10)),
                        # The pack's weather (100, 201, 403, 504...) isn't a vanilla weather ID and its
                        # script didn't decompile: any weather, the raw value kept in the note.
                        "weather": -1, "note": "Myths Maker Anim%d%s" % (n, "" if int(num(scen, "weather", -1)) == -1
                                                                           else " (pack weather %d)" % int(num(scen, "weather"))),
                    })
                i += 1
        lines = ["    %s = { name = %s, ownAnims = %s," % (species, lua_value(NAMES[species]), lua_value(own_anims))]
        lines.append("        variants = { %s }," % ", ".join("{ %s, %s }" % (lua_value(a), lua_value(b)) for a, b in variants))
        lines.append("        ifps = { %s }," % ", ".join(lua_value(x) for x in ifps))
        lines.append("        sounds = { random = { %s }, damage = { %s } } }," % (
            ", ".join(lua_value(x) for x in sounds["random"]), ", ".join(lua_value(x) for x in sounds["damage"])))
        species_lua.append("\n".join(lines))

    with open(os.path.join(repo, "vana-wildlife", "config", "species.lua"), "w") as f:
        f.write("-- Generated by tools/seed/seed_wildlife.py from Myths Maker 2.7's animal pack (docs/credits.md):\n"
                "-- each species' model variants ({ dff, txd }), its own animations (IFP) and sounds, in\n"
                "-- mods/myths_maker/<species>/. Re-seed rather than edit.\n"
                "WildlifeSpecies = {\n%s\n}\n" % "\n".join(species_lua))
    with open(os.path.join(seed_out, "wildlife_spawners.lua"), "w") as f:
        f.write("WildlifeSpawners = {\n")
        for s in spawners:
            fields = ", ".join("%s = %s" % (k, lua_value(v)) for k, v in s.items() if k != "pos")
            f.write("    { %s, %s, %s, %s },\n" % (lua_value(s["pos"][0]), lua_value(s["pos"][1]), lua_value(s["pos"][2]), fields))
        f.write("}\n")
    print("%d spawners, %d species -> vana-wildlife/mods/myths_maker, config/species.lua, %s/wildlife_spawners.lua"
          % (len(spawners), len(SPECIES), seed_out))


if __name__ == "__main__":
    main()
