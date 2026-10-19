-- Where a station's programme comes from (config/radio.lua's `source`). Each source makes a planner:
-- planner(ctx) -> the next segments to play back to back, each { length (ms), track (a vanilla track
-- ID, played from the game's own audio) or label (no audio), kind, and for routines beat (vanilla's
-- beat-track number) and fade (ms) }. A "stream" station has no planner: it plays its URL live.
RadioSources = {}

function RadioSources.vanilla(def)
    local station = VanillaStation.new(def.radio)
    return function(ctx)
        local out = station:next(ctx)
        for _, seg in ipairs(out) do seg.length = RadioData.durations[seg.track + 1] end
        return out
    end
end

function RadioSources.timer(def)
    return function()
        return { { length = def.length or 180000, label = def.label or def.name, kind = "timer" } }
    end
end

-- Beat tracks as routines: each plays until its end marker (key 33, 2 s after the last beat) plus
-- the fade, never past the track's end.
function RadioSources.beats(def)
    local last, step = nil, 0
    return function()
        local beat
        if def.order == "sequence" then
            step = step % #def.beats + 1
            beat = def.beats[step]
        else
            repeat beat = def.beats[math.random(#def.beats)] until #def.beats == 1 or beat ~= last
        end
        last = beat
        local track = RadioData.beatTracks[beat + 1]
        local beats = RadioData.beats[track]
        local length = RadioData.durations[track + 1]
        if beats then length = math.min(length, beats[#beats][1] + RadioConfig.fadeMs) end
        return { { track = track, length = length, kind = "routine", beat = beat, fade = RadioConfig.fadeMs } }
    end
end
