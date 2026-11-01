-- Plans every station on the server clock and sends the schedule to clients (docs/radio.md).

local config = RadioConfig

---@class Segment
---@field at integer start time on the server clock (getTickCount)
---@field length integer duration in ms
---@field track integer? vanilla track ID, played from the game's audio
---@field label string? name of a segment without audio
---@field kind string "body", "intro", "advert", "routine", ...
---@field beat integer? vanilla beat-track number (routines)
---@field fade integer? fade-out at the end, ms (routines)

---@class Station
---@field def table the station's entry in RadioConfig.stations
---@field plan fun(context: table): Segment[] | nil nil for streams
---@field segments Segment[]
---@field url string? stream URL

---@type table<integer, Station>
local stations = {}
---@type table<player, true>
local listeners = {}
---@type table<player, integer>
local lastPing = {}

--- Station IDs the car radio steps through, in order, ending with 0 (off).
local carStations = {}
for _, def in ipairs(config.stations) do
    if not def.hidden then carStations[#carStations + 1] = def.id end
end
carStations[#carStations + 1] = 0

--- What vanilla's DJ banter depends on.
local context = {
    hour = 0,
    weather = function(id)
        local current, blendingTo = getWeather()
        return current == id or blendingTo == id
    end,
}

---@return player[]
local function listenerList()
    local list = {}
    for player in pairs(listeners) do list[#list + 1] = player end
    return list
end

--- Plans a station at least `config.aheadMs` ahead and one segment past the current one, and
--- drops segments that finished more than 5 s ago.
---@param station Station
---@param now integer
---@return Segment[] added
local function extend(station, now)
    local added = {}
    local last = station.segments[#station.segments]
    local cursor = last and last.at + last.length or now
    local upcoming = 0
    for _, segment in ipairs(station.segments) do
        if segment.at > now then upcoming = upcoming + 1 end
    end
    context.hour = getTime()
    local emptyPlans = 0
    while (cursor < now + config.aheadMs or upcoming < 1) and emptyPlans < 10 do
        local planned = station.plan(context)
        if #planned == 0 then emptyPlans = emptyPlans + 1 end
        for _, segment in ipairs(planned) do
            if segment.length and segment.length > 0 then
                segment.at = cursor
                if cursor > now then upcoming = upcoming + 1 end
                cursor = cursor + segment.length
                station.segments[#station.segments + 1] = segment
                added[#added + 1] = segment
            end
        end
    end
    while station.segments[1] and station.segments[1].at + station.segments[1].length < now - 5000 do
        table.remove(station.segments, 1)
    end
    return added
end

---@param def table
local function startStation(def)
    local station = { def = def, segments = {}, url = def.url }
    if def.source ~= "stream" then
        local makePlanner = RadioSources[def.source]
        if not makePlanner then
            outputDebugString(("[vana-radio] station %d (%s): unknown source %q"):format(def.id, def.name, tostring(def.source)), 1)
            return
        end
        station.plan = makePlanner(def)
        extend(station, getTickCount())
        -- Start part way into the first segment, as if the station had been on the air already.
        local first = station.segments[1]
        local shift = first and math.floor(first.length * math.random() * 0.8) or 0
        for _, segment in ipairs(station.segments) do segment.at = segment.at - shift end
    end
    stations[def.id] = station
end

--- The car radio's next station after `current`.
---@param current integer
---@param direction integer 1 or -1
---@return integer
local function stepStation(current, direction)
    local index = 1
    for i, id in ipairs(carStations) do
        if id == current then index = i end
    end
    return carStations[(index - 1 + direction) % #carStations + 1]
end

---@param player player
---@param vehicle vehicle
---@return boolean
local function isDriving(player, vehicle)
    return getPedOccupiedVehicle(player) == vehicle and getPedOccupiedVehicleSeat(player) == 0
end

---@param vehicle vehicle
---@return boolean
local function hasRadio(vehicle)
    return type(getElementData(vehicle, "vana:radio")) == "number"
end

--- Adds the action that steps the car radio one way. Clients show the new station's name when the
--- car's `vana:radio` changes.
---@param name string
---@param direction integer 1 or -1
---@param summary string
local function addStationAction(name, direction, summary)
    Actions.add{
        name = name, label = summary, usage = "", summary = summary .. " (driver)",
        targets = { "vehicle" }, inside = true,
        accepts = hasRadio,
        available = isDriving,
        run = function(player, vehicle)
            if not isDriving(player, vehicle) then return false, "Only the driver can do that." end
            setElementData(vehicle, "vana:radio", stepStation(getElementData(vehicle, "vana:radio"), direction))
        end,
    }
end

addStationAction("radionext", 1, "Next radio station")
addStationAction("radioprevious", -1, "Previous radio station")

addEventHandler("onResourceStart", resourceRoot, function()
    for _, def in ipairs(config.stations) do startStation(def) end
end)

setTimer(function()
    local now = getTickCount()
    local players = listenerList()
    for id, station in pairs(stations) do
        if station.plan then
            local added = extend(station, now)
            if #added > 0 and #players > 0 then
                triggerClientEvent(players, "vana-radio:segments", resourceRoot, id, added)
            end
        end
    end
end, 1000, 0)

addEvent("vana-radio:hello", true)
addEventHandler("vana-radio:hello", resourceRoot, function()
    listeners[client] = true
    local schedule = {}
    for id, station in pairs(stations) do schedule[id] = { segments = station.segments, url = station.url } end
    triggerClientEvent(client, "vana-radio:schedule", resourceRoot, schedule, Speakers or {})
end)

addEvent("vana-radio:ping", true)
addEventHandler("vana-radio:ping", resourceRoot, function(sentAt)
    local now = getTickCount()
    if type(sentAt) ~= "number" or (lastPing[client] and now - lastPing[client] < 200) then return end
    lastPing[client] = now
    triggerClientEvent(client, "vana-radio:pong", resourceRoot, sentAt, now)
end)

addEventHandler("onPlayerQuit", root, function()
    listeners[source], lastPing[source] = nil, nil
end)

--- Export: what a station is playing now.
---@param id integer
---@return integer|string|false track the track ID or label, or false
---@return integer? position ms into it
---@return string? kind
---@return integer? length
---@return string? url for a stream station
function getStationNow(id)
    local station = stations[id]
    if not station then return false end
    if station.url then return false, 0, "stream", 0, station.url end
    local now = getTickCount()
    for _, segment in ipairs(station.segments) do
        if now >= segment.at and now < segment.at + segment.length then
            return segment.track or segment.label, now - segment.at, segment.kind, segment.length
        end
    end
    return false
end

--- Export: a station's segments from the current one on.
---@param id integer
---@return Segment[]|false
function getStationSegments(id)
    local station = stations[id]
    if not station then return false end
    local now, upcoming = getTickCount(), {}
    for _, segment in ipairs(station.segments) do
        if segment.at + segment.length > now then
            upcoming[#upcoming + 1] = { track = segment.track, at = segment.at, length = segment.length,
                                        kind = segment.kind, beat = segment.beat }
        end
    end
    return upcoming
end

--- Export: a beat track's beats, { { ms, key }, ... } (keys: docs/radio.md).
---@param track integer
---@return table|false
function getBeats(track)
    return RadioData.beats[track] or false
end

addCommandHandler("radiostatus", function(source)
    if getElementType(source) ~= "console" then return end
    local now = getTickCount()
    for _, def in ipairs(config.stations) do
        local station = stations[def.id]
        local line = ("[radiostatus] %d %s (%s):"):format(def.id, def.name, def.source)
        if station and station.url then
            line = line .. " " .. station.url
        elseif station then
            for _, segment in ipairs(station.segments) do
                if segment.at + segment.length > now then
                    line = line .. (" %s %s %+ds/%ds;"):format(segment.kind, tostring(segment.track or segment.label),
                        math.floor((now - segment.at) / 1000), math.floor(segment.length / 1000))
                end
            end
        end
        outputServerLog(line)
    end
    outputServerLog("[radiostatus] " .. #listenerList() .. " clients listening")
end)
