#!/usr/bin/env python3
"""Seeds vana-shops' vending machines and food carts from retail map data.

Reads (never executes) the text IPLs' inst sections and the binary IPLs in models/gta3.img and
models/gta_int.img, and writes vana-shops/config/vendors.lua: every placed vending machine, candy
machine and food cart (the objects main.scm attaches the vending_machine / food_vendor brains to).
Ours afterwards: edit freely.

usage: seed_vendors.py <GTA San Andreas dir> <vana-shops/config dir>
"""
import os
import struct
import sys

GTA, OUT = sys.argv[1], sys.argv[2]
KINDS = {
    "vendmach": "soda", "vendmachfd": "candy", "vendin3": "soda", "cj_sprunk1": "soda", "cj_ext_sprunk": "soda",
    "cj_candyvendor": "candy", "cj_ext_candy": "candy",
    "icescart_prop": "icecream", "chillidogcart": "hotdog", "noodlecart_prop": "noodles",
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

vendors, seen = [], set()


def add(model_name, interior, x, y, z):
    kind = KINDS.get(model_name)
    key = (kind, round(x, 1), round(y, 1), round(z, 1))
    if kind and key not in seen:
        seen.add(key)
        vendors.append((kind, interior, x, y, z))


# Text IPLs: inst lines are "id, model, interior, x, y, z, qx, qy, qz, qw, lod".
for root, _, files in os.walk(os.path.join(GTA, "data", "maps")):
    for fn in files:
        if not fn.lower().endswith(".ipl"):
            continue
        section = None
        for line in open(os.path.join(root, fn), encoding="latin-1"):
            l = line.split("#")[0].strip()
            if l.lower() in ("inst", "enex", "cull", "pick", "path", "occl", "mult", "grge", "cars", "jump", "tcyc", "auzo"):
                section = l.lower()
            elif l.lower() == "end":
                section = None
            elif section == "inst" and l:
                f = [x.strip() for x in l.split(",")]
                if len(f) >= 6:
                    add(f[1].lower(), int(f[2]) & 0xFF, float(f[3]), float(f[4]), float(f[5]))

# Binary IPLs in the streaming archives.
for archive in ("gta3.img", "gta_int.img"):
    with open(os.path.join(GTA, "models", archive), "rb") as img:
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
                x, y, z, _, _, _, _, model, interior, _ = struct.unpack_from("<7f3i", data, at + 40 * k)
                add(names.get(model, ""), interior & 0xFF, x, y, z)

os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, "vendors.lua"), "w") as f:
    f.write("-- Seeded by tools/seed/seed_vendors.py from the map IPLs and gta3.img/gta_int.img. Edit freely: this file is ours now.\n")
    f.write("-- Vending machines and food carts: kind (see VendorKinds in config/vendorkinds.lua), interior, position.\n")
    f.write("Vendors = {\n")
    for kind, interior, x, y, z in sorted(vendors):
        f.write('    { kind = "%s", interior = %d, x = %.2f, y = %.2f, z = %.2f },\n' % (kind, interior, x, y, z))
    f.write("}\n")
counts = {}
for v in vendors:
    counts[v[0]] = counts.get(v[0], 0) + 1
print("vendors: %d %s" % (len(vendors), counts))
