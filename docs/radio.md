# Radio

`vana-radio` runs every station on the server's clock: each car, outside radio and speaker tuned to
a station hears the same moment of it. The game's own radio is switched off for good.

## How it works

- **The server plans** each station at least `aheadMs` (60 s) ahead as segments with absolute
  start times on its clock (`getTickCount`), and sends new segments to every client. A station
  starts part way into its first segment, as if it had been on the air already.
- **Clients sync their clock** by pinging the server (five quick pings, then one every 30 s) and
  keep the offset from the ping with the shortest round trip among the last 8.
- **Emitters** are where a station is heard: the car you're in (2D) and the nearest running cars
  outside (3D, muffled). Each plays the segment due now, at the position due now
  (`playSFX("radio", archive, track)`). It loads the next one paused 1.5 s ahead and starts it
  within a frame of its time. A sound more than 150 ms off is moved back in place.
- **Sources** (`config/radio.lua`, per station):
  - `vanilla`: vanilla's programme (below).
  - `stream`: an internet radio URL, played live. It can't be position-synced, and every listener
    downloads it, so at most `maxStreams` (2) play at once on a client.
  - `timer`: silent segments of a set length, for testing or as placeholders.
- **Station IDs** are what cars store (`vana:radio`, set by `vana-vehicles`). 1 to 11 are vanilla's
  stations, which are also MTA's radio channels, so saved cars keep theirs. 0 is off.

### Music zones

- **Zone stations** (`hidden` in the config: not in the car radio's list) use the `beats` source:
  vanilla's beat tracks (dance and lowrider music), each played as a routine up to its end marker
  and faded out over 3 s. The clubs play beat tracks 1-4 at random (no repeat in a row), the lowrider
  contest alternates 13 and 0 as vanilla's LOWR does.
- **Speakers** are `speaker` elements in `[data]/vana-data-radio` (edit them in the Map Editor:
  position, interior, station, range, volume). Each client plays the nearest 4 in range, in its
  interior, as 3D sounds.
- **Activities** join the routine playing at their zone (`getStationSegments`, `getBeats`), so the
  dancers' and lowriders' games run on the music everyone there hears ([activities.md](activities.md)).
- A station always has its next segment planned (as well as 60 s ahead), so an activity can join the
  next routine.

### In the car

- The native radio is kept on channel 0 with its HUD hidden, and its own switching is cancelled.
  MTA's channel alone isn't checked: the game's radio can play while it reads 0 (started by
  `setRadioPlaybackState`), so the game's track manager is checked too (`getRadioPlaybackState`).
- Switching is two actions ([controls.md](controls.md)), `/radionext` and `/radioprevious`, which
  step through the stations, then off. The radio keys (`radio_next` / `radio_previous`, the mouse
  wheel by default) are bound to them. As with `/engine`, only the driver can: anyone else gets
  "Only the driver can do that." The server sets the car's `vana:radio`, and every client in the car
  shows the new station's name when it changes.
- The station's name shows top centre on getting in and on each switch, as vanilla does. The font
  and colour are approximations (`hud` in the config).
- The radio plays while the engine runs.
- `/radiovolume 0-100`: the game's radio volume can't be read, so this is our own setting, saved on
  the client.

### Notes from the engine

- `playSFX`'s `"radio"` container takes the archive **by name** ("Playback FM", "K-Rose"...): a
  number fails. MTA finds the track by walking the archive's headers on every call.
- Tracks under 4.5 KB are refused by MTA. No retail track is that small.

## For other resources

- `getStationNow(id)` (server export): the track ID (or label) playing, ms into it, its kind and
  length; or, for a stream station, `false, 0, "stream", 0, url`.
- `getStationSegments(id)` (server export): the segment playing and those planned after it, `{ track,
  at, length, kind, beat }` with `at` on the server's `getTickCount` (the same in every resource).
- `getBeats(track)` (server export): a beat track's `{ ms, key }` list.
- `getServerTime()` (client export): the server's clock on this client, or false before the first sync.
- `/radiodebug` (client): the game's own radio state, the clock offset, and each emitter's segment,
  where it's due and where its sound is.
- `radiostatus` (console): every station's current and upcoming segments, and how many clients
  are listening.

## Track data (`vana-radio/config/radio_data.lua`)

Seeded from your game files by `tools/seed/seed_radio.py` (see [setup.md](setup.md)). It holds facts
only (track IDs, durations, beats), no audio: each player's game plays the audio itself.

- **Track IDs** are `audio/CONFIG/TrakLkup.dat`'s order, 0-based, 1922 in all (1922 means "no track").
  The streams, in order and with their track counts: AA 66 (police scanner), ADVERTS 69, AMBIENCE 40,
  BEATS 10, CH 130 (Playback FM), CO 155 (K-Rose), CR 156 (K-DST), CUTSCENE 141, DS 179 (Bounce FM),
  HC 115 (SF-UR), MH 152 (Radio Los Santos), MR 147 (Radio X), NJ 130 (CSR 103.9), RE 161 (K-Jah West),
  RG 170 (Master Sounds 98.3), TK 101 (WCTR).
- **Durations** come from each track's Ogg data: the last page's sample position over the stream's
  rate. A track's size is its header's last length entry, which is what the engine and MTA's
  `playSFX` read. TrakLkup's length includes the 8068-byte header for some tracks and not for others,
  so it can't be used. All 1922 durations match `sox --i -D` on exactly the bytes MTA plays. The
  scanner's short clips (60 to 65) are mostly silence, hence their tiny size.
- **Stations** (index = vanilla's radio ID + 1): songs (each a body plus up to 3 intro and 3 outro
  variants, as inclusive ID ranges), idents, DJ banter lists by weather and time of day, and the
  adverts each station never plays.
- **Beats**: the BEATS stream's track headers (1000 `{ ms, key }` slots each). Keys are LD_BEAT's
  sprites (1 to 4 dancing, 9 to 16 lowrider, 33 the end, always 2 s after the last beat).
  `beatTracks` is vanilla's 14-entry lookup (beat-track number to track ID). Tracks 176, 182, 183 and
  184 are in it but carry no beats in the retail files: only missions play them, as music
  (beat tracks 9 and 10 in End Of The Line and Intro).

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
| banter list pick (`ChooseDJBanterIndexFromList`) | 0x4E95E0 |
| `AddMusicTrackIndexToHistory` | 0x4E96C0 |
| `ResolveProbability`, `GetRandomNumberInRange` | 0x4D9C80, 0x4D9C10 |
| songs per station | 0x8C9010 (12 × int32) |
| song bodies | 0x8C9040 (`[station * 31 + song]`) |
| intros, outros | 0x8C9610, 0x8CA1B0 (ID pairs, same indexing) |
| idents | 0x8C8FB0 (pair per station) |
| adverts | 0x8C8B88 (one pair, 66 to 134) |
| adverts never played | 0x8CADD0 + 0x5C × station (23 × int32) |
| banter: general, evening, morning, night, rain, sun, fog | 0x8C8CB0, 0x8C8D70, 0x8C8DD0, 0x8C8E30, 0x8C8E90, 0x8C8EF0, 0x8C8F50 (pair per station) |
| beat-track lookup | 0x8AE538 (14 × int16) |

Ported in `vana-radio/sources/vanilla.lua`.

- **What comes next** (`ResolveProbability` rolls):
  - 95% of the time:
    - 90%: a song's body and outro.
    - else 50%: maybe (50%) an ident, then a song with its intro.
    - else the outro of a newly picked song, then either maybe (50%) an ident and a song with its
      intro, or maybe (50%) an ident and banter (an advert if there's no banter).
  - 5% of the time: maybe (50%) an ident, banter or else an advert, then a song with its intro.
  - The police scanner has banter wherever the others talk.
- **Song parts** (`QueueUpTracksForStation`, type 0 to 5): an ident, an advert, banter, intro + body +
  outro, body + outro, or an outro alone. Intro and outro variants are drawn at random.
- **Repeats are avoided** with per-station histories, filled as each piece starts playing:
  - songs: the last min(20, n − 2)
  - idents: min(8, n − 2)
  - adverts: the last 40, never the station's excluded ones
  - banter: 15 (the depth taken from the general list's size, for every list)
  `GetRandomNumberInRange` is inclusive at both ends.
- **Banter:**
  - The police scanner picks from its night list during the riots, otherwise from its general list.
  - Other stations, 60% of the time and only outside interiors, pick by conditions in this order:
    - rain coming (forecast weather 8 or 16): the rain list, 50%
    - fog (9): the fog list, 50%
    - 6:00 to 8:59: morning, 30%
    - 18:00 to 20:59: evening, 30%
    - 22:00 to 2:59: night, 30%
    - otherwise: general
  - The other 40% of the time there's no banter, so the caller plays an advert. Weather "coming" is
    `ForecastWeather(id, 3)`; the server uses its current weather or the one it's blending into.
    SF-UR has no idents and WCTR no banter in the tables.
  - The sun list's condition (hour under 8 and at least 6, with sunny weather) is never reached in
    practice.
- **Not ported:**
  - Story-gated content, played as if the story were complete: the special banter tables
    (0x8C8BF0, 0x8C8C50, 0x8CB280), WCTR's talk-show gating (stats 0x135 onwards; all shows count
    as available) and Radio Los Santos' ident 1100 (held back while stat 338 is 0).
  - Talking only outdoors (vanilla checks the listener's area) and the scanner's riot lists: a
    station is the same for everyone.
  - An unidentified banter-sized list at 0x8C8D10.
  - Track concatenation (0x4EA930), which is for user tracks only.

## Not yet verified in game

Checked offline and on the server: the seeded data, the vanilla port (24 hours of every station
simulated: every piece from the station's own archive or the adverts, history rules held), and the
server planning every station. Not yet heard on a client:
- that `playSFX("radio", name, index)` plays the right track at the right position, and the joins
  between segments (gapless or not)
- clock sync accuracy (two clients side by side should be within a frame or two)
- the native radio staying silent on entering cars of every kind, and the HUD name's look
- the outside radio's volume, muffling and range; `/radiovolume`
- speakers: their volume and range in each club, the routines' fade-outs
- dancers' moves seen from another client (server-set animations), and lowriders' hydraulics bounces
  (the driver's own hydraulics keys, synced as their controls) seen from another client
