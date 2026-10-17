-- Executes the server's drive targets with GTA's native drive-to task. Decisions (route, light
-- stops, encounters) stay on the server; native lights are ignored so the server's synced lights
-- are the only authority.
local commands = {}  -- vehicle -> { ped, x, y, z, speed, mode, style, prepared }
local lastCollision = {}

local function ready(cmd, vehicle)
    local ped = cmd.ped
    return isElement(ped) and isElementStreamedIn(ped) and isElementStreamedIn(vehicle)
        and isElementSyncer(ped) and isElementSyncer(vehicle)
        and getPedOccupiedVehicle(ped) == vehicle and getPedOccupiedVehicleSeat(ped) == 0
end

local function prepare(cmd, vehicle)
    -- Occupants run as mission actors while seated: no ambient event responses mid-drive.
    for _, occupant in pairs(getVehicleOccupants(vehicle) or {}) do
        if getElementType(occupant) == "ped" and getElementData(occupant, "vana:traffic") then setPedMissionActor(occupant, true) end
    end
    -- Mission-car collision policy: ghost instead of falling when far-away road collision unloads.
    setVehicleLoadCollisionFlag(vehicle, false)
    killPedTask(cmd.ped, "primary", 3, false)
    -- The server stops units by their front bumper, so tell it where that is for this model.
    local _, _, _, _, maxY = getElementBoundingBox(vehicle)
    if maxY then triggerServerEvent("vana-traffic:front", resourceRoot, vehicle, maxY) end
    -- Enter the world already rolling, as vanilla ambient traffic does (velocity is per 1/50 s).
    if getVehicleEngineState(vehicle) == false then setVehicleEngineState(vehicle, true) end
    local m = getElementMatrix(vehicle)
    local rolling = cmd.speed * 0.5 / 50
    setElementVelocity(vehicle, m[2][1] * rolling, m[2][2] * rolling, 0)
    cmd.prepared = true
end

local function apply(vehicle)
    local cmd = commands[vehicle]
    if not cmd or not isElement(vehicle) then commands[vehicle] = nil return end
    if not ready(cmd, vehicle) then
        -- Ownership and streaming arrive asynchronously; keep trying for a while.
        if getTickCount() - cmd.since < 10000 and not isTimer(cmd.retry) then
            cmd.retry = setTimer(apply, 200, 1, vehicle)
        end
        return
    end
    if not cmd.prepared then prepare(cmd, vehicle) end
    if not setPedDriveTo(cmd.ped, vehicle, cmd.x, cmd.y, cmd.z, cmd.speed, cmd.mode, cmd.style) then
        outputDebugString("[vana-traffic] native drive-to refused", 2)
    end
end

addEvent("vana-traffic:drive", true)
addEventHandler("vana-traffic:drive", resourceRoot, function(vehicle, ped, x, y, z, speed, mode, style)
    if not isElement(vehicle) or not isElement(ped) then return end
    local cmd = commands[vehicle] or { prepared = false }
    cmd.ped, cmd.x, cmd.y, cmd.z, cmd.speed, cmd.mode, cmd.style, cmd.since = ped, x, y, z, speed, mode, style, getTickCount()
    commands[vehicle] = cmd
    apply(vehicle)
end)

addEvent("vana-traffic:release", true)
addEventHandler("vana-traffic:release", resourceRoot, function(vehicle, ped)
    local cmd = commands[vehicle]
    commands[vehicle] = nil
    if cmd and isTimer(cmd.retry) then killTimer(cmd.retry) end
    if isElement(ped) and isElementStreamedIn(ped) and not isPedDead(ped) and getPedOccupiedVehicle(ped) == vehicle then
        killPedTask(ped, "primary", 3, false)
    end
end)

-- Occupants get out (to pick a fight, or because the car has been abandoned).
addEvent("vana-traffic:exit", true)
addEventHandler("vana-traffic:exit", resourceRoot, function(vehicle, peds)
    commands[vehicle] = nil
    for _, ped in ipairs(peds) do
        if isElement(ped) and isElementStreamedIn(ped) and getPedOccupiedVehicle(ped) then
            killPedTask(ped, "primary", 3, false)
            setPedExitVehicle(ped)
        end
    end
end)

addEvent("vana-traffic:honk", true)
addEventHandler("vana-traffic:honk", resourceRoot, function(ped)
    if not isElement(ped) or not isElementSyncer(ped) then return end
    setPedControlState(ped, "horn", true)
    setTimer(function() if isElement(ped) then setPedControlState(ped, "horn", false) end end, 900, 1)
end)

-- Incidents: players hitting, kicking or shooting a traffic car or its occupants. The server decides
-- what the occupants do. Reported by the car's owner, and by a player who rams one themselves.
local function report(vehicle, player, incident, magnitude)
    local now = getTickCount()
    if lastCollision[vehicle] and now - lastCollision[vehicle] < 1500 then return end
    lastCollision[vehicle] = now
    triggerServerEvent("vana-traffic:incident", resourceRoot, vehicle, player, incident, magnitude)
end

local function playerBehind(element)
    if not isElement(element) then return false end
    if getElementType(element) == "vehicle" then element = getVehicleController(element) end
    return element and getElementType(element) == "player" and element
end

local function isTrafficCar(vehicle)
    return isElement(vehicle) and getElementData(vehicle, "vana:trafficCar")
end

addEventHandler("onClientVehicleCollision", root, function(hitElement, force)
    if isTrafficCar(source) and isElementSyncer(source) then
        local player = playerBehind(hitElement)
        if player then report(source, player, "collision", force) end
    elseif source == getPedOccupiedVehicle(localPlayer) and isTrafficCar(hitElement) then
        report(hitElement, localPlayer, "collision", force)
    end
end)

-- Weapons 0-15 are fists and melee; anything else counts as being shot at.
local function incidentFor(weapon)
    return (weapon or 0) <= 15 and "melee" or "shot"
end

addEventHandler("onClientVehicleDamage", root, function(attacker, weapon)
    if not isTrafficCar(source) or not isElementSyncer(source) or not weapon then return end
    local player = playerBehind(attacker)
    if player then report(source, player, incidentFor(weapon)) end
end)

addEventHandler("onClientPedDamage", root, function(attacker, weapon)
    local vehicle = getPedOccupiedVehicle(source)
    if not getElementData(source, "vana:traffic") or not isTrafficCar(vehicle) or not isElementSyncer(vehicle) then return end
    local player = playerBehind(attacker)
    if player then report(vehicle, player, incidentFor(weapon)) end
end)

addEventHandler("onClientElementStreamIn", root, function()
    if commands[source] then apply(source) end
end)

addEventHandler("onClientElementDestroy", root, function()
    commands[source], lastCollision[source] = nil, nil
end)

-- Debug telemetry (server toggles it with /traffic debug on): real speed and native autopilot state.
setTimer(function()
    if not getElementData(resourceRoot, "debug") then return end
    local samples = {}
    for vehicle in pairs(commands) do
        if isElement(vehicle) and isElementSyncer(vehicle) then
            local vx, vy, vz = getElementVelocity(vehicle)
            local ok, diag = pcall(getVehicleNativeAutoPilotDiagnostic, vehicle)
            diag = ok and type(diag) == "table" and diag or {}
            samples[#samples + 1] = {
                vehicle = vehicle, speed = math.sqrt(vx * vx + vy * vy + vz * vz) * 50,
                mission = diag.carMission, temp = diag.temporaryAction, stuck = diag.isStuck, style = diag.drivingStyle,
            }
        end
    end
    if #samples > 0 then triggerServerEvent("vana-traffic:telemetry", resourceRoot, samples) end
end, 2000, 0)
