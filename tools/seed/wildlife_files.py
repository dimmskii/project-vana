#!/usr/bin/env python3
"""Lists in vana-wildlife/meta.xml the files clients download (at connect): those of the species
config/wildlife.lua knows (their models, sounds and walkcycle IFPs, from config/species.lua), between
its <!-- files --> markers. Run after changing either (from the repo root):
  python3 tools/seed/wildlife_files.py
"""
import os
import re

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "vana-wildlife")
kinds = open(os.path.join(root, "config", "wildlife.lua")).read()
species = open(os.path.join(root, "config", "species.lua")).read()

files = []
for m in re.finditer(r"^    (\w+) = \{ driver = .*$", kinds, re.M):
    sp = re.search(r"^    %s = \{.*?\} \} \},$" % m.group(1), species, re.M | re.S)
    for path in re.findall(r'"(mods/[^"]+)"', (sp.group(0) if sp else "") + m.group(0)):
        if path not in files:
            files.append(path)
meta_path = os.path.join(root, "meta.xml")
meta = open(meta_path).read()
block = "".join('    <file src="%s" />\n' % p for p in files)
meta = re.sub(r"(<!-- files -->\n).*?(    <!-- /files -->)", lambda m: m.group(1) + block + m.group(2), meta, flags=re.S)
open(meta_path, "w").write(meta)
print("%d files in vana-wildlife/meta.xml" % len(files))
