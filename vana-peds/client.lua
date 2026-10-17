-- Executes the server's walk targets and encounters with GTA's native tasks, and leases GTA's
-- ambient event profile so owned peds avoid, flinch, flee and fight natively.
local commands = {}  -- ped -> walk { x, y, z, hold } or encounter { mode, target, vehicle, ms }, plus since
local leases = {}    -- ped -> event profile token
local lastReport = {}

local function lease(ped)
    local kind = getElementData(ped, "vana:ambient")
    if leases[ped] or not kind then return end
    -- Former traffic occupants arrive as mission actors, which ambient profiles refuse.
    if isPedMissionActor(ped) then setPedMissionActor(ped, false) end
    -- Every client holds the lease; Neon only lets the current syncer act on it. Cops get the safe
    -- cop profile: they react but never escalate to wanted levels or arrests.
    leases[ped] = acquirePedNativeEventProfile(ped, kind == "cop" and "ambient-cop-safe" or "ambient-wander") or nil
end

-- A ped becoming ambient while already streamed in (e.g. a driver who just got out of a car).
addEventHandler("onClientElementDataChange", root, function(key)
    if key == "vana:ambient" and getElementType(source) == "ped" and isElementStreamedIn(source) then lease(source) end
end)

-- GTA's route tasks (follow-node-route, and the seek/flee tasks built on it) take slots from two
-- 64-slot pools; when they run out the game crashes. Walking uses a straight native go-to instead,
-- and route-hungry orders wait while the pools are nearly full.
local ROUTE_POOL_RESERVE = 12

local function routesAvailable()
    for _, pool in ipairs({ "point-route", "node-route" }) do
        local capacity, used = engineGetPoolCapacity(pool), engineGetPoolUsedCapacity(pool)
        if capacity and used and capacity - used <= ROUTE_POOL_RESERVE then return false end
    end
    return true
end

local function walk(ped, cmd)
    -- Holding at a kerb: arrive precisely. Walking: arrive loosely so the ped never slows down
    -- before the next target arrives.
    local radius = cmd.hold and 0.75 or 2.0
    return setPedTaskSequence(ped, { { task = "go_to", x = cmd.x, y = cmd.y, z = cmd.z, movement = "walk",
        radius = radius, slowdownRadius = cmd.hold and 2.0 or radius } })
end

local function engage(ped, cmd)
    if cmd.mode == "react" then return true end -- GTA's own event response is already running
    if not routesAvailable() then return false end -- retried by the watchdog once there's room
    -- An arrest is a fight with the nightstick in hand (the server picked the weapon).
    if cmd.mode == "fight" or cmd.mode == "arrest" then
        -- Already attacking (the weapon in hand decides between beating and shooting): leave it be.
        if isPedDoingTask(ped, "TASK_COMPLEX_KILL_PED_ON_FOOT") then return true end
        return isElement(cmd.target) and isElementStreamedIn(cmd.target) and setPedKillOnFoot(ped, cmd.target)
    elseif cmd.mode == "flee" then
        return isElement(cmd.target) and isElementStreamedIn(cmd.target) and
            setPedTaskSequence(ped, { { task = "smart_flee", target = cmd.target, safeDistance = 60, duration = cmd.ms } })
    elseif cmd.mode == "jack" then
        return isElement(cmd.vehicle) and isElementStreamedIn(cmd.vehicle) and setPedEnterVehicle(ped, cmd.vehicle, 0)
    end
    return false
end

local function apply(ped)
    local cmd = commands[ped]
    if not cmd or not isElement(ped) then commands[ped] = nil return end
    if not (isElementStreamedIn(ped) and isElementSyncer(ped)) then
        if getTickCount() - cmd.since < 10000 and not isTimer(cmd.retry) then
            cmd.retry = setTimer(apply, 200, 1, ped)
        end
        return
    end
    lease(ped)
    local ok
    if cmd.mode then ok = engage(ped, cmd) else ok = walk(ped, cmd) end
    if not ok then outputDebugString("[vana-peds] native " .. (cmd.mode or "navigate-to") .. " refused", 2) end
end

local function command(ped, cmd)
    local old = commands[ped]
    if old and isTimer(old.retry) then killTimer(old.retry) end
    if old and isTimer(old.timer) then killTimer(old.timer) end
    cmd.since = getTickCount()
    commands[ped] = cmd
    apply(ped)
end

-- Fights and arrests don't always take: a ped in the middle of being dragged from a car drops the
-- order. Re-issue it, but only to a ped that is properly idle: never on top of a running (or merely
-- interrupted) attack task, whose replacement mid-update can crash GTA's seek/follow-route tasks.
local BUSY_TASKS = { "KILL_PED", "FALL", "GET_UP", "HIT_", "IN_AIR", "LAND", "DIE", "DEAD", "CAR", "REACT", "FLEE" }

local function isBusy(ped)
    if isPedDoingTask(ped, "TASK_COMPLEX_KILL_PED_ON_FOOT") then return true end
    local task = getPedSimplestTask(ped) or ""
    for _, part in ipairs(BUSY_TASKS) do
        if task:find(part, 1, true) then return true end
    end
    return false
end

setTimer(function()
    for ped, cmd in pairs(commands) do
        if (cmd.mode == "fight" or cmd.mode == "arrest") and (cmd.reissued or 0) < 5 and isElement(ped) and isElementStreamedIn(ped)
            and isElementSyncer(ped) and not isPedDead(ped) and not isBusy(ped) then
            cmd.reissued = (cmd.reissued or 0) + 1
            apply(ped)
        end
    end
end, 3000, 0)

addEvent("vana-peds:walk", true)
addEventHandler("vana-peds:walk", resourceRoot, function(ped, x, y, z, hold)
    if isElement(ped) then command(ped, { x = x, y = y, z = z, hold = hold }) end
end)

addEvent("vana-peds:engage", true)
addEventHandler("vana-peds:engage", resourceRoot, function(ped, mode, target, vehicle, ms)
    if isElement(ped) then command(ped, { mode = mode, target = target, vehicle = vehicle, ms = ms }) end
end)

addEvent("vana-peds:release", true)
addEventHandler("vana-peds:release", resourceRoot, function(ped)
    local cmd = commands[ped]
    commands[ped] = nil
    if cmd and isTimer(cmd.retry) then killTimer(cmd.retry) end
    if cmd and isTimer(cmd.timer) then killTimer(cmd.timer) end
    -- Never interrupt a dying ped's fall: killing its task leaves the body hanging in mid-air.
    if isElement(ped) and isElementStreamedIn(ped) and not isPedDead(ped) and not getPedOccupiedVehicle(ped) then
        killPedTask(ped, "primary", 3, false)
    end
end)

-- Report players hurting a ped we simulate; the server decides how it responds.
addEventHandler("onClientPedDamage", root, function(attacker, weapon)
    if not getElementData(source, "vana:ambient") or not isElementSyncer(source) or not isElement(attacker) then return end
    if getElementType(attacker) == "vehicle" then attacker = getVehicleController(attacker) end
    if not attacker or getElementType(attacker) ~= "player" then return end
    local now = getTickCount()
    if lastReport[source] and now - lastReport[source] < 1000 then return end
    lastReport[source] = now
    triggerServerEvent("vana-peds:attacked", resourceRoot, source, attacker, weapon)
end)

addEventHandler("onClientElementStreamIn", root, function()
    if getElementType(source) ~= "ped" then return end
    lease(source)
    if commands[source] then apply(source) end
end)

addEventHandler("onClientElementDestroy", root, function()
    if leases[source] then releasePedNativeEventProfile(leases[source]) end
    leases[source], commands[source], lastReport[source] = nil, nil, nil
end)
