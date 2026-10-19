# Radio

The radio is being rebuilt as one server-side schedule per station: every car, speaker and dance
floor tuned to a station hears the same moment of it. This page records the vanilla data it's built
on. The scheduler (`vana-radio`) and music zones come next.

## Track data (`vana-radio/config/radio_data.lua`)

Seeded from your game files by `tools/seed/seed_radio.py` (see [setup.md](setup.md)). It holds facts
only (track IDs, durations, beats), no audio: each player's game plays the audio itself.

- **Track IDs** are `audio/CONFIG/TrakLkup.dat`'s order, 0-based, 1922 in all (1922 means "no track").
  The streams, in order and with their track counts: AA 66 (police scanner), ADVERTS 69, AMBIENCE 40,
  BEATS 10, CH 130 (Playback FM), CO 155 (K-Rose), CR 156 (K-DST), CUTSCENE 141, DS 179 (Bounce FM),
  HC 115 (SF-UR), MH 152 (Radio Los Santos), MR 147 (Radio X), NJ 130 (CSR 103.9), RE 161 (K-Jah West),
  RG 170 (Master Sounds 98.3), TK 101 (WCTR).
- **Durations** come from each track's Ogg data: the last whole page's sample position over the
  stream's rate. Two retail quirks: a track header's size field is sometimes the whole entry's
  (header included), and some tracks end in a cut-off page that never decodes. So the seed walks the
  pages within the TrakLkup length and counts only whole ones. All 1922 match `sox --i -D`
  on the decrypted tracks. The scanner's short clips (60 to 65) are mostly silence, hence their tiny size.
- **Stations** (index = vanilla's radio ID + 1): songs (each a body plus up to 3 intro and 3 outro
  variants, as inclusive ID ranges), idents, DJ banter lists by weather and time of day, and the
  adverts each station never plays.
- **Beats**: the BEATS stream's track headers (1000 `{ ms, key }` slots each). Keys are LD_BEAT's
  sprites (1 to 4 dancing, 9 to 16 lowrider, 33 the end, always 2 s after the last beat).
  `beatTracks` is vanilla's 14-entry lookup (beat-track number to track ID). Tracks 176, 182, 183 and
  184 are in it but carry no beats in the retail files.

### Stream format

Each stream file is XORed with a 16-byte key (`EA 3A C4 A1 9A A8 14 F3 48 B0 D7 23 9D E8 FF F1`),
keyed on the absolute file position. Each track starts with an 8068-byte header: 1000 × `{ int32 ms,
int32 key }` beats, 8 × `{ uint32 length, uint32 sample rate }` (unused slots `0xCDCDCDCD`), and a
trailer. The Ogg Vorbis data follows (32 kHz stereo).

## How vanilla picks what plays (CAERadioTrackManager, US 1.0)

| What | Address |
| --- | --- |
| `ChooseTracksForStation` | 0x4EB180 |
| `QueueUpTracksForStation` | 0x4EA670 |
| `ChooseMusicTrackIndex` | 0x4EA270 |
| `ChooseIdentIndex` | 0x4E94C0 |
| `ChooseAdvertIndex` | 0x4E9570 |
| `ChooseDJBanterIndex` | 0x4EA2D0 |
| `ChooseTalkRadioShow` (WCTR) | 0x4E8E40 |
| songs per station | 0x8C9010 (12 × int32) |
| song bodies | 0x8C9040 (`[station * 31 + song]`) |
| intros, outros | 0x8C9610, 0x8CA1B0 (ID pairs, same indexing) |
| idents | 0x8C8FB0 (pair per station) |
| adverts | 0x8C8B88 (one pair, 66 to 134) |
| adverts never played | 0x8CADD0 + 0x5C × station (23 × int32) |
| banter: general, evening, morning, night, rain, sun, fog | 0x8C8CB0, 0x8C8D70, 0x8C8DD0, 0x8C8E30, 0x8C8E90, 0x8C8EF0, 0x8C8F50 (pair per station) |
| beat-track lookup | 0x8AE538 (14 × int16) |

- **What comes next:** 90% of the time the next song. Otherwise a mix of ident, advert and banter,
  then a song. A song is queued as intro + body + outro, or body + outro.
- **Repeats are avoided** with histories: songs 20, idents 8 (or one fewer than the station has),
  adverts 40, banter 15. `GetRandomNumberInRange` is inclusive at both ends.
- **Banter:**
  - The police scanner picks from its night list during the riots, otherwise from its general list.
  - Other stations, 60% of the time and only outside interiors, pick by conditions in this order:
    - rain coming (forecast weather 8 or 16): the rain list, 50%
    - fog (9): the fog list, 50%
    - 6:00 to 8:59: morning, 30%
    - 18:00 to 20:59: evening, 30%
    - 22:00 to 2:59: night, 30%
    - otherwise: general
  - The sun list's condition (hour under 8 and at least 6, with sunny weather) is never reached in
    practice.
- **Not ported:**
  - Story-gated banter (three special tables at 0x8C8BF0, 0x8C8C50 and 0x8CB280) and WCTR's
    talk-show gating: we play as if the story is complete, all shows available.
  - An unidentified banter-sized list at 0x8C8D10.
  - Track concatenation (0x4EA930), which is for user tracks only.
