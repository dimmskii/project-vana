-- Car radio (live stations: in the car through the native radio, from outside as muffled 3D sound)
-- and the fuel gauge.
local R, F = VehicleConfig.radio, VehicleConfig.fuel
local live = {}     -- channel -> { state, age, at (receipt tick), external, leader }
local outside = {}  -- vehicle -> { sound, channel, trackId }
local car = { vehicle = nil, channel = nil, enteredAt = 0, applying = false, lastTrack = nil, lastReport = 0 }
local refuel = { active = false, text = nil, shownUntil = 0 }

-- Native track IDs count through every stream archive in order: the archive and 1-based track in it.
local firstTrack = {}
do
    local id = 0
    for stream, count in ipairs(RadioStreamTracks) do
        firstTrack[stream - 1] = id
        id = id + count
    end
end

local function streamOf(trackId)
    for stream = #RadioStreamTracks - 1, 0, -1 do
        if trackId >= firstTrack[stream] then
            local index = trackId - firstTrack[stream] + 1
            return index <= RadioStreamTracks[stream + 1] and stream or nil, index
        end
    end
end

local function stationRadio(vehicle)
    local info = VehicleRadio[getElementModel(vehicle)]
    return info and info[1] == "civilian"
end

-- Where a live station is now, or nil once its last known track is over.
local function livePosition(channel)
    local st = live[channel]
    if not st then return end
    local position = st.state.position + st.age + (getTickCount() - st.at)
    if st.state.length > 0 and position >= st.state.length - 250 then return end
    return position, st
end

----------------------------------------------------------------------------------------------------
-- In the car

local function listen(channel)
    if car.listening == channel then return end
    car.listening = channel
    triggerServerEvent("vana-vehicles:listen", resourceRoot, channel or false)
end

-- Tune the native radio into the live station (unless this client is the one setting it).
local function tuneLive(channel)
    local position, st = livePosition(channel)
    if not position or st.external or st.leader == localPlayer then return end
    local s = {}
    for k, v in pairs(st.state) do s[k] = v end
    s.station, s.position = channel, math.floor(position)
    setRadioPlaybackState(s)
    car.lastTrack = s.trackId
end

local function applyStation(vehicle)
    local channel = getElementData(vehicle, "vana:radio")
    if type(channel) ~= "number" or not stationRadio(vehicle) then return end
    car.channel = channel
    car.applying = true
    setRadioChannel(channel)
    car.applying = false
    if RadioStreams[channel] then
        listen(channel)
        tuneLive(channel)
    else
        listen(nil)
    end
end

addEventHandler("onClientPlayerVehicleEnter", localPlayer, function(vehicle)
    car.vehicle, car.enteredAt, car.channel = vehicle, getTickCount(), nil
    -- After the native radio has started for the car.
    setTimer(function()
        if car.vehicle == vehicle and isElement(vehicle) then applyStation(vehicle) end
    end, 300, 1)
end)

addEventHandler("onClientPlayerVehicleExit", localPlayer, function()
    car.vehicle, car.channel = nil, nil
    listen(nil)
end)

addEventHandler("onClientPlayerWasted", localPlayer, function()
    car.vehicle, car.channel = nil, nil
    listen(nil)
end)

addEventHandler("onClientPlayerRadioSwitch", localPlayer, function(channel)
    local vehicle = getPedOccupiedVehicle(localPlayer)
    if car.applying or not vehicle or vehicle ~= car.vehicle then return end
    -- The native radio picks its own station as the car starts; ours follows straight after.
    if getTickCount() - car.enteredAt < 1000 then return end
    local driver = getVehicleOccupant(vehicle, 0)
    if driver and driver ~= localPlayer and getElementType(driver) == "player" then
        cancelEvent() -- the driver has the say
        return
    end
    car.channel = channel
    triggerServerEvent("vana-vehicles:radioSet", resourceRoot, vehicle, channel)
    listen(RadioStreams[channel] and channel or nil)
    if RadioStreams[channel] then setTimer(tuneLive, 100, 1, channel) end
end)

addEventHandler("onClientElementDataChange", root, function(key, _, new)
    if key == "vana:radio" and source == car.vehicle and new ~= car.channel and type(new) == "number" then
        applyStation(source)
    end
end)

-- Report what the native radio plays: the server keeps it if this client leads the station.
setTimer(function()
    local channel = car.vehicle and car.channel
    if not channel or not RadioStreams[channel] or getRadioChannel() ~= channel then return end
    local s = getRadioPlaybackState()
    if not s or s.trackId < 0 then return end
    local now = getTickCount()
    if s.trackId ~= car.lastTrack or now - car.lastReport > R.reportMs then
        car.lastTrack, car.lastReport = s.trackId, now
        triggerServerEvent("vana-vehicles:radioReport", resourceRoot, channel, s, false)
    end
end, 1000, 0)

----------------------------------------------------------------------------------------------------
-- Outside: a running car's radio, muffled, in sync with the station

local function stopOutside(vehicle)
    local o = outside[vehicle]
    if o and isElement(o.sound) then destroyElement(o.sound) end
    outside[vehicle] = nil
end

local function playOutside(vehicle, channel, trackId, position)
    stopOutside(vehicle)
    local stream, index = streamOf(trackId)
    if not stream then return end
    local x, y, z = getElementPosition(vehicle)
    local sound = playSFX3D("radio", stream, index, x, y, z, false)
    if not sound then return end
    setSoundMinDistance(sound, 3)
    setSoundMaxDistance(sound, R.outsideRange)
    setSoundVolume(sound, R.outsideVolume)
    setSoundEffectEnabled(sound, "parameq", true)
    for key, value in pairs(R.muffle) do setSoundEffectParameter(sound, "parameq", key, value) end
    setElementInterior(sound, getElementInterior(vehicle))
    setElementDimension(sound, getElementDimension(vehicle))
    attachElements(sound, vehicle)
    if position and position > 0 then setSoundPosition(sound, position / 1000) end
    outside[vehicle] = { sound = sound, channel = channel, trackId = trackId }
    return sound
end

-- Nobody listens in a car and the last track is over: pick one from the station's own archive
-- and tell the server, so others outside hear the same.
local function pickTrack(vehicle, channel)
    local stream = RadioStreams[channel]
    local trackId = firstTrack[stream] + math.random(0, RadioStreamTracks[stream + 1] - 1)
    local sound = playOutside(vehicle, channel, trackId, 0)
    if not sound then return end
    local length = math.floor((getSoundLength(sound) or 0) * 1000)
    if length <= 0 then length = 180000 end
    local state = { station = channel, mode = 0, trackId = trackId, trackType = 0, trackIndex = 0, position = 0,
                    length = length, flags = 0, queue = {} }
    live[channel] = { state = state, age = 0, at = getTickCount(), external = true, leader = localPlayer }
    triggerServerEvent("vana-vehicles:radioReport", resourceRoot, channel, state, true)
end

local function audible(vehicle, px, py, pz)
    if vehicle == getPedOccupiedVehicle(localPlayer) or isVehicleBlown(vehicle) or not getVehicleEngineState(vehicle) then return false end
    local channel = getElementData(vehicle, "vana:radio")
    if type(channel) ~= "number" or not RadioStreams[channel] or not stationRadio(vehicle) then return false end
    local x, y, z = getElementPosition(vehicle)
    return getDistanceBetweenPoints3D(x, y, z, px, py, pz) < R.outsideRange and channel
end

setTimer(function()
    local px, py, pz = getElementPosition(localPlayer)
    for vehicle in pairs(outside) do
        if not isElement(vehicle) or not audible(vehicle, px, py, pz) then stopOutside(vehicle) end
    end
    for _, vehicle in ipairs(getElementsByType("vehicle", root, true)) do
        local channel = audible(vehicle, px, py, pz)
        if channel then
            local o = outside[vehicle]
            local position, st = livePosition(channel)
            if not position then
                pickTrack(vehicle, channel)
            elseif not o or o.channel ~= channel or o.trackId ~= st.state.trackId or not isElement(o.sound) then
                playOutside(vehicle, channel, st.state.trackId, position)
            end
        end
    end
end, 500, 0)

addEvent("vana-vehicles:station", true)
addEventHandler("vana-vehicles:station", resourceRoot, function(channel, state, age, external, leader)
    live[channel] = { state = state, age = age or 0, at = getTickCount(), external = external, leader = leader }
    if car.vehicle and car.channel == channel and getRadioChannel() == channel and leader ~= localPlayer and not external then
        tuneLive(channel)
    end
    -- Outside radios on this station jump to the new track.
    local position = livePosition(channel)
    for vehicle, o in pairs(outside) do
        if o.channel == channel and o.trackId ~= state.trackId and isElement(vehicle) then
            playOutside(vehicle, channel, state.trackId, position)
        end
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    triggerServerEvent("vana-vehicles:hello", resourceRoot)
    local vehicle = getPedOccupiedVehicle(localPlayer)
    if vehicle then
        car.vehicle, car.enteredAt = vehicle, getTickCount() - 1000
        applyStation(vehicle)
    end
end)

----------------------------------------------------------------------------------------------------
-- Fuel gauge, above the radar (where vanilla draws nothing in a car)

local function sx(v) return v * (select(2, guiGetScreenSize()) / 720) end

addEvent("vana-vehicles:refuel", true)
addEventHandler("vana-vehicles:refuel", resourceRoot, function(active, paid, text)
    refuel.active = active
    if not active then
        refuel.text = text or (paid and paid > 0 and ("Refuelled: $" .. paid)) or nil
        refuel.shownUntil = getTickCount() + 3000
    end
end)

addEventHandler("onClientRender", root, function()
    local vehicle = getPedOccupiedVehicle(localPlayer)
    local fuel = vehicle and getElementData(vehicle, "vana:fuel")
    if not fuel or not F.enabled or isPlayerMapVisible() then return end
    local W, H = guiGetScreenSize()
    -- The radar sits at (40, 344) in vanilla's 640x448 HUD space, 94 x 76.
    local x, w = W * 40 / 640, W * 94 / 640
    local y, h = H * (448 - 104) / 448 - sx(16), sx(7)
    local share = math.max(0, math.min(1, fuel / F.tank))
    dxDrawRectangle(x - 1, y - 1, w + 2, h + 2, tocolor(0, 0, 0, 200))
    local colour = fuel < F.low and tocolor(200, 50, 40, 230) or tocolor(220, 180, 60, 230)
    dxDrawRectangle(x, y, w * share, h, colour)
    dxDrawText("FUEL", x, y - sx(16), x + w, y, tocolor(220, 220, 220, 230), sx(0.9), "default-bold", "left", "bottom")
    if refuel.active then
        dxDrawText("Refuelling...", 0, H * 0.7, W, H * 0.75, tocolor(255, 255, 255), sx(1.4), "default-bold", "center", "center")
    elseif refuel.text and getTickCount() < refuel.shownUntil then
        dxDrawText(refuel.text, 0, H * 0.7, W, H * 0.75, tocolor(255, 255, 255), sx(1.4), "default-bold", "center", "center")
    end
end)
