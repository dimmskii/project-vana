-- Radio settings. Every station runs on the server's clock (docs/radio.md); cars, outside radios and
-- speakers all play the same moment of it.
RadioConfig = {
    -- The stations, in switching order. `id` is what a car stores (`vana:radio`, 0 off): 1..11 are
    -- vanilla's stations (and MTA's radio channels), keep those for saved cars. `source`:
    --   "vanilla": vanilla's programme (songs, DJs, idents, adverts) from the game's own audio; `radio`
    --              is vanilla's radio ID (1 Playback FM .. 11 WCTR)
    --   "stream":  an internet radio stream (`url`), played live: it can't be position-synced
    --   "timer":   no audio, just `length` ms segments named `label` (testing, placeholders)
    --   "beats":   vanilla's beat tracks (the BEATS archive: dancing and the lowrider contest), by
    --              vanilla's beat-track number (`beats`), each played as a routine up to its end
    --              marker and faded out; in `order` "sequence" or at random (no repeat in a row)
    -- `hidden` stations aren't in the car radio's list: they're heard from speakers (music zones,
    -- [data]/vana-data-radio) and drive the activities there.
    stations = {
        { id = 1, name = "Playback FM", source = "vanilla", radio = 1 },
        { id = 2, name = "K-Rose", source = "vanilla", radio = 2 },
        { id = 3, name = "K-DST", source = "vanilla", radio = 3 },
        { id = 4, name = "Bounce FM", source = "vanilla", radio = 4 },
        { id = 5, name = "SF-UR", source = "vanilla", radio = 5 },
        { id = 6, name = "Radio Los Santos", source = "vanilla", radio = 6 },
        { id = 7, name = "Radio X", source = "vanilla", radio = 7 },
        { id = 8, name = "CSR 103.9", source = "vanilla", radio = 8 },
        { id = 9, name = "K-Jah West", source = "vanilla", radio = 9 },
        { id = 10, name = "Master Sounds 98.3", source = "vanilla", radio = 10 },
        { id = 11, name = "WCTR", source = "vanilla", radio = 11 },
        -- Music zones. Vanilla's DANCE plays beat tracks 1-4; LOWR alternates 13 and 0.
        { id = 101, name = "Alhambra", source = "beats", beats = { 1, 2, 3, 4 }, hidden = true },
        { id = 102, name = "Ten Green Bottles", source = "beats", beats = { 1, 2, 3, 4 }, hidden = true },
        { id = 103, name = "Lil' Probe Inn", source = "beats", beats = { 1, 2, 3, 4 }, hidden = true },
        { id = 110, name = "Lowrider contest", source = "beats", beats = { 13, 0 }, order = "sequence", hidden = true },
        -- { id = 20, name = "Some Internet FM", source = "stream", url = "http://example.com/stream.mp3" },
        -- { id = 21, name = "Test Timer", source = "timer", length = 20000, label = "Test segment" },
    },

    aheadMs = 60000,   -- each station is planned at least this far ahead
    preloadMs = 1500,  -- a client loads the next track this long before it starts, for a gapless join
    resyncMs = 150,    -- a playing track is moved back in place once it drifts this far

    -- In the car (2D).
    car = { volume = 0.8 },
    -- A running car's radio heard from outside: muffled (BASS parametric EQ), only the nearest few.
    outside = { range = 25, minDistance = 3, volume = 0.55, nearest = 4,
                muffle = { fCenter = 1800, fBandwidth = 36, fGain = -15 } },
    -- Internet streams are a download each: at most this many play at once (the car's included).
    maxStreams = 2,
    -- Speakers (music zones): the nearest few in range play; a routine fades out over its last fadeMs.
    speakers = { nearest = 4, minDistance = 4 },
    fadeMs = 3000,

    -- The station name shown on switching and getting in, in vanilla's 640 x 448 HUD space.
    hud = { y = 22, scale = 1.0, font = "beckett", colour = { 228, 172, 52 }, offColour = { 150, 150, 150 },
            showMs = 2500, fadeMs = 400 },
}

-- playSFX's names for the audio/streams archives, in TrakLkup.dat's order, and their track counts:
-- a track ID counts through them in this order.
RadioStreams = {
    { "Police", 66 }, { "Adverts", 69 }, { "Ambience", 40 }, { "Beats", 10 }, { "Playback FM", 130 },
    { "K-Rose", 155 }, { "K-DST", 156 }, { "Cutscene", 141 }, { "Bounce FM", 179 }, { "SF-UR", 115 },
    { "Radio Los Santos", 152 }, { "Radio X", 147 }, { "CSR 103.9", 130 }, { "K-Jah West", 161 },
    { "Master Sounds 98.3", 170 }, { "WCTR", 101 },
}
