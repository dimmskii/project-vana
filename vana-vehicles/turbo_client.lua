-- The turbo's whine (config `performance.whine`): on every running car with a turbo (`vana:tune`) near
-- you, a looped game sound (the Hydra's jet by default) on top of its own engine, pitched up with its
-- speed against its top speed and louder on the throttle. /turbosound [bank sound | off] auditions.
local W = VehicleConfig.performance.whine
local playing = {} -- vehicle -> { sound, last speed }
local enabled = true

local function stop(vehicle)
    local p = playing[vehicle]
    if p and isElement(p.sound) then destroyElement(p.sound) end
    playing[vehicle] = nil
end

local function hasTurbo(vehicle)
    local tune = getElementData(vehicle, "vana:tune")
    return type(tune) == "table" and tune.turbo ~= nil
end

setTimer(function()
    local px, py, pz = getElementPosition(localPlayer)
    for vehicle in pairs(playing) do
        if not isElement(vehicle) then playing[vehicle] = nil end
    end
    for _, vehicle in ipairs(getElementsByType("vehicle", root, true)) do
        local x, y, z = getElementPosition(vehicle)
        local wanted = enabled and hasTurbo(vehicle) and getVehicleEngineState(vehicle) and not isVehicleBlown(vehicle)
            and getDistanceBetweenPoints3D(x, y, z, px, py, pz) < W.range
        if wanted and not playing[vehicle] then
            local sound = playSFX3D("genrl", W.bank, W.sound, x, y, z, true)
            if sound then
                setSoundMaxDistance(sound, W.range)
                setSoundMinDistance(sound, 4)
                setSoundVolume(sound, 0)
                setElementInterior(sound, getElementInterior(vehicle))
                setElementDimension(sound, getElementDimension(vehicle))
                attachElements(sound, vehicle)
                playing[vehicle] = { sound = sound, speed = 0 }
            end
        elseif not wanted and playing[vehicle] then
            stop(vehicle)
        end
    end
end, 300, 0)

-- Every frame: pitch with speed (against the car's own top speed), volume with throttle (the local
-- driver's accelerate control; others': speeding up).
addEventHandler("onClientPreRender", root, function(dt)
    for vehicle, p in pairs(playing) do
        if isElement(vehicle) and isElement(p.sound) then
            local vx, vy, vz = getElementVelocity(vehicle)
            local speed = (vx * vx + vy * vy + vz * vz) ^ 0.5 * 180 -- km/h-ish, the handling's units
            local top = (getVehicleHandling(vehicle) or {}).maxVelocity or 160
            local share = math.min(1, speed / math.max(1, top))
            local driver = getVehicleOccupant(vehicle, 0)
            local throttle
            if driver == localPlayer then
                throttle = getPedControlState(localPlayer, "accelerate")
            else
                throttle = speed > p.speed + 0.02 * dt / 16
            end
            p.speed = speed
            local target = (0.25 + 0.75 * share) * (throttle and 1 or 0.45) * W.volume
            p.volume = (p.volume or 0) + (target - (p.volume or 0)) * math.min(1, dt / 200)
            setSoundVolume(p.sound, p.volume)
            setSoundSpeed(p.sound, W.pitch[1] + (W.pitch[2] - W.pitch[1]) * share + (throttle and 0.08 or 0))
        end
    end
end)

addCommandHandler("turbosound", function(_, a, b)
    if a == "off" then
        enabled = false
    else
        enabled = true
        if tonumber(a) and tonumber(b) then W.bank, W.sound = tonumber(a), tonumber(b) end
    end
    for vehicle in pairs(playing) do stop(vehicle) end
    outputChatBox(enabled and ("Turbo whine: GENRL bank %d, sound %d."):format(W.bank, W.sound) or "Turbo whine off.", 200, 200, 255)
end)
