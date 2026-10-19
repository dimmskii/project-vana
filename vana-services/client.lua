-- Runs emergency service orders from the server with native tasks, once this client syncs the
-- elements involved. Orders that arrive before ownership/streaming are retried for a while.
local function retry(fn, ...)
    local args, started = { ... }, getTickCount()
    local function attempt()
        if fn(unpack(args)) or getTickCount() - started > 10000 then return end
        setTimer(attempt, 250, 1)
    end
    attempt()
end

local function owns(element)
    return isElement(element) and isElementStreamedIn(element) and isElementSyncer(element)
end

-- Orders that were accepted but didn't take (GTA can drop one without saying so, and a medic still
-- climbing out of the ambulance misses his walk): each is watched every second for VERIFY_FOR_MS and
-- given again when the ped stands idle for 1.5 s short of done, at most VERIFY_TRIES times. Getting in
-- or out of a car, falling and an animation (the medics' CPR) aren't idle.
local VERIFY_MS, VERIFY_FOR_MS, VERIFY_TRIES = 1000, 25000, 5
local BUSY = { "CAR", "FALL", "GET_UP", "HIT_", "IN_AIR", "LAND", "DIE", "DEAD" }
local verifying = {} -- ped -> timer

local function busy(ped)
    if getPedAnimation(ped) then return true end
    local task = getPedSimplestTask(ped) or ""
    for _, part in ipairs(BUSY) do
        if task:find(part, 1, true) then return true end
    end
    return false
end

local function verify(ped, done, again)
    if isTimer(verifying[ped]) then killTimer(verifying[ped]) end
    local started, tries, idleSince = getTickCount(), 0, nil
    verifying[ped] = setTimer(function()
        if not isElement(ped) or isPedDead(ped) or done() or getTickCount() - started > VERIFY_FOR_MS then
            if isTimer(verifying[ped]) then killTimer(verifying[ped]) end
            verifying[ped] = nil
            return
        end
        if not owns(ped) then return end
        local vx, vy = getElementVelocity(ped)
        if (vx * vx + vy * vy) * 2500 > 0.09 or getPedTaskSequenceProgress(ped) >= 0 or busy(ped) then
            idleSince = nil
            return
        end
        idleSince = idleSince or getTickCount()
        if getTickCount() - idleSince >= 1500 and tries < VERIFY_TRIES then
            tries, idleSince = tries + 1, nil
            again()
        end
    end, VERIFY_MS, 0)
end

local prepared = {}
local forgetHeli

addEvent("vana-services:drive", true)
addEventHandler("vana-services:drive", resourceRoot, function(vehicle, driver, x, y, z, speed, mode)
    retry(function()
        if not owns(vehicle) or not owns(driver) or getPedOccupiedVehicleSeat(driver) ~= 0 then return false end
        if not prepared[vehicle] then
            for _, occupant in pairs(getVehicleOccupants(vehicle) or {}) do
                if getElementType(occupant) == "ped" then setPedMissionActor(occupant, true) end
            end
            setVehicleLoadCollisionFlag(vehicle, false)
            killPedTask(driver, "primary", 3, false)
            prepared[vehicle] = true
        end
        -- Emergency vehicles plough on through traffic and ignore lights.
        setPedDriveTo(driver, vehicle, x, y, z, speed, mode, "avoid_cars")
        return true
    end)
end)

addEvent("vana-services:exit", true)
addEventHandler("vana-services:exit", resourceRoot, function(vehicle, crew)
    for _, ped in ipairs(crew) do
        retry(function()
            if not owns(ped) then return false end
            if getPedOccupiedVehicle(ped) then
                killPedTask(ped, "primary", 3, false)
                setPedExitVehicle(ped)
            end
            return true
        end)
        verify(ped, function() return not getPedOccupiedVehicle(ped) end, function() setPedExitVehicle(ped) end)
    end
end)

addEvent("vana-services:walk", true)
addEventHandler("vana-services:walk", resourceRoot, function(ped, x, y, z, run)
    -- A straight go-to: GTA's route follower draws on small pools that crash the game when full.
    local function go()
        return setPedTaskSequence(ped, { { task = "go_to", x = x, y = y, z = z, movement = run and "run" or "walk", radius = 1.0, slowdownRadius = 1.5 } })
    end
    retry(function()
        if not owns(ped) or getPedOccupiedVehicle(ped) then return false end
        return go()
    end)
    verify(ped, function()
        local px, py = getElementPosition(ped)
        return getDistanceBetweenPoints2D(px, py, x, y) <= 1.5
    end, function()
        if getPedOccupiedVehicle(ped) then setPedExitVehicle(ped) else go() end
    end)
end)

addEvent("vana-services:enter", true)
addEventHandler("vana-services:enter", resourceRoot, function(ped, vehicle, seat)
    retry(function()
        if not owns(ped) or not isElement(vehicle) or not isElementStreamedIn(vehicle) then return false end
        if getPedOccupiedVehicle(ped) == vehicle then return true end
        return setPedEnterVehicle(ped, vehicle, seat)
    end)
    verify(ped, function() return not isElement(vehicle) or getPedOccupiedVehicle(ped) == vehicle end, function()
        if isElementStreamedIn(vehicle) then setPedEnterVehicle(ped, vehicle, seat) end
    end)
end)

addEvent("vana-services:kill", true)
addEventHandler("vana-services:kill", resourceRoot, function(ped, target)
    retry(function()
        if not owns(ped) or not isElement(target) or not isElementStreamedIn(target) then return false end
        -- Never replace a running attack task: doing so mid-update can crash GTA's seek task.
        if isPedDoingTask(ped, "TASK_COMPLEX_KILL_PED_ON_FOOT") then return true end
        -- Attacking seeks with GTA's route tasks; wait while their pools are nearly full.
        for _, pool in ipairs({ "point-route", "node-route" }) do
            local capacity, used = engineGetPoolCapacity(pool), engineGetPoolUsedCapacity(pool)
            if capacity and used and capacity - used <= 12 then return false end
        end
        return setPedKillOnFoot(ped, target)
    end)
end)

addEvent("vana-services:release", true)
addEventHandler("vana-services:release", resourceRoot, function(vehicle)
    prepared[vehicle] = nil
    if forgetHeli then forgetHeli(vehicle) end
end)

addEventHandler("onClientElementDestroy", root, function()
    prepared[source] = nil
    if isTimer(verifying[source]) then killTimer(verifying[source]) end
    verifying[source] = nil
end)

-- Firefighters hose down a wreck with an extinguisher.
addEvent("vana-services:spray", true)
addEventHandler("vana-services:spray", resourceRoot, function(ped, x, y, z, ms)
    retry(function()
        if not owns(ped) or getPedOccupiedVehicle(ped) then return false end
        if getPedWeapon(ped) ~= 42 then
            -- Extinguisher in hand (the server gives weapons; locally the native task needs it current).
            setPedWeaponSlot(ped, 9)
        end
        return setPedShootAt(ped, Vector3(x, y, z), ms, 20)
    end)
end)

-- Police helicopter, flown by its owner: circles the player at a height, nose toward them; the
-- gunner fires drive-by from the side door; a searchlight at night.
local helis = {} -- vehicle -> { crew, target, leaving, angle, light }

addEvent("vana-services:heli", true)
addEventHandler("vana-services:heli", resourceRoot, function(vehicle, crew, target, leaving)
    local h = helis[vehicle] or { angle = math.random() * 2 * math.pi }
    h.crew, h.target, h.leaving, h.firing = crew, target, leaving, nil
    helis[vehicle] = h
end)

function forgetHeli(vehicle)
    local h = helis[vehicle]
    if h and isElement(h.light) then destroyElement(h.light) end
    helis[vehicle] = nil
end

addEventHandler("onClientPreRender", root, function(msPassed)
    local dt = msPassed / 1000
    for vehicle, h in pairs(helis) do
        local pilot = h.crew and h.crew[1]
        if not isElement(vehicle) or not isElement(h.target) then
            forgetHeli(vehicle)
        elseif not isElement(pilot) or isPedDead(pilot) or getPedOccupiedVehicle(pilot) ~= vehicle then
            -- No pilot, no flying: let it come down.
            forgetHeli(vehicle)
        elseif isElementSyncer(vehicle) and isElementStreamedIn(vehicle) then
            local x, y, z = getElementPosition(vehicle)
            local tx, ty, tz = getElementPosition(h.target)
            local gx, gy, gz
            if h.leaving then
                gx, gy, gz = x + (x - tx), y + (y - ty), z + 40
            else
                h.angle = h.angle + dt * 0.25
                gx, gy, gz = tx + math.cos(h.angle) * 28, ty + math.sin(h.angle) * 28, tz + 22
            end
            local dx, dy, dz = gx - x, gy - y, gz - z
            local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
            local speed = math.min(25, dist * 0.8)
            if dist > 0.1 then
                setElementVelocity(vehicle, dx / dist * speed / 50, dy / dist * speed / 50, dz / dist * speed / 50)
            end
            setElementRotation(vehicle, 0, 0, math.deg(math.atan2(ty - y, tx - x)) - 90)
            setVehicleRotorSpeed(vehicle, 0.2)

            local gunner = h.crew and h.crew[2]
            if not h.leaving and isElement(gunner) and not h.firing and getDistanceBetweenPoints3D(x, y, z, tx, ty, tz) < 70 then
                h.firing = setPedDriveBy(gunner, h.target, 120, "ai_side")
            end

            local hour = getTime()
            if not h.leaving and (hour >= 20 or hour < 6) then
                if not isElement(h.light) then h.light = createSearchLight(x, y, z, tx, ty, tz, 0.5, 6) end
                if h.light then
                    setSearchLightStartPosition(h.light, x, y, z - 1)
                    setSearchLightEndPosition(h.light, tx, ty, tz)
                end
            elseif isElement(h.light) then
                destroyElement(h.light)
                h.light = nil
            end
        end
    end
end)

addEventHandler("onClientElementDestroy", root, function()
    if helis[source] then forgetHeli(source) end
end)

-- Knocked down or getting up: reported for the local player and the cops this client simulates,
-- so the police can't bust anyone (or be busting) from the ground.
local DOWN_TASKS = { "FALL", "GET_UP", "IN_AIR", "LAND", "HIT_", "DIE", "DEAD", "KNOCK" }
local reportedDown = {}

local function isDown(ped)
    local task = getPedSimplestTask(ped) or ""
    for _, part in ipairs(DOWN_TASKS) do
        if task:find(part, 1, true) then return true end
    end
    return false
end

setTimer(function()
    local changes, any = {}, false
    local function check(ped)
        local state = isDown(ped)
        if reportedDown[ped] ~= state then
            reportedDown[ped], changes[ped], any = state, state, true
        end
    end
    check(localPlayer)
    for _, ped in ipairs(getElementsByType("ped", root, true)) do
        if isElementSyncer(ped) and (getElementData(ped, "vana:service") == "police" or getElementData(ped, "vana:ambient") == "cop"
            or getElementData(ped, "vana:traffic") == "cop") then
            check(ped)
        end
    end
    if any then triggerServerEvent("vana-services:down", resourceRoot, changes) end
end, 250, 0)

-- Hits on service crews we simulate count as crimes (reported to the server, which decides).
local lastHit = {}
addEventHandler("onClientPedDamage", root, function(attacker, weapon)
    if not getElementData(source, "vana:service") or not isElementSyncer(source) or not isElement(attacker) then return end
    if getElementType(attacker) == "vehicle" then attacker = getVehicleController(attacker) end
    if not attacker or getElementType(attacker) ~= "player" then return end
    local now = getTickCount()
    if lastHit[source] and now - lastHit[source] < 250 then return end
    lastHit[source] = now
    triggerServerEvent("vana-services:crewHit", resourceRoot, source, attacker, weapon)
end)

addEventHandler("onClientElementDestroy", root, function() reportedDown[source], lastHit[source] = nil, nil end)

-- World events: a fire burning at a spot (vana-services events.lua) until the server puts it out.
-- GTA fires are local to each client, so the server tells everyone near.
addEvent("vana-services:fire", true)
addEventHandler("vana-services:fire", resourceRoot, function(x, y, z, size, burning)
    if burning then createFire(x, y, z, size) else extinguishFire(x, y, z, size * 2) end
end)
