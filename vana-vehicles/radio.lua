-- Car radio. Each car has a station ("vana:radio", an MTA radio channel; 0 off), first picked as vanilla
-- does: one of its driver's two favourites (peds.ide), else the model's default. Stations are live:
-- one listening client (the station's leader) reports what its native radio plays, and everyone else
-- tuned in, or hearing a car's radio from outside, plays the same track at the same moment.
local stations = {}  -- channel -> { state, at, leader, external }
local listeners = {} -- player -> channel they're listening to in a car

local function call(resource, fn, ...)
    local res = getResourceFromName(resource)
    if not res or getResourceState(res) ~= "running" then return end
    local result = { pcall(function(...) return exports[resource][fn](exports[resource], ...) end, ...) }
    if result[1] then return unpack(result, 2) end
end

-- driverModel: the ped model choosing (as CPed::SetRadioStation), or nil for the model's default.
function assignRadio(vehicle, driverModel)
    if not isElement(vehicle) or getElementData(vehicle, "vana:radio") ~= false and getElementData(vehicle, "vana:radio") ~= nil then
        return false
    end
    local info = VehicleRadio[getElementModel(vehicle)]
    if not info or info[1] ~= "civilian" then return false end
    local station = info[2]
    if driverModel then
        local r1, r2 = call("vana-population", "getPedRadio", driverModel)
        local pick = math.random() < 0.5 and r1 or r2
        if pick and pick >= 1 and pick <= 11 then station = pick end
    end
    setElementData(vehicle, "vana:radio", station)
    return station
end

-- A player getting into a vehicle: its dashboard skin, chosen once (config/dashboards.lua).
addEventHandler("onVehicleEnter", root, function(player)
    if getElementType(player) ~= "player" or getElementData(source, "vana:dashboard") then return end
    local model = getElementModel(source)
    if not Dashboards.none[model] then setElementData(source, "vana:dashboard", Dashboards.models[model] or Dashboards.default) end
end)

-- A player getting into a car with no station yet takes its driver's favourite, as in vanilla.
addEventHandler("onVehicleEnter", root, function(player)
    if getElementType(player) ~= "player" then return end
    local driver = getVehicleOccupant(source, 0)
    assignRadio(source, driver and driver ~= player and getElementType(driver) == "ped" and getElementModel(driver) or nil)
end)

-- The driver chooses the station; passengers only when no player is driving.
addEvent("vana-vehicles:radioSet", true)
addEventHandler("vana-vehicles:radioSet", resourceRoot, function(vehicle, channel)
    if not isElement(vehicle) or getPedOccupiedVehicle(client) ~= vehicle or type(channel) ~= "number" then return end
    if channel < 0 or channel > 12 or channel ~= math.floor(channel) then return end
    local driver = getVehicleOccupant(vehicle, 0)
    if driver ~= client and driver and getElementType(driver) == "player" then return end
    setElementData(vehicle, "vana:radio", channel)
end)

local function copyState(s)
    if type(s) ~= "table" then return end
    local out = {}
    for _, key in ipairs({ "station", "mode", "trackId", "trackType", "trackIndex", "position", "length", "flags" }) do
        if type(s[key]) ~= "number" then return end
        out[key] = math.floor(s[key])
    end
    out.radioOn = s.radioOn ~= false
    out.queue = {}
    for i, q in ipairs(type(s.queue) == "table" and s.queue or {}) do
        if i > 16 or type(q) ~= "table" then break end
        out.queue[i] = { id = tonumber(q.id) or -1, type = tonumber(q.type) or 0, index = tonumber(q.index) or 0 }
    end
    return out
end

local function broadcast(channel, to)
    local st = stations[channel]
    if not st then return end
    triggerClientEvent(to or root, "vana-vehicles:station", resourceRoot, channel, st.state, getTickCount() - st.at, st.external, st.leader)
end

local function inCarListener(channel, except)
    for player, ch in pairs(listeners) do
        if ch == channel and player ~= except then return player end
    end
end

addEvent("vana-vehicles:listen", true)
addEventHandler("vana-vehicles:listen", resourceRoot, function(channel)
    local old = listeners[client]
    listeners[client] = type(channel) == "number" and channel or nil
    if old and old ~= channel and stations[old] and stations[old].leader == client then
        stations[old].leader = inCarListener(old)
    end
    local st = channel and stations[channel]
    -- A car listener takes over from nobody or from an outside-only leader.
    if st and (not st.leader or st.external or not isElement(st.leader)) then st.leader = client end
end)

addEvent("vana-vehicles:radioReport", true)
addEventHandler("vana-vehicles:radioReport", resourceRoot, function(channel, state, external)
    if type(channel) ~= "number" or not RadioStreams[channel] then return end
    state = copyState(state)
    if not state then return end
    external = external == true
    local st = stations[channel]
    local now = getTickCount()
    if external then
        -- Outside-only reports fill in a station nobody listens to in a car, once its last track is over.
        if inCarListener(channel) then return end
        if st and st.leader ~= client and st.state.length > 0 and st.state.position + (now - st.at) < st.state.length then return end
    else
        if listeners[client] ~= channel then return end
        if st and st.leader and st.leader ~= client and isElement(st.leader) and listeners[st.leader] == channel then return end
    end
    local expected = st and st.state.trackId == state.trackId and st.state.position + (now - st.at)
    stations[channel] = { state = state, at = now, leader = client, external = external }
    -- Everyone hears about new tracks and jumps; a steady position just refreshes the record.
    if not expected or math.abs(expected - state.position) > 3000 or (st and st.external ~= external) then broadcast(channel) end
end)

addEvent("vana-vehicles:hello", true)
addEventHandler("vana-vehicles:hello", resourceRoot, function()
    for channel in pairs(stations) do broadcast(channel, client) end
end)

addEventHandler("onPlayerQuit", root, function()
    listeners[source] = nil
    for ch, st in pairs(stations) do
        if st.leader == source then st.leader = inCarListener(ch) end
    end
end)

-- Console-only: the live stations and who leads them.
addCommandHandler("radiostatus", function(source)
    if getElementType(source) ~= "console" then return end
    local now = getTickCount()
    for channel, st in pairs(stations) do
        outputServerLog(("[radiostatus] channel %d: track %d at %ds of %ds, %s, leader %s"):format(channel, st.state.trackId,
            (st.state.position + now - st.at) / 1000, st.state.length / 1000, st.external and "outside" or "in a car",
            isElement(st.leader) and getPlayerName(st.leader) or "none"))
    end
    for player, channel in pairs(listeners) do
        outputServerLog(("[radiostatus] %s listens to channel %d"):format(getPlayerName(player), channel))
    end
    if not next(stations) then outputServerLog("[radiostatus] no live stations yet") end
    for _, player in ipairs(getElementsByType("player")) do
        local vehicle = getPedOccupiedVehicle(player)
        outputServerLog(("[radiostatus] %s: %s"):format(getPlayerName(player), vehicle and ("in a %s, station %s, seat %d"):format(
            getVehicleName(vehicle), tostring(getElementData(vehicle, "vana:radio")), getPedOccupiedVehicleSeat(player)) or "on foot"))
    end
end)
