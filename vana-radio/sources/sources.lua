-- Where a station's programme comes from (config/radio.lua's `source`). Each source makes a planner:
-- planner(ctx) -> the next segments to play back to back, each { length (ms), track (a vanilla track
-- ID, played from the game's own audio) or label (no audio) , kind }. A "stream" station has no
-- planner: it plays its URL live.
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
