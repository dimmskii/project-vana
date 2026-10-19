#!/usr/bin/env python3
"""Seeds vana-radio's track data from the retail game files (read, never executed):

  - gta_sa.exe (US 1.0, sha256 a559aa77...cbd26): the radio stations' track tables, as
    CAERadioTrackManager uses them (disassembled; see docs/radio.md): songs (body, 3 intros, 3
    outros), idents, adverts and their per-station exclusions, DJ banter lists by weather and time
    of day, and the beat-track lookup.
  - audio/config/TrakLkup.dat and audio/streams/*: each track's exact duration (from its Ogg data:
    the last page's sample position over the stream's sample rate) and the beat-track headers' beats
    (time in ms, key).

Writes vana-radio/config/radio_data.lua: facts only (track IDs, durations, beat timings), no audio.
The audio itself plays from each player's own install (playSFX "radio").

usage: seed_radio.py <GTA San Andreas dir> <vana-radio/config dir>
"""
import hashlib
import os
import struct
import sys

GTA, OUT = sys.argv[1], sys.argv[2]
EXE_SHA256 = "a559aa772fd136379155efa71f00c47aad34bbfeae6196b0fe1047d0645cbd26"
KEY = bytes([0xEA, 0x3A, 0xC4, 0xA1, 0x9A, 0xA8, 0x14, 0xF3, 0x48, 0xB0, 0xD7, 0x23, 0x9D, 0xE8, 0xFF, 0xF1])
NONE = 1922  # the engine's "no track" (the track count)
STATIONS = ["AA", "PlaybackFM", "KRose", "KDST", "BounceFM", "SFUR", "RadioLosSantos", "RadioX", "CSR",
            "KJahWest", "MasterSounds", "WCTR"]

exe = open(os.path.join(GTA, "gta_sa.exe"), "rb").read()
assert hashlib.sha256(exe).hexdigest() == EXE_SHA256, "unexpected gta_sa.exe build"


def off(va):
    if 0x8A4000 <= va < 0xC9E000:
        return va - 0x8A4000 + 0x4A1C00
    if 0x858000 <= va < 0x8A4000:
        return va - 0x858000 + 0x456800
    raise ValueError(hex(va))


def i32(va):
    return struct.unpack_from("<i", exe, off(va))[0]


def pair(va):
    lo, hi = i32(va), i32(va + 4)
    return None if lo == NONE else (lo, hi)


# --- exe tables (addresses from ChooseMusicTrackIndex 0x4EA270, QueueUpTracksForStation 0x4EA670,
# ChooseIdentIndex 0x4E94C0, ChooseAdvertIndex 0x4E9570, ChooseDJBanterIndex 0x4EA2D0) ---------------
stations = []
for s, name in enumerate(STATIONS):
    n = i32(0x8C9010 + 4 * s)
    songs = []
    for k in range(n):
        songs.append({"body": i32(0x8C9040 + 4 * (s * 31 + k)), "intros": pair(0x8C9610 + 8 * (s * 31 + k)),
                      "outros": pair(0x8CA1B0 + 8 * (s * 31 + k))})
    banter = {}
    for kind, va in [("general", 0x8C8CB0), ("evening", 0x8C8D70), ("morning", 0x8C8DD0), ("night", 0x8C8E30),
                     ("rain", 0x8C8E90), ("sun", 0x8C8EF0), ("fog", 0x8C8F50)]:
        r = pair(va + 8 * s)
        if r:
            banter[kind] = r
    exclude = [x for x in (i32(0x8CADD0 + 0x5C * s + 4 * j) for j in range(23)) if x >= 0 and x != NONE]
    stations.append({"name": name, "songs": songs, "idents": pair(0x8C8FB0 + 8 * s), "banter": banter,
                     "excludedAdverts": exclude})
adverts = (i32(0x8C8B88), i32(0x8C8B8C))
beat_lookup = [struct.unpack_from("<h", exe, off(0x8AE538) + 2 * i)[0] for i in range(14)]

# --- streams: durations and beats ---------------------------------------------------------------------
paks = open(os.path.join(GTA, "audio", "CONFIG", "StrmPaks.dat"), "rb").read()
pak_names = [paks[i * 16:(i + 1) * 16].split(b"\0")[0].decode() for i in range(len(paks) // 16)]
trak = open(os.path.join(GTA, "audio", "CONFIG", "TrakLkup.dat"), "rb").read()
tracks = [struct.unpack_from("<B3xII", trak, 12 * i) for i in range(len(trak) // 12)]  # (pak, offset, length)


def dec(buf, pos):
    return bytes(b ^ KEY[(pos + i) % 16] for i, b in enumerate(buf))


durations, beats = [], {}
handles = {}
for tid, (pak, offset, _) in enumerate(tracks):
    name = pak_names[pak]
    f = handles.get(name) or open(os.path.join(GTA, "audio", "streams", name), "rb")
    handles[name] = f
    f.seek(offset)
    header = dec(f.read(8068), offset)
    # The Ogg data's size is the header's last length entry, as the engine and MTA's playSFX read it
    # (TrakLkup's length includes the header for some tracks and not for others).
    size = [l for l, _ in (struct.unpack_from("<II", header, 8000 + 8 * i) for i in range(8)) if l != 0xCDCDCDCD][-1]
    data_at, data_end = offset + 8068, offset + 8068 + size
    # The duration is the stream's last sample position over its rate: walk the Ogg pages (decoding
    # only their headers), counting whole pages only.
    rate, serial, granule, pos = None, None, 0, data_at
    while pos + 27 <= data_end:
        f.seek(pos)
        page = dec(f.read(27), pos)
        if page[:4] != b"OggS":
            break
        flags, gpos, ser = page[5], *struct.unpack_from("<qI", page, 6)
        segs = dec(f.read(page[26]), pos + 27)
        if flags & 2 and rate is None:  # first page: the vorbis identification header
            ident = dec(f.read(30), pos + 27 + len(segs))
            assert ident[1:7] == b"vorbis", (tid, ident)
            rate, serial = struct.unpack_from("<I", ident, 12)[0], ser
        end = pos + 27 + len(segs) + sum(segs)
        if ser == serial and gpos > granule and end <= data_end:
            granule = gpos
        pos = end
    assert rate and granule, "track %d: no Ogg data" % tid
    durations.append(int(round(granule * 1000 / rate)))
    if name == "BEATS":
        b = [struct.unpack_from("<iI", header, 8 * i) for i in range(1000)]
        b = [(t, k) for t, k in b if t >= 0 and k != 0]
        if b:
            beats[tid] = b

# --- write --------------------------------------------------------------------------------------------
def lua_pair(p):
    return "{ %d, %d }" % p if p else "nil"


os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, "radio_data.lua"), "w") as f:
    f.write("-- Origin: gta_sa.exe's radio tables and the audio streams' headers via tools/seed/seed_radio.py;\n")
    f.write("-- rerunning it overwrites edits. Facts only: track IDs (TrakLkup.dat order, 0-based), durations, beats.\n")
    f.write("RadioData = {\n")
    f.write("    -- Every track's duration in ms, by track ID (index = ID + 1).\n")
    f.write("    durations = {\n")
    for i in range(0, len(durations), 16):
        f.write("        " + ", ".join(str(d) for d in durations[i:i + 16]) + ",\n")
    f.write("    },\n")
    f.write("    -- Per station (index = vanilla's radio ID + 1: 1 the police scanner, 2 Playback FM .. 12 WCTR): each\n")
    f.write("    -- song's body and its intro / outro variants (inclusive ID ranges), idents, DJ banter lists.\n")
    f.write("    stations = {\n")
    for s in stations:
        f.write('        { name = "%s", idents = %s, excludedAdverts = { %s },\n' % (
            s["name"], lua_pair(s["idents"]), ", ".join(str(x) for x in s["excludedAdverts"])))
        f.write("          banter = { %s },\n" % ", ".join("%s = %s" % (k, lua_pair(v)) for k, v in s["banter"].items()))
        f.write("          songs = {\n")
        for song in s["songs"]:
            f.write("              { body = %d, intros = %s, outros = %s },\n" % (song["body"], lua_pair(song["intros"]), lua_pair(song["outros"])))
        f.write("          } },\n")
    f.write("    },\n")
    f.write("    adverts = %s,\n" % lua_pair(adverts))
    f.write("    -- The 14 beat tracks (vanilla's beat-track numbers 0..13, index = number + 1) -> track ID.\n")
    f.write("    beatTracks = { %s },\n" % ", ".join(str(t) for t in beat_lookup))
    f.write("    -- Beats by track ID: { ms, key }, key = LD_BEAT's sprite: 1 down, 2 left, 3 up, 4 right (dancing);\n")
    f.write("    -- 9 left, 10 right, 11 up-right, 12 down-left, 13 up, 14 down, 15 up-left, 16 down-right (lowrider);\n")
    f.write("    -- 33 ends the routine, 2 s after its last beat.\n")
    f.write("    beats = {\n")
    for tid, b in sorted(beats.items()):
        f.write("        [%d] = {\n" % tid)
        for i in range(0, len(b), 8):
            f.write("            " + ", ".join("{ %d, %d }" % x for x in b[i:i + 8]) + ",\n")
        f.write("        },\n")
    f.write("    },\n")
    f.write("}\n")

songs = sum(len(s["songs"]) for s in stations)
print("tracks %d (%d with a duration), stations %d, songs %d, beat tracks %d" % (
    len(durations), sum(1 for d in durations if d > 0), len(stations), songs, len(beats)))
print("e.g. track 231 (Playback FM's first song) %d ms; BEATS 175 %d ms" % (durations[231], durations[175]))
