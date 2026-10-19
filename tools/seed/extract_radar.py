#!/usr/bin/env python3
"""Copies the map's images for vana-map's own map (F11): the 144 radar tiles radar00..radar143.txd out of
models/gta3.img (a 12 x 12 grid of 500 m squares, radar00 the north-west corner) and models/hud.txd (the
blip sprites). Rockstar's files: copied from your own install at setup, never committed.

Usage: python3 tools/seed/extract_radar.py "/path/to/GTA San Andreas" [vana-map/data]
"""
import os
import struct
import sys


def img_entries(path):
    # VER2: an 8-byte header, 32-byte directory entries, 2048-byte sectors.
    with open(path, "rb") as img:
        magic, count = struct.unpack("<4sI", img.read(8))
        assert magic == b"VER2", "not a GTA:SA IMG archive: " + path
        directory = img.read(32 * count)
        for i in range(count):
            offset, streaming, size = struct.unpack_from("<IHH", directory, 32 * i)
            name = directory[32 * i + 8:32 * i + 32].split(b"\0")[0].decode("latin-1").lower()
            img.seek(offset * 2048)
            yield name, img.read((size or streaming) * 2048)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    game = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), "..", "..", "vana-map", "data")
    tiles = os.path.join(out, "radar")
    os.makedirs(tiles, exist_ok=True)
    wanted = {"radar%02d.txd" % i for i in range(144)}
    found = 0
    for name, data in img_entries(os.path.join(game, "models", "gta3.img")):
        if name in wanted:
            with open(os.path.join(tiles, name), "wb") as f:
                f.write(data)
            found += 1
    with open(os.path.join(game, "models", "hud.txd"), "rb") as src, open(os.path.join(out, "hud.txd"), "wb") as dst:
        dst.write(src.read())
    print("%d of 144 radar tiles and hud.txd written to %s" % (found, out))
    if found != 144:
        sys.exit("missing radar tiles: " + ", ".join(sorted(wanted - {n for n in os.listdir(tiles)})))


if __name__ == "__main__":
    main()
