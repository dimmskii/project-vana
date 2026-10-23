-- Trains: the server keeps every train on its track all the time (schedule.lua) and makes elements
-- only for those near players, simulated by one nearby player's client (as traffic units are). The
-- server sets their speed; while a train exists, where it is comes back from that client's game, so
-- nothing is ever teleported in sight. A driver a player pulls out is handed to vana-peds.
-- No blips: vanilla shows no trains on the radar. No elements for players in interiors or other
-- dimensions, and nothing parked anywhere: a train nobody is near isn't in the world at all.
local population = exports["vana-population"]
local rules = population:getPersonalityRules()
local CONFIG = TrainConfig

local counts = {} -- the services' train counts, from the meta.xml settings (/vanaset trains freight 3)
for _, service in pairs(CONFIG.services) do counts[service.setting] = service.count end

local trains, lastId = {}, 0  -- id -> train (schedule.lua)
local live = {}               -- train -> { engine, cars = {}, driver, driverSpec, owner, ... }
local released = {}           -- drivers no longer ours: ped -> { kind, personality, encounter }
local enabled = true
-- setTrainDirection(true) runs the way rail distances grow, until a running train shows otherwise
-- (once: a second flip would mean the check is wrong, not the flag).
local clockwiseGrows, flipped = true, false

local function sync(text) if Debug.on("sync") then Debug.log("sync", text) end end

local function serviceCounts()
    local out = {}
    for name, service in pairs(CONFIG.services) do out[name] = counts[service.setting] or service.count end
    return out
end

local function eligiblePlayers()
    local list = {}
    for _, player in ipairs(getElementsByType("player")) do
        if getElementDimension(player) == 0 and getElementInterior(player) == 0 then list[#list + 1] = player end
    end
    return list
end

local function nearestPlayer(x, y, z, players, maxDist)
    local best, bestDist = false, maxDist or math.huge
    for _, player in ipairs(players) do
        local px, py, pz = getElementPosition(player)
        local d = getDistanceBetweenPoints3D(x, y, z, px, py, pz)
        if d < bestDist then best, bestDist = player, d end
    end
    return best, bestDist
end

-- The nearest player to any part of a train (engine, middle, tail).
local function nearestToTrain(train, players, maxDist)
    local t = Tracks[train.track]
    local best, bestDist = false, maxDist or math.huge
    local dir = train.forward and 1 or -1
    for k = 0, 2 do
        local x, y, z = TracksData.pointAt(t, train.s - dir * train.length * k / 2)
        local p, d = nearestPlayer(x, y, z, players, bestDist)
        if p then best, bestDist = p, d end
    end
    return best, bestDist
end

local function vehiclesOf(l)
    local list = { l.engine }
    for _, car in ipairs(l.cars) do list[#list + 1] = car end
    return list
end

-- A player in any seat of any of its vehicles.
local function playerAboard(l)
    for _, v in ipairs(vehiclesOf(l)) do
        if isElement(v) then
            for _, occupant in pairs(getVehicleOccupants(v) or {}) do
                if getElementType(occupant) == "player" then return occupant end
            end
        end
    end
    return false
end

local function railPlace(vehicle, track, s, forward)
    setTrainTrack(vehicle, getDefaultTrack(track))
    setTrainPosition(vehicle, s)
    setTrainDirection(vehicle, forward == clockwiseGrows)
end

-- Every vehicle of the train put at its rail distance (only while nobody can see it). The server's
-- copy of the engine's position stays where it was until the owner's game syncs the new one, so
-- readbacks of that old position (stale) are ignored.
local function replace(train, l)
    l.stale, l.placedTick, l.placedS = { getElementPosition(l.engine) }, getTickCount(), train.s
    l.stillTicks, l.wrongWay = 0, 0
    local dir = train.forward and 1 or -1
    for k, v in ipairs(vehiclesOf(l)) do
        if isElement(v) then railPlace(v, train.track, TracksData.wrap(Tracks[train.track], train.s - dir * (k - 1) * CONFIG.carSpacing), train.forward) end
    end
end

local function setOwner(train, l, owner)
    if l.owner == owner then return end
    l.owner = owner
    if not owner or train.state == "taken" then return end
    for _, v in ipairs(vehiclesOf(l)) do if isElement(v) then setElementSyncer(v, owner, true, true) end end
    if isElement(l.driver) then setElementSyncer(l.driver, owner, true, true) end
    sync(("train %d (%s): simulated by %s"):format(train.id, train.service, getPlayerName(owner)))
end

local function materialize(train, owner)
    local t = Tracks[train.track]
    local x, y, z, heading = TracksData.pointAt(t, train.s)
    if not train.forward then heading = (heading + 180) % 360 end
    local engine = createVehicle(train.engine, x, y, z + 1, 0, 0, heading)
    if not engine then return false end
    local l = { engine = engine, cars = {}, sent = -1, sentAt = 0, lastS = train.s, stillTicks = 0, wrongWay = 0 }
    local dir = train.forward and 1 or -1
    local prev = engine
    for k, model in ipairs(train.cars) do
        local cx, cy, cz = TracksData.pointAt(t, train.s - dir * k * CONFIG.carSpacing)
        local car = createVehicle(model, cx, cy, cz + 1, 0, 0, heading)
        if car then
            l.cars[#l.cars + 1] = car
            attachTrailerToVehicle(prev, car)
            prev = car
        end
    end
    for _, v in ipairs(vehiclesOf(l)) do
        -- Ours to manage: never kept by vana-vehicles' registry. Vanilla trains can't be wrecked.
        setElementData(v, "vana:managed", true, false)
        setElementData(v, "vana:train", train.service)
        setVehicleDamageProof(v, true)
        setTrainDerailable(v, false)
    end
    replace(train, l)
    local model = CONFIG.drivers[math.random(#CONFIG.drivers)]
    local driver = createPed(model, x, y, z + 2)
    if driver and warpPedIntoVehicle(driver, engine, 0) then
        setElementData(driver, "vana:train", train.service)
        l.driver, l.driverSpec = driver, { kind = "civilian", personality = population:getPersonality(model) }
    elseif driver then
        destroyElement(driver)
    end
    setVehicleEngineState(engine, true)
    live[train] = l
    setOwner(train, l, owner)
    sync(("train %d (%s): made at %.0f m on track %d (%s), %d cars"):format(train.id, train.service, train.s, train.track, getZoneName(x, y, z), #l.cars))
    return true
end

local function dematerialize(train)
    local l = live[train]
    if not l then return end
    live[train] = nil
    for _, v in ipairs(vehiclesOf(l)) do
        if isElement(v) then destroyElement(v) end
    end
    if isElement(l.driver) and not released[l.driver] then destroyElement(l.driver) end
    sync(("train %d (%s): removed at %.0f m"):format(train.id, train.service, train.s))
end

-- Its driver walks off (pulled out, or out to fight or flee) as one of vana-peds' pedestrians.
local function releaseDriver(l, encounter)
    if not isElement(l.driver) or released[l.driver] then return end
    setElementSyncer(l.driver, true)
    released[l.driver] = { kind = l.driverSpec.kind, personality = l.driverSpec.personality, encounter = encounter }
end

-- How the driver answers being pulled out: temper and fear (config/personalities.lua), as traffic's.
local function jackedEncounter(l, jacker)
    local p = l.driverSpec and l.driverSpec.personality or {}
    local fight = (p.temper or 50) >= rules.collision.fightTemper and (p.fear or 50) < rules.collision.fleeFear
    return { mode = fight and "fight" or "flee", target = jacker }
end

-- A player took the cab, or the driver is gone: off the schedule, every element back to automatic sync.
local function take(train, l, jacker)
    train.state = "taken"
    for _, v in ipairs(vehiclesOf(l)) do
        if isElement(v) then
            setElementSyncer(v, true)
            setTrainDerailable(v, true) -- a player can derail it, as in vanilla
        end
    end
    releaseDriver(l, jacker and jackedEncounter(l, jacker) or nil)
    sync(("train %d (%s): %s"):format(train.id, train.service, jacker and ("taken by " .. getPlayerName(jacker)) or "lost its driver"))
end

-- A taken train left (or wrecked) and out of everyone's sight: gone, and a new one of its service put
-- back on the line where nobody is.
local function replaceTaken(train, players)
    dematerialize(train)
    trains[train.id] = nil
    local fresh
    lastId = lastId + 1
    fresh = Schedule.newTrain(lastId, train.service, 0)
    local spot = Schedule.freeSpot(fresh.track, trains, fresh.length + 2 * CONFIG.gap + 400, function(s)
        local x, y, z = TracksData.pointAt(Tracks[fresh.track], s)
        return nearestPlayer(x, y, z, players, CONFIG.despawn + 100) ~= false
    end)
    if not spot then return sync(("train %d (%s): no room to put it back"):format(train.id, train.service)) end
    fresh.s = spot
    trains[fresh.id] = fresh
    sync(("train %d (%s): replaced by train %d at %.0f m"):format(train.id, train.service, fresh.id, spot))
end

-- Where the owner's game has the train now becomes its s. Not when that is still where it was before
-- we last put it somewhere, nor a jump: then it's put where the timetable has it, out of sight (a
-- train its owner's game doesn't simulate: not streamed in yet).
local function readBack(train, l)
    local t = Tracks[train.track]
    local x, y, z = getElementPosition(l.engine)
    if l.stale then
        if getDistanceBetweenPoints3D(x, y, z, l.stale[1], l.stale[2], l.stale[3]) < 0.05 then
            -- Not synced since: it runs on the timetable, put where that has it now and then, so it's
            -- there when it streams in.
            if getTickCount() - l.placedTick > 5000 and math.abs(TracksData.ahead(t, l.placedS, train.s, train.forward)) > 1 then
                replace(train, l)
            end
            return
        end
        -- Synced again: from here on, steps are the train running, not the jump we made.
        l.stale = nil
        l.lastS = TracksData.nearestAround(t, x, y, z, train.s, 200)
    end
    local s, off = TracksData.nearestAround(t, x, y, z, train.s, 200)
    -- Since the last readback, signed along the rail (positions arrive with the owner's sync, a
    -- fraction of a second late, so they're compared with each other, never with the timetable's).
    local step = TracksData.ahead(t, l.lastS, s, true)
    if step > t.length / 2 then step = step - t.length end
    local moved = math.abs(step) > 0.05
    l.lastS = s
    if train.state == "taken" then
        if off < 20 then train.s = s end
        return
    end
    if off > 20 then
        sync(("train %d (%s): %.0f m off its track: put back"):format(train.id, train.service, off))
        return replace(train, l)
    end
    if not moved and train.v > 1 then
        l.stillTicks = l.stillTicks + 1
        if l.stillTicks == 4 then
            sync(("train %d (%s): not moving at %.1f m/s (nobody simulates it?): put at %.0f m"):format(train.id, train.service, train.v, train.s))
            replace(train, l)
        end
        return
    end
    l.stillTicks = 0
    -- Which way it went: setTrainDirection's meaning, learnt from the first trains that run.
    if train.v > 3 and step * (train.forward and 1 or -1) < -1 then
        l.wrongWay = l.wrongWay + 1
        if l.wrongWay >= 3 and not flipped then
            clockwiseGrows, flipped = not clockwiseGrows, true
            outputServerLog(("[vana-trains] trains ran backwards: direction flag flipped (setTrainDirection(true) now means rail distances %s)")
                :format(clockwiseGrows and "grow" or "shrink"))
            for other, ol in pairs(live) do
                if other.state ~= "taken" then
                    for _, v in ipairs(vehiclesOf(ol)) do if isElement(v) then setTrainDirection(v, other.forward == clockwiseGrows) end end
                end
                ol.wrongWay = 0
            end
        elseif l.wrongWay == 3 then
            outputServerLog(("[vana-trains] WARNING: train %d (%s) runs backwards although the direction flag was already flipped"):format(train.id, train.service))
        end
        return
    end
    l.wrongWay = 0
    local drift = TracksData.ahead(t, train.s, s, true)
    if drift > t.length / 2 then drift = drift - t.length end
    if math.abs(drift) > 50 then
        -- Far from the timetable: never a jump to adopt. Put it back where it should be.
        sync(("train %d (%s): %.0f m from where the timetable had it: put back"):format(train.id, train.service, drift))
        return replace(train, l)
    end
    train.s = s
    Schedule.moved(train)
end

local function sendSpeed(train, l, v)
    local now = getTickCount()
    if math.abs(v - l.sent) < 0.05 and now - l.sentAt < 3000 then return end
    l.sent, l.sentAt = v, now
    setTrainSpeed(l.engine, v / 50) -- GTA units: m/s / 50
end

local function updateLive(train, l, players, dt)
    if not isElement(l.engine) then
        live[train] = nil
        return replaceTaken(train, players)
    end
    readBack(train, l)
    local controller = getVehicleController(l.engine)
    if train.state ~= "taken" then
        local driverGone = not isElement(l.driver) or isPedDead(l.driver) or getPedOccupiedVehicle(l.driver) ~= l.engine
        if controller and getElementType(controller) == "player" then take(train, l, controller)
        elseif driverGone then take(train, l, nil) end
    end
    if train.state == "taken" then
        local driving = controller and getElementType(controller) == "player"
        if not driving then
            -- Nobody at the controls: it brakes to a halt (and stays where it was left).
            train.v = math.max(0, train.v - CONFIG.decel * dt)
            sendSpeed(train, l, train.v)
        else
            train.v = math.abs((getTrainSpeed(l.engine) or 0) * 50)
        end
        local aboard = playerAboard(l)
        if aboard then
            l.abandonedAt = nil
        else
            l.abandonedAt = l.abandonedAt or getTickCount()
            local derailed = isTrainDerailed(l.engine)
            if (derailed or getTickCount() - l.abandonedAt > CONFIG.abandonedMs) and not nearestToTrain(train, players, CONFIG.despawn) then
                return replaceTaken(train, players)
            end
        end
        return
    end
    local owner, dist = nearestToTrain(train, players, CONFIG.despawn)
    if not owner and not playerAboard(l) then return dematerialize(train) end
    local ownerGone = not isElement(l.owner) or select(2, nearestToTrain(train, { l.owner })) > CONFIG.ownerRadius
    if owner and ownerGone and dist <= CONFIG.ownerRadius then setOwner(train, l, owner) end
end

local function tick()
    local players = eligiblePlayers()
    local now = getTickCount()
    local dt = CONFIG.tick / 1000
    for _, train in pairs(trains) do
        if live[train] then updateLive(train, live[train], players, dt) end
    end
    for _, train in pairs(trains) do Schedule.step(train, trains, dt, now) end
    for _, train in pairs(trains) do
        local l = live[train]
        if l and train.state ~= "taken" then sendSpeed(train, l, train.v) end
        if not l and enabled and train.state ~= "taken" then
            local owner = nearestToTrain(train, players, CONFIG.spawnRange)
            if owner then materialize(train, owner) end
        end
    end

    for ped, info in pairs(released) do
        if not isElement(ped) then
            released[ped] = nil
        elseif not isPedDead(ped) and not getPedOccupiedVehicle(ped) then
            local res = getResourceFromName("vana-peds")
            if res and getResourceState(res) == "running" then
                local ok, adopted = pcall(function()
                    return exports["vana-peds"]:adoptPed(ped, info.kind, nil, info.personality, info.encounter)
                end)
                if ok and adopted then released[ped] = nil end
            end
        end
        if isElement(ped) and released[ped] then
            local x, y, z = getElementPosition(ped)
            if not nearestPlayer(x, y, z, players, CONFIG.despawn) then
                released[ped] = nil
                destroyElement(ped)
            end
        end
    end
end

local function rebuild()
    for train in pairs(live) do dematerialize(train) end
    trains, lastId = Schedule.build(serviceCounts())
end

Settings.bind(counts, { freight = "number", passenger = "number", trams = "number" }, rebuild)
rebuild()
setTimer(tick, CONFIG.tick, 0)

addEventHandler("onPlayerQuit", root, function()
    for _, l in pairs(live) do if l.owner == source then l.owner = nil end end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for train in pairs(live) do dematerialize(train) end
end)

-- Admin control. Restricted: needs command.trains in the ACL (vana-player grants it to Admin).
addCommandHandler("trains", function(source, _, action, value)
    local reply = function(msg)
        if getElementType(source) == "console" then outputServerLog("[trains] " .. msg) else outputChatBox(msg, source, 200, 200, 255) end
    end
    if action == "on" then
        enabled = true
        reply("Trains appear near players again.")
    elseif action == "off" then
        enabled = false
        for train in pairs(live) do if train.state ~= "taken" then dematerialize(train) end end
        reply("Trains off: they keep running on the schedule, out of the world.")
    elseif action == "reset" then
        rebuild()
        reply("Trains reset: every train back at its start.")
    elseif action == "debug" then
        local core = getResourceFromName("vana-core")
        if not core or getResourceState(core) ~= "running" then return reply("Train debug needs vana-core (its /vanadebug switches).") end
        exports["vana-core"]:setDebug("vana-trains", value == "on" and "sync" or nil)
        reply("Train debug " .. (value == "on" and "on: train lines in the server log." or "off.") .. " (as /vanadebug trains sync)")
    elseif CONFIG.services[action] and tonumber(value) then
        local service = CONFIG.services[action]
        Settings.set(service.setting, math.max(0, math.min(8, math.floor(tonumber(value))))) -- kept across restarts
        reply(("%d %s trains (all trains reset)."):format(counts[service.setting], action))
    else
        local lines = {}
        for _, train in pairs(trains) do
            local x, y, z = TracksData.pointAt(Tracks[train.track], train.s)
            lines[#lines + 1] = ("%d %s %s %.0f km/h in %s%s"):format(train.id, train.service, train.state, train.v * 3.6,
                getZoneName(x, y, z), live[train] and " (in the world)" or "")
        end
        table.sort(lines)
        reply(("Trains are %s. Usage: /trains on|off|reset|freight|passenger|tram <count>|debug on|off"):format(enabled and "on" or "off"))
        for _, line in ipairs(lines) do reply(line) end
    end
end, true)
