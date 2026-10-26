-- Car radios: the game's own radio stays off; our stations play in the car (2D) and from running
-- cars nearby (muffled 3D). The radio keys run /radionext and /radioprevious (server actions).

local config = RadioConfig

---@type table? emitter for the car we're in
local inCarEmitter
---@type table<vehicle, table> emitters for cars heard from outside
local outsideEmitters = {}
local shownStation = { id = nil, at = 0 }
local hudWasVisible
--- True while we switch the game's radio off ourselves, so the switch isn't cancelled.
local switchingNative = false

---@param vehicle vehicle?
---@return integer? stationId nil for vehicles without a radio
local function stationOf(vehicle)
    local id = vehicle and getElementData(vehicle, "vana:radio")
    return type(id) == "number" and id or nil
end

---@param id integer
local function showStationName(id)
    shownStation.id, shownStation.at = id, getTickCount()
end

--- Stops the game's radio. MTA's channel can read 0 while the game still plays (setRadioPlaybackState
--- starts it), so the track manager's mode (0-2: starting, waiting, playing) is checked too.
local function silenceNativeRadio()
    local state = getRadioPlaybackState()
    if getRadioChannel() ~= 0 or (state and state.mode and state.mode <= 2) then
        switchingNative = true
        setRadioChannel(0)
        switchingNative = false
    end
end

---@param vehicle vehicle
---@param px number
---@param py number
---@param pz number
---@return number|false distance when this car's radio can be heard from (px, py, pz)
local function audibleDistance(vehicle, px, py, pz)
    if isVehicleBlown(vehicle) or not getVehicleEngineState(vehicle) then return false end
    local id = stationOf(vehicle)
    if not id or id == 0 or not Radio.byId[id] then return false end
    local distance = getDistanceBetweenPoints3D(px, py, pz, getElementPosition(vehicle))
    return distance < config.outside.range and distance
end

local function updateInCarEmitter(vehicle)
    local id = stationOf(vehicle)
    local playing = id and id ~= 0 and Radio.byId[id] and getVehicleEngineState(vehicle) and not isVehicleBlown(vehicle)
    if playing then
        inCarEmitter = inCarEmitter or Radio.addEmitter({ station = id, volume = config.car.volume })
        Radio.setEmitterStation(inCarEmitter, id)
    elseif inCarEmitter then
        Radio.removeEmitter(inCarEmitter)
        inCarEmitter = nil
    end
end

local function updateOutsideEmitters(ownVehicle)
    local px, py, pz = getElementPosition(localPlayer)
    local audible = {}
    for _, vehicle in ipairs(getElementsByType("vehicle", root, true)) do
        local distance = vehicle ~= ownVehicle and audibleDistance(vehicle, px, py, pz)
        if distance then audible[#audible + 1] = { vehicle = vehicle, distance = distance } end
    end
    table.sort(audible, function(a, b) return a.distance < b.distance end)

    local nearest = {}
    for i = 1, math.min(#audible, config.outside.nearest) do nearest[audible[i].vehicle] = true end
    for vehicle, emitter in pairs(outsideEmitters) do
        if not nearest[vehicle] or not isElement(vehicle) then
            Radio.removeEmitter(emitter)
            outsideEmitters[vehicle] = nil
        end
    end
    for vehicle in pairs(nearest) do
        local station = stationOf(vehicle)
        if outsideEmitters[vehicle] then
            Radio.setEmitterStation(outsideEmitters[vehicle], station)
        else
            local outside = config.outside
            outsideEmitters[vehicle] = Radio.addEmitter({ station = station, element = vehicle, volume = outside.volume,
                minDistance = outside.minDistance, maxDistance = outside.range, muffle = outside.muffle })
        end
    end
end

local function loadVolume()
    if not fileExists("@settings.json") then return end
    local file = fileOpen("@settings.json", true)
    if not file then return end
    local settings = fromJSON(fileRead(file, fileGetSize(file)) or "")
    fileClose(file)
    if type(settings) == "table" and type(settings.volume) == "number" then
        Radio.volume = math.max(0, math.min(1, settings.volume))
    end
end

local function saveVolume()
    local file = fileCreate("@settings.json")
    if not file then return end
    fileWrite(file, toJSON({ volume = Radio.volume }))
    fileClose(file)
end

addEventHandler("onClientPlayerRadioSwitch", localPlayer, function(channel)
    if channel ~= 0 and not switchingNative then cancelEvent() end
end)

addEventHandler("onClientPlayerVehicleEnter", localPlayer, function(vehicle)
    local id = stationOf(vehicle)
    if id then showStationName(id) end
end)

addEventHandler("onClientElementDataChange", root, function(key, old, new)
    if key == "vana:radio" and source == getPedOccupiedVehicle(localPlayer) and type(new) == "number" and new ~= old then
        showStationName(new)
    end
end)

setTimer(function()
    silenceNativeRadio()
    local vehicle = getPedOccupiedVehicle(localPlayer)
    updateInCarEmitter(vehicle)
    updateOutsideEmitters(vehicle)
end, 250, 0)

addEventHandler("onClientRender", root, function()
    if not shownStation.id or not getPedOccupiedVehicle(localPlayer) then return end
    local hud = config.hud
    local elapsed = getTickCount() - shownStation.at
    if elapsed > hud.showMs + hud.fadeMs then
        shownStation.id = nil
        return
    end
    local alpha = elapsed < hud.showMs and 255 or 255 * (1 - (elapsed - hud.showMs) / hud.fadeMs)
    local def = Radio.byId[shownStation.id]
    local colour = def and hud.colour or hud.offColour
    local text = def and def.name or "Radio Off"
    local screenWidth, screenHeight = guiGetScreenSize()
    local scale = screenHeight / 448
    local y = hud.y * scale
    dxDrawText(text, 2, y + 2, screenWidth + 2, y + 2, tocolor(0, 0, 0, alpha), hud.scale * scale, hud.font, "center", "top")
    dxDrawText(text, 0, y, screenWidth, y, tocolor(colour[1], colour[2], colour[3], alpha), hud.scale * scale, hud.font, "center", "top")
end)

-- The game's radio volume can't be read, so ours is a setting of its own.
addCommandHandler("radiovolume", function(_, value)
    local volume = tonumber(value)
    if volume then
        Radio.volume = math.max(0, math.min(100, volume)) / 100
        Radio.refreshVolume()
        saveVolume()
    end
    outputChatBox(("Radio volume: %d%s"):format(math.floor(Radio.volume * 100 + 0.5), volume and "" or " (use /radiovolume 0-100)"))
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    bindKey("radio_next", "down", "radionext")
    bindKey("radio_previous", "down", "radioprevious")
    loadVolume()
    hudWasVisible = isPlayerHudComponentVisible("radio")
    setPlayerHudComponentVisible("radio", false)
    silenceNativeRadio()
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if hudWasVisible ~= nil then setPlayerHudComponentVisible("radio", hudWasVisible) end
end)
