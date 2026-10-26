-- Station sources (RadioConfig.stations[].source). Each makes a planner that returns the next
-- segments to play back to back. "stream" stations have no planner: they play their URL live.

---@alias Planner fun(context: table): Segment[]

---@type table<string, fun(def: table): Planner>
RadioSources = {}

--- Vanilla's programme from the game's own audio.
---@param def table
---@return Planner
function RadioSources.vanilla(def)
    local station = VanillaStation.new(def.radio)
    return function(context)
        local segments = station:next(context)
        for _, segment in ipairs(segments) do segment.length = RadioData.durations[segment.track + 1] end
        return segments
    end
end

--- Silent segments of a fixed length, for testing.
---@param def table
---@return Planner
function RadioSources.timer(def)
    return function()
        return { { length = def.length or 180000, label = def.label or def.name, kind = "timer" } }
    end
end

--- Vanilla's beat tracks as dance routines. Each plays to its end marker (key 33, 2 s after the last
--- beat) plus the fade, never past the track's end.
---@param def table
---@return Planner
function RadioSources.beats(def)
    local lastBeat, sequenceIndex = nil, 0
    return function()
        local beat
        if def.order == "sequence" then
            sequenceIndex = sequenceIndex % #def.beats + 1
            beat = def.beats[sequenceIndex]
        else
            repeat beat = def.beats[math.random(#def.beats)] until #def.beats == 1 or beat ~= lastBeat
        end
        lastBeat = beat
        local track = RadioData.beatTracks[beat + 1]
        local beats = RadioData.beats[track]
        local length = RadioData.durations[track + 1]
        if beats then length = math.min(length, beats[#beats][1] + RadioConfig.fadeMs) end
        return { { track = track, length = length, kind = "routine", beat = beat, fade = RadioConfig.fadeMs } }
    end
end
