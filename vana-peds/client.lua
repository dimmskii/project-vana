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

-- GTA refuses a new walk while the last one is still the ped's task: walking it (or walking into a
-- wall on the way), or arrived and standing still at its end (where it stays). Those are plain go-tos, safe to end; a flee sequence
-- (route tasks) never is.
local function inWalk(ped)
    local step = getPedSimplestTask(ped)
    return isPedDoingTask(ped, "TASK_COMPLEX_USE_SEQUENCE") and (step == "TASK_SIMPLE_GO_TO_POINT" or step == "TASK_SIMPLE_STAND_STILL"
        or step == "TASK_SIMPLE_HIT_WALL")
end

local function standingInWalk(ped)
    return isPedDoingTask(ped, "TASK_COMPLEX_USE_SEQUENCE") and getPedSimplestTask(ped) == "TASK_SIMPLE_STAND_STILL"
end

-- A go-to sequence, given over the last one: that one is cleared first, since GTA otherwise refuses
-- the new order, or queues it and quietly drops it while the old walk runs on to its end.
local capturing, captured -- Neon's own error for a refused order, for vana-peds:orders
addEventHandler("onClientDebugMessage", root, function(message) if capturing then captured = message end end)

local function goTo(ped, sequence)
    if inWalk(ped) then killPedTask(ped, "primary", 3, false) end
    capturing, captured = true, nil
    local ok = setPedTaskSequence(ped, sequence)
    capturing = false
    return ok
end

local function walk(ped, cmd)
    -- Holding at a kerb: arrive precisely. Walking: arrive loosely so the ped never slows down
    -- before the next target arrives.
    local radius = cmd.hold and 0.75 or 2.0
    return goTo(ped, { { task = "go_to", x = cmd.x, y = cmd.y, z = cmd.z, movement = "walk",
        radius = radius, slowdownRadius = cmd.hold and 2.0 or radius } })
end

local function engage(ped, cmd)
    -- GTA's own event response is already running; a holdup's hands-up animation is the server's.
    if cmd.mode == "react" or cmd.mode == "holdup" then return true end
    if not routesAvailable() then return false end -- retried by the watchdog once there's room
    -- An arrest is a fight with the nightstick in hand (the server picked the weapon).
    if cmd.mode == "fight" or cmd.mode == "arrest" then
        -- Already attacking (the weapon in hand decides between beating and shooting): leave it be.
        if isPedDoingTask(ped, "TASK_COMPLEX_KILL_PED_ON_FOOT") then return true end
        if not isElement(cmd.target) then return false end
        -- A target this client hasn't streamed in can't be attacked yet: run to where it is, and the
        -- re-issue below turns it into the attack once it streams in.
        if not isElementStreamedIn(cmd.target) then
            local tx, ty, tz = getElementPosition(cmd.target)
            cmd.approaching = true
            return goTo(ped, { { task = "go_to", x = tx, y = ty, z = tz, movement = "run", radius = 3.0, slowdownRadius = 3.0 } })
        end
        cmd.approaching = nil
        return setPedKillOnFoot(ped, cmd.target)
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
    cmd.applied = getTickCount()
    local ok
    if cmd.mode then ok = engage(ped, cmd) else ok = walk(ped, cmd) end
    if not ok and Debug.on("orders") then
        -- Why the game might have said no (docs/debug.md, vana-peds:orders).
        local points = { engineGetPoolCapacity("point-route"), engineGetPoolUsedCapacity("point-route") }
        local nodes = { engineGetPoolCapacity("node-route"), engineGetPoolUsedCapacity("node-route") }
        Debug.log("orders", ("%s refused%s: %s, task %s / %s, mission actor %s, health %d, frozen %s, route pools %s/%s and %s/%s"):format(
            cmd.mode or "walk", captured and (" (" .. captured .. ")") or "",
            cmd.mode and ("target " .. (isElement(cmd.target) and getElementType(cmd.target) or "gone") ..
                (isElement(cmd.target) and (isElementStreamedIn(cmd.target) and " streamed" or " not streamed") or ""))
                or ("to %.1f, %.1f"):format(cmd.x, cmd.y),
            tostring(getPedTask(ped, "primary", 3)), tostring(getPedSimplestTask(ped)), tostring(isPedMissionActor(ped)),
            getElementHealth(ped), tostring(isElementFrozen(ped)),
            tostring(points[2]), tostring(points[1]), tostring(nodes[2]), tostring(nodes[1])))
    end
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
        if (cmd.mode == "fight" or cmd.mode == "arrest") and isElement(ped) and isElementStreamedIn(ped)
            and isElementSyncer(ped) and not isPedDead(ped) and not isBusy(ped) then
            if (cmd.reissued or 0) < 5 or cmd.approaching then
                -- Running towards a target not streamed in yet doesn't use up the tries.
                if not cmd.approaching then cmd.reissued = (cmd.reissued or 0) + 1 end
                apply(ped)
            elseif not getPedTask(ped, "primary", 3) and not cmd.reported then
                -- Still idle after every try: the server calls the fight off and the ped walks on.
                cmd.reported = true
                triggerServerEvent("vana-peds:stuck", resourceRoot, ped)
            end
        end
    end
end, 3000, 0)

-- Walks that didn't take. GTA can drop an order without saying so (its event queue full, or an event
-- response of its own replacing it), and a reaction (flinch, flee) that ends leaves the ped idle. So
-- twice a second each walk this client runs is checked: still under way (its sequence running, or
-- moving), or arrived. If not, and the ped isn't busy with a reaction of GTA's, the order is given
-- again; after MAX_REAPPLIES in vain the server is asked for a fresh route. A ped hanging in the air
-- goes back onto the ground under it, or, with no ground loaded there and out of view, is given up.
local CHECK_MS, REAPPLY_MS, MAX_REAPPLIES, HANG_MS = 500, 800, 6, 1000

local function debugLog(text) if Debug.on("orders") then Debug.log("orders", text) end end

setTimer(function()
    local now = getTickCount()
    for ped, cmd in pairs(commands) do
        if not cmd.mode and isElement(ped) and isElementStreamedIn(ped) and isElementSyncer(ped) and not isPedDead(ped)
            and not getPedOccupiedVehicle(ped) then
            local x, y, z = getElementPosition(ped)
            local vx, vy, vz = getElementVelocity(ped)
            if not isPedOnGround(ped) and math.abs(vz) < 0.01 then
                cmd.hangingSince = cmd.hangingSince or now
                if now - cmd.hangingSince > HANG_MS then
                    cmd.hangingSince = nil
                    cmd.putBack = (cmd.putBack or 0) + 1
                    local ground = getGroundPosition(x, y, z + 1)
                    -- GTA can keep a ped pinned where it is (waiting for collision): putting it down
                    -- again doesn't help, so the third time it's given up, in view or not.
                    if cmd.putBack >= 3 then
                        debugLog(("ped %s still hanging after being put down twice: given up"):format(tostring(ped):sub(-8)))
                        triggerServerEvent("vana-peds:lost", resourceRoot, ped)
                    elseif ground and ground ~= 0 then
                        debugLog(("ped %s hanging %.1f m up: put back on the ground"):format(tostring(ped):sub(-8), z - ground))
                        setElementFrozen(ped, false)
                        setElementPosition(ped, x, y, ground + 1)
                        if cmd.putBack == 2 then setElementVelocity(ped, 0, 0, -0.1) end
                    elseif not isElementOnScreen(ped) then
                        triggerServerEvent("vana-peds:lost", resourceRoot, ped)
                    end
                end
            else
                cmd.hangingSince, cmd.putBack = nil, nil
            end
            local moving = (vx * vx + vy * vy) * 2500 > 0.09
            local arrived = getDistanceBetweenPoints2D(x, y, cmd.x, cmd.y) <= (cmd.hold and 1.25 or 2.5)
            -- Hanging: no walk takes until it's back on the ground (above).
            if cmd.hangingSince or moving or arrived or (getPedTaskSequenceProgress(ped) >= 0 and not standingInWalk(ped)) then
                cmd.misses = 0
            elseif not isBusy(ped) and now - (cmd.applied or cmd.since) > REAPPLY_MS then
                cmd.misses = (cmd.misses or 0) + 1
                if cmd.misses > MAX_REAPPLIES then
                    cmd.misses = 0
                    debugLog(("ped %s: walk to %.1f, %.1f never took (task %s): asking for a new route"):format(tostring(ped):sub(-8), cmd.x, cmd.y,
                        tostring(getPedTask(ped, "primary", 3))))
                    triggerServerEvent("vana-peds:stuck", resourceRoot, ped)
                    cmd.applied = now
                else
                    debugLog(("ped %s idle (task %s / %s) %.1f m from its target (%.1f m below it%s): walk given again (%d)"):format(tostring(ped):sub(-8),
                        tostring(getPedTask(ped, "primary", 3)), tostring(getPedSimplestTask(ped)), getDistanceBetweenPoints2D(x, y, cmd.x, cmd.y),
                        (cmd.z or z) - z, cmd.hold and ", holding" or "", cmd.misses))
                    apply(ped)
                end
            end
        end
    end
end, CHECK_MS, 0)

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
    if not ped then return end -- destroyed before the event arrived (the resource stopping)
    local cmd = commands[ped]
    commands[ped] = nil
    if cmd and isTimer(cmd.retry) then killTimer(cmd.retry) end
    if cmd and isTimer(cmd.timer) then killTimer(cmd.timer) end
    -- Never interrupt a dying ped's fall: killing its task leaves the body hanging in mid-air.
    if isElement(ped) and isElementStreamedIn(ped) and not isPedDead(ped) and not getPedOccupiedVehicle(ped) then
        killPedTask(ped, "primary", 3, false)
    end
end)

-- Report players and peds hurting a ped we simulate; the server decides how it responds.
addEventHandler("onClientPedDamage", root, function(attacker, weapon)
    if not getElementData(source, "vana:ambient") or not isElementSyncer(source) or not isElement(attacker) then return end
    if getElementType(attacker) == "vehicle" then attacker = getVehicleController(attacker) end
    if not attacker or attacker == source then return end
    local kind = getElementType(attacker)
    if kind ~= "player" and kind ~= "ped" then return end
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

-- A ped hurting us: our gang's members nearby come to help (the server decides who).
local lastHurt = 0
addEventHandler("onClientPlayerDamage", localPlayer, function(attacker)
    if isElement(attacker) and getElementType(attacker) == "vehicle" then attacker = getVehicleController(attacker) end
    if not isElement(attacker) or getElementType(attacker) ~= "ped" or getTickCount() - lastHurt < 1000 then return end
    lastHurt = getTickCount()
    triggerServerEvent("vana-peds:playerAttacked", resourceRoot, attacker)
end)

-- Aiming a gun at someone: walkers hold up, run or fight (vana-peds); drivers bail out, speed off or
-- fight (vana-traffic). Reported twice a second while the aim lasts.
setTimer(function()
    local slot = getPedWeaponSlot(localPlayer)
    if slot < 2 or slot > 7 or not getPedControlState(localPlayer, "aim_weapon") or getPedOccupiedVehicle(localPlayer) then return end
    local target = getPedTarget(localPlayer)
    if not isElement(target) or getElementType(target) ~= "ped" or isPedDead(target) then return end
    local car = getPedOccupiedVehicle(target)
    local traffic = getResourceFromName("vana-traffic")
    if car and getElementData(car, "vana:trafficCar") and traffic and getResourceState(traffic) == "running" then
        triggerServerEvent("vana-traffic:incident", getResourceRootElement(traffic), car, localPlayer, "aimed", 0)
    elseif getElementData(target, "vana:ambient") then
        triggerServerEvent("vana-peds:aimed", resourceRoot, target)
    end
end, 500, 0)
