-- Car radios: the native radio stays off for good (channel 0, its HUD hidden, its switching
-- cancelled); the radio switch keys tune the car to our stations instead, played in the car as 2D
-- and from running cars nearby as muffled 3D (client/player.lua). The station's name shows as
-- vanilla's does.
local R = RadioConfig
local order = {} -- switching order: the stations, then off
for _, def in ipairs(R.stations) do order[#order + 1] = def.id end
order[#order + 1] = 0

local inCar           -- the emitter for the car we're in
local outside = {}    -- vehicle -> emitter
local shown = { id = nil, at = 0 }
local hudWasVisible
local switching = false -- our own setRadioChannel(0)

local function stationOf(vehicle)
    local id = vehicle and getElementData(vehicle, "vana:radio")
    return type(id) == "number" and id or nil
end

local function showName(id)
    shown.id, shown.at = id, getTickCount()
end

----------------------------------------------------------------------------------------------------
-- The native radio: off, quietly

addEventHandler("onClientPlayerRadioSwitch", localPlayer, function(channel)
    if channel ~= 0 and not switching then cancelEvent() end
end)

local function nativeOff()
    if getRadioChannel() ~= 0 then
        switching = true
        setRadioChannel(0)
        switching = false
    end
end

----------------------------------------------------------------------------------------------------
-- Switching: the radio keys step through our stations (the driver's say; passengers only when no
-- player drives). The server checks the same and sets the car's station.

local function canTune(vehicle)
    local driver = getVehicleOccupant(vehicle, 0)
    return not driver or driver == localPlayer or getElementType(driver) ~= "player"
end

local pending -- { vehicle, id, at }: asked for, not yet set by the server

local function step(dir)
    local vehicle = getPedOccupiedVehicle(localPlayer)
    local current = stationOf(vehicle)
    if not current or not canTune(vehicle) or isCursorShowing() then return end
    -- Several presses in a row step on from the last one asked for.
    if pending and pending.vehicle == vehicle and getTickCount() - pending.at < 2000 then current = pending.id end
    local at = 1
    for i, id in ipairs(order) do if id == current then at = i end end
    local id = order[(at - 1 + dir) % #order + 1]
    pending = { vehicle = vehicle, id = id, at = getTickCount() }
    triggerServerEvent("vana-radio:tune", resourceRoot, vehicle, id)
    showName(id)
end

bindKey("radio_next", "down", function() step(1) end)
bindKey("radio_previous", "down", function() step(-1) end)

addEventHandler("onClientPlayerVehicleEnter", localPlayer, function(vehicle)
    local id = stationOf(vehicle)
    if id then showName(id) end
end)

-- The station arriving after we got in (the server picks it as we enter).
addEventHandler("onClientElementDataChange", root, function(key, old, new)
    if key == "vana:radio" and source == getPedOccupiedVehicle(localPlayer) and old == nil and type(new) == "number" then showName(new) end
end)

----------------------------------------------------------------------------------------------------
-- Who plays what: the car we're in, and the nearest running cars outside

local function audibleOutside(vehicle, px, py, pz)
    if isVehicleBlown(vehicle) or not getVehicleEngineState(vehicle) then return end
    local id = stationOf(vehicle)
    if not id or id == 0 or not Radio.byId[id] then return end
    local x, y, z = getElementPosition(vehicle)
    local d = getDistanceBetweenPoints3D(x, y, z, px, py, pz)
    return d < R.outside.range and d
end

setTimer(function()
    nativeOff()
    local mine = getPedOccupiedVehicle(localPlayer)
    local id = stationOf(mine)
    if id and id ~= 0 and Radio.byId[id] and getVehicleEngineState(mine) and not isVehicleBlown(mine) then
        if not inCar then inCar = Radio.addEmitter({ station = id, volume = R.car.volume }) end
        Radio.setEmitterStation(inCar, id)
    elseif inCar then
        Radio.removeEmitter(inCar)
        inCar = nil
    end

    local px, py, pz = getElementPosition(localPlayer)
    local near = {}
    for _, vehicle in ipairs(getElementsByType("vehicle", root, true)) do
        local d = vehicle ~= mine and audibleOutside(vehicle, px, py, pz)
        if d then near[#near + 1] = { vehicle, d } end
    end
    table.sort(near, function(a, b) return a[2] < b[2] end)
    local keep = {}
    for i = 1, math.min(#near, R.outside.nearest) do keep[near[i][1]] = true end
    for vehicle, e in pairs(outside) do
        if not keep[vehicle] or not isElement(vehicle) then
            Radio.removeEmitter(e)
            outside[vehicle] = nil
        end
    end
    for vehicle in pairs(keep) do
        local station = stationOf(vehicle)
        if outside[vehicle] then
            Radio.setEmitterStation(outside[vehicle], station)
        else
            local o = R.outside
            outside[vehicle] = Radio.addEmitter({ station = station, element = vehicle, volume = o.volume,
                minDistance = o.minDistance, maxDistance = o.range, muffle = o.muffle })
        end
    end
end, 250, 0)

----------------------------------------------------------------------------------------------------
-- The station's name, top centre (vanilla shows it on getting in and on every switch)

addEventHandler("onClientRender", root, function()
    if not shown.id or not getPedOccupiedVehicle(localPlayer) then return end
    local H = R.hud
    local t = getTickCount() - shown.at
    if t > H.showMs + H.fadeMs then
        shown.id = nil
        return
    end
    local alpha = t < H.showMs and 255 or 255 * (1 - (t - H.showMs) / H.fadeMs)
    local def = Radio.byId[shown.id]
    local c = def and H.colour or H.offColour
    local W, Hs = guiGetScreenSize()
    local k = Hs / 448
    local y = H.y * k
    local text = def and def.name or "Radio Off"
    dxDrawText(text, 2, y + 2, W + 2, y + 2, tocolor(0, 0, 0, alpha), H.scale * k, H.font, "center", "top")
    dxDrawText(text, 0, y, W, y, tocolor(c[1], c[2], c[3], alpha), H.scale * k, H.font, "center", "top")
end)

----------------------------------------------------------------------------------------------------
-- Volume: the game's radio volume can't be read, so ours is a setting (/radiovolume 0-100).

local SETTINGS = "@settings.json"

local function loadVolume()
    if not fileExists(SETTINGS) then return end
    local f = fileOpen(SETTINGS, true)
    if not f then return end
    local data = fromJSON(fileRead(f, fileGetSize(f)) or "")
    fileClose(f)
    if type(data) == "table" and type(data.volume) == "number" then Radio.volume = math.max(0, math.min(1, data.volume)) end
end

local function saveVolume()
    local f = fileCreate(SETTINGS)
    if not f then return end
    fileWrite(f, toJSON({ volume = Radio.volume }))
    fileClose(f)
end

addCommandHandler("radiovolume", function(_, value)
    local v = tonumber(value)
    if not v then
        outputChatBox(("Radio volume: %d (use /radiovolume 0-100)"):format(math.floor(Radio.volume * 100 + 0.5)))
        return
    end
    Radio.volume = math.max(0, math.min(100, v)) / 100
    Radio.refreshVolume()
    saveVolume()
    outputChatBox(("Radio volume set to %d"):format(math.floor(Radio.volume * 100 + 0.5)))
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    loadVolume()
    hudWasVisible = isPlayerHudComponentVisible("radio")
    setPlayerHudComponentVisible("radio", false)
    nativeOff()
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if hudWasVisible ~= nil then setPlayerHudComponentVisible("radio", hudWasVisible) end
end)
