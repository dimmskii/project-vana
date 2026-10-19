-- The stations' one source of truth: each is planned ahead as segments with absolute start times on
-- the server's clock (getTickCount), sent to every client; clients measure their offset from that
-- clock and play whatever is due, wherever they hear it (docs/radio.md).
local R = RadioConfig
local stations = {} -- id -> { def, plan, segments = { { at, length, track | label, kind } }, url }
local ready = {}    -- player -> true once their client has said hello
local lastPing = {}

local function readyList()
    local list = {}
    for player in pairs(ready) do list[#list + 1] = player end
    return list
end

-- What vanilla's banter looks at: the hour and the weather due (the current one or the one it's
-- blending into).
local context = {
    weather = function(id)
        local now, blending = getWeather()
        return now == id or blending == id
    end,
}

-- Plans the station until aheadMs from now, and at least one segment after the playing one (so
-- activities can join the next routine); returns the new segments.
local function extend(st, now)
    local added = {}
    local last = st.segments[#st.segments]
    local t = last and last.at + last.length or now
    local upcoming = 0
    for _, seg in ipairs(st.segments) do if seg.at > now then upcoming = upcoming + 1 end end
    local empty = 0
    context.hour = getTime()
    while (t < now + R.aheadMs or upcoming < 1) and empty < 10 do
        local segs = st.plan(context)
        if #segs == 0 then empty = empty + 1 end
        for _, seg in ipairs(segs) do
            if seg.length and seg.length > 0 then
                seg.at = t
                if t > now then upcoming = upcoming + 1 end
                t = t + seg.length
                st.segments[#st.segments + 1] = seg
                added[#added + 1] = seg
            end
        end
    end
    -- Forget what has finished.
    while st.segments[1] and st.segments[1].at + st.segments[1].length < now - 5000 do table.remove(st.segments, 1) end
    return added
end

local function start(def)
    local st = { def = def, segments = {}, url = def.url }
    if def.source ~= "stream" then
        local make = RadioSources[def.source]
        if not make then
            outputDebugString(("[vana-radio] station %d (%s): unknown source %q"):format(def.id, def.name, tostring(def.source)), 1)
            return
        end
        st.plan = make(def)
        -- On the air for a while already: join the first segment part way through.
        local now = getTickCount()
        extend(st, now)
        local first = st.segments[1]
        local shift = first and math.floor(first.length * math.random() * 0.8) or 0
        for _, seg in ipairs(st.segments) do seg.at = seg.at - shift end
    end
    stations[def.id] = st
end

addEventHandler("onResourceStart", resourceRoot, function()
    for _, def in ipairs(R.stations) do start(def) end
end)

setTimer(function()
    local now = getTickCount()
    local players = readyList()
    for id, st in pairs(stations) do
        if st.plan then
            local added = extend(st, now)
            if #added > 0 and #players > 0 then triggerClientEvent(players, "vana-radio:segments", resourceRoot, id, added) end
        end
    end
end, 1000, 0)

-- A client starting: the whole schedule so far.
addEvent("vana-radio:hello", true)
addEventHandler("vana-radio:hello", resourceRoot, function()
    ready[client] = true
    local all = {}
    for id, st in pairs(stations) do all[id] = { segments = st.segments, url = st.url } end
    triggerClientEvent(client, "vana-radio:schedule", resourceRoot, all, Speakers or {})
end)

-- Clock sync: the client measures its offset from the round trip.
addEvent("vana-radio:ping", true)
addEventHandler("vana-radio:ping", resourceRoot, function(sent)
    local now = getTickCount()
    if type(sent) ~= "number" or (lastPing[client] and now - lastPing[client] < 200) then return end
    lastPing[client] = now
    triggerClientEvent(client, "vana-radio:pong", resourceRoot, sent, now)
end)

addEventHandler("onPlayerQuit", root, function()
    ready[source], lastPing[source] = nil, nil
end)

-- Retuning a car: the driver chooses; passengers only when no player drives. Vehicles without a
-- station (vana-vehicles gives one only to cars with a radio) can't be tuned.
addEvent("vana-radio:tune", true)
addEventHandler("vana-radio:tune", resourceRoot, function(vehicle, id)
    if type(id) ~= "number" or (id ~= 0 and (not stations[id] or stations[id].def.hidden)) then return end
    if not isElement(vehicle) or getPedOccupiedVehicle(client) ~= vehicle then return end
    if type(getElementData(vehicle, "vana:radio")) ~= "number" then return end
    local driver = getVehicleOccupant(vehicle, 0)
    if driver and driver ~= client and getElementType(driver) == "player" then return end
    setElementData(vehicle, "vana:radio", id)
end)

-- For other resources (music zones, activities): what a station plays now. Returns the track ID (or
-- the label), how far into it (ms), its kind and its length; or the URL of a stream station.
function getStationNow(id)
    local st = stations[id]
    if not st then return false end
    if st.url then return false, 0, "stream", 0, st.url end
    local now = getTickCount()
    for _, seg in ipairs(st.segments) do
        if now >= seg.at and now < seg.at + seg.length then
            return seg.track or seg.label, now - seg.at, seg.kind, seg.length
        end
    end
    return false
end

-- A station's segments from the one playing now on: { track, at (getTickCount: the same clock in
-- every resource), length, kind, beat }.
function getStationSegments(id)
    local st = stations[id]
    if not st then return false end
    local now, out = getTickCount(), {}
    for _, seg in ipairs(st.segments) do
        if seg.at + seg.length > now then
            out[#out + 1] = { track = seg.track, at = seg.at, length = seg.length, kind = seg.kind, beat = seg.beat }
        end
    end
    return out
end

-- A beat track's beats: { { ms, key }, ... } (keys: docs/radio.md), or false.
function getBeats(track)
    return RadioData.beats[track] or false
end

-- Console-only: every station's current and next segments.
addCommandHandler("radiostatus", function(source)
    if getElementType(source) ~= "console" then return end
    local now = getTickCount()
    for _, def in ipairs(R.stations) do
        local st = stations[def.id]
        local line = ("[radiostatus] %d %s (%s):"):format(def.id, def.name, def.source)
        if st and st.url then
            line = line .. " " .. st.url
        elseif st then
            for _, seg in ipairs(st.segments) do
                if seg.at + seg.length > now then
                    line = line .. (" %s %s %+ds/%ds;"):format(seg.kind, tostring(seg.track or seg.label),
                        math.floor((now - seg.at) / 1000), math.floor(seg.length / 1000))
                end
            end
        end
        outputServerLog(line)
    end
    local n = 0
    for _ in pairs(ready) do n = n + 1 end
    outputServerLog("[radiostatus] " .. n .. " clients listening")
end)
