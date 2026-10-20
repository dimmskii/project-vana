-- Server-owned traffic units. The server plans routes and light stops (planner.lua) and decides
-- encounters from the occupants' personalities; the owning client only executes native tasks
-- (client.lua). Occupants who end up on foot are handed to vana-peds: one population.
local paths = exports["vana-paths"]
local population = exports["vana-population"]
local rules = population:getPersonalityRules()

local CONFIG = {
    density = 1,                     -- multiplies vanilla popcycle targets
    maxPerPlayer = 30,               -- hard cap on traffic around one player
    spawnMin = 70, spawnMax = 160,   -- spawn ring around a player
    despawn = 250,                   -- removed once no player is this close
    ownerRadius = 200,               -- players eligible to simulate a unit
    unitSpacing = 20,
    tick = 500,
    cruise = 15, cruiseHighway = 22, -- native autopilot cruise speeds
    panicCruise = 30,
}
Settings.bind(CONFIG, { density = "number", maxPerPlayer = "number" }) -- meta.xml settings (/vanaset)

local units = {}      -- vehicle -> unit
local released = {}   -- elements no longer driven by us: peds -> spec (+ encounter), vehicles -> true
local enabled = true
-- vana-traffic:telemetry (docs/debug.md): vana-core's debug switch, on this resource's root element.
local function debugging()
    local v = getElementData(resourceRoot, "vana:debug")
    return v == "all" or (type(v) == "string" and ("," .. v .. ","):find(",telemetry,", 1, true) ~= nil)
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

-- Driver first, then passengers: { ped, spec } for every occupant we spawned.
local function occupants(unit)
    local list = { { ped = unit.ped, spec = unit.driver } }
    for _, p in ipairs(unit.passengers) do list[#list + 1] = p end
    return list
end

local function panicking(unit)
    return unit.panicUntil and getTickCount() < unit.panicUntil
end

local function sendTarget(unit, target)
    unit.target, unit.sentAt, unit.sends = target, getTickCount(), (unit.sends or 0) + 1
    if not isElement(unit.owner) then return end
    local speed = panicking(unit) and CONFIG.panicCruise or target.hold and CONFIG.cruise or unit.cruise
    local style = panicking(unit) and "avoid_cars" or "stop_for_cars_ignore_lights"
    triggerClientEvent(unit.owner, "vana-traffic:drive", resourceRoot, unit.vehicle, unit.ped,
        target.x, target.y, target.z, speed, target.mode, style)
end

local function setOwner(unit, owner)
    if unit.owner == owner then return end
    if isElement(unit.owner) then triggerClientEvent(unit.owner, "vana-traffic:release", resourceRoot, unit.vehicle, unit.ped) end
    unit.owner = owner
    if owner then
        setElementSyncer(unit.vehicle, owner, true, true)
        for _, o in ipairs(occupants(unit)) do
            if isElement(o.ped) then setElementSyncer(o.ped, owner, true, true) end
        end
        if unit.target then sendTarget(unit, unit.target) end
    end
end

local EXIT_RETRY_MS, EXIT_TRIES = 2000, 5 -- released occupants still seated: how often, how many times to tell them

local function releasePed(ped, spec, encounter)
    if not isElement(ped) then return end
    -- Back to automatic syncing: a ped (or body) nobody syncs freezes wherever it was.
    setElementSyncer(ped, true)
    released[ped] = { kind = spec.kind, gang = spec.gang, personality = spec.personality, encounter = encounter }
end

-- A car a player has been in is remembered by vana-vehicles and must never be cleaned up here.
local function kept(vehicle)
    return getElementData(vehicle, "vana:kept") ~= false and getElementData(vehicle, "vana:kept") ~= nil
end

-- How an occupant answers a threat, by kind and personality (config/personalities.lua):
-- "fight", "flee" or "stay". threat: "jacked" (pulled from the car / the car taken), "bail" (shot
-- at: everyone out), or "fight" (the driver gets out to fight: passengers choose for themselves).
local function respond(spec, kind, threat)
    local p = spec.personality or {}
    local fear, temper = p.fear or 50, p.temper or 50
    if kind == "cop" then return "fight" end
    if kind == "gang" then return fear >= 70 and "flee" or "fight" end
    if threat == "fight" then
        if temper >= rules.collision.fightTemper then return "fight" end
        return fear >= rules.collision.fleeFear and "flee" or "stay"
    end
    if threat == "jacked" and temper >= rules.collision.fightTemper and fear < rules.collision.fleeFear then return "fight" end
    return "flee"
end

local function encounterFor(spec, kind, threat, target, vehicle)
    local action = respond(spec, kind, threat)
    if action == "stay" then return nil end
    return { mode = action, target = target, vehicle = vehicle }
end

-- keepElements: leave vehicle and occupants in the world (occupants still inside are told to get out).
-- encounter: one encounter for the crew, or a function(occupant) giving each its own.
local function removeUnit(unit, keepElements, encounter)
    units[unit.vehicle] = nil
    if isElement(unit.vehicle) then removeElementData(unit.vehicle, "vana:trafficCar") end
    if isElement(unit.owner) then triggerClientEvent(unit.owner, "vana-traffic:release", resourceRoot, unit.vehicle, unit.ped) end
    if keepElements then
        local stillInside = {}
        for _, o in ipairs(occupants(unit)) do
            if isElement(o.ped) and getPedOccupiedVehicle(o.ped) == unit.vehicle then stillInside[#stillInside + 1] = o.ped end
            if type(encounter) == "function" then
                releasePed(o.ped, o.spec, o.encounter or encounter(o))
            else
                -- The driver (and a gang or cop crew) carries the encounter; other passengers go by
                -- their own answer, or just get out, unless everyone is bailing out.
                local shared = o.ped == unit.ped or unit.kind ~= "civilian" or (encounter and encounter.mode == "flee")
                releasePed(o.ped, o.spec, o.encounter or (shared and encounter or nil))
            end
        end
        if isElement(unit.vehicle) then
            setElementSyncer(unit.vehicle, true)
            released[unit.vehicle] = true
        end
        if #stillInside > 0 and isElement(unit.owner) then
            triggerClientEvent(unit.owner, "vana-traffic:exit", resourceRoot, unit.vehicle, stillInside)
        end
    else
        for _, o in ipairs(occupants(unit)) do
            if isElement(o.ped) then destroyElement(o.ped) end
        end
        if isElement(unit.vehicle) and kept(unit.vehicle) then
            -- Remembered: it stays where it is, driverless, out of everyone's sight.
            setElementSyncer(unit.vehicle, true)
            setVehicleEngineState(unit.vehicle, false)
        elseif isElement(unit.vehicle) then
            destroyElement(unit.vehicle)
        end
    end
end

-- What already drives around a point, by population kind (for vana-population's picks).
local function countsNear(x, y, z)
    local counts, total = { gangs = {} }, 0
    for _, unit in pairs(units) do
        local ux, uy, uz = getElementPosition(unit.vehicle)
        if getDistanceBetweenPoints3D(x, y, z, ux, uy, uz) < CONFIG.spawnMax + 40 then
            total = total + 1
            counts[unit.kind] = (counts[unit.kind] or 0) + 1
            if unit.gang then counts.gangs[unit.gang] = (counts.gangs[unit.gang] or 0) + 1 end
        end
    end
    return counts, total
end

-- Hands an on-foot former occupant to vana-peds, so car occupants and pedestrians are one population.
local function adoptAsPedestrian(ped, info)
    local res = getResourceFromName("vana-peds")
    if not res or getResourceState(res) ~= "running" then return false end
    local ok, adopted = pcall(function()
        return exports["vana-peds"]:adoptPed(ped, info.kind, info.gang, info.personality, info.encounter)
    end)
    return ok and adopted
end

local function spawnOccupant(spec, vehicle, seat, x, y, z)
    local ped = createPed(spec.model, x, y, z)
    if not ped then return false end
    if not warpPedIntoVehicle(ped, vehicle, seat) then destroyElement(ped) return false end
    if spec.weapon then giveWeapon(ped, spec.weapon, 500, false) end
    setElementData(ped, "vana:traffic", spec.kind)
    return ped
end

-- A unit around an existing vehicle and driver (spawned traffic, or a car a ped has just taken).
local function startUnit(vehicle, ped, driverSpec, passengers, kind, gang, route, owner)
    local x, y = getElementPosition(vehicle)
    local unit = {
        vehicle = vehicle, ped = ped, driver = driverSpec, passengers = passengers or {}, route = route,
        kind = kind, gang = gang,
        cruise = route[route.idx] and route[route.idx].highway and CONFIG.cruiseHighway or CONFIG.cruise,
        front = 2.5, -- until the owning client reports the model's real front length
        lastX = x, lastY = y, lastMoved = getTickCount(),
    }
    -- Server-created vehicles start with the engine off, and a native driver can't move them then.
    setVehicleEngineState(vehicle, true)
    -- The driver's favourite station, as vanilla (vana-vehicles).
    local res = getResourceFromName("vana-vehicles")
    if res and getResourceState(res) == "running" and isElement(ped) then
        pcall(function() exports["vana-vehicles"]:assignRadio(vehicle, getElementModel(ped)) end)
    end
    setElementData(vehicle, "vana:trafficCar", true)
    units[vehicle] = unit
    setOwner(unit, owner)
    return unit
end

local function trySpawnNear(player, players, counts)
    local px, py, pz = getElementPosition(player)
    local angle, r = math.random() * 2 * math.pi, CONFIG.spawnMin + math.random() * (CONFIG.spawnMax - CONFIG.spawnMin)
    local area, id = paths:findNearestNode(px + math.cos(angle) * r, py + math.sin(angle) * r, pz, "vehicle", 40)
    if not area then return false end

    local node = Planner.getNode(area, id)
    if not node or node.floodFill ~= 1 or node.spawnProbability == 0 or not Planner.isUsable(node, 1) then return false end
    local _, nearest = nearestPlayer(node.x, node.y, node.z, players)
    if nearest < CONFIG.spawnMin * 0.8 then return false end
    for _, unit in pairs(units) do
        local ux, uy, uz = getElementPosition(unit.vehicle)
        if getDistanceBetweenPoints3D(ux, uy, uz, node.x, node.y, node.z) < CONFIG.unitSpacing then return false end
    end

    local route = Planner.newRoute(area, id)
    if not route then return false end
    local nxt = route[2]
    local dx, dy = nxt.x - node.x, nxt.y - node.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.1 then return false end
    dx, dy = dx / len, dy / len

    -- Start in the right-hand lane when the road carries traffic both ways.
    local x, y = node.x, node.y
    local navi = nxt.link and nxt.link.naviArea and paths:getNaviNode(nxt.link.naviArea, nxt.link.naviIndex)
    if navi and navi.leftLanes > 0 and navi.rightLanes > 0 then
        x, y = x + dy * Planner.LANE_WIDTH / 2, y - dx * Planner.LANE_WIDTH / 2
    end

    -- Vanilla population rules decide what drives here (and who), or that the area is already full.
    local spec = population:pickCar(node.x, node.y, node.z, counts, CONFIG.density)
    if not spec then return false end

    local vehicle = createVehicle(spec.model, x, y, node.z + 1, 0, 0, math.deg(math.atan2(dy, dx)) - 90)
    if not vehicle then return false end
    -- Its parts, as vanilla's and ours make ambient cars (vana-vehicles).
    local vres = getResourceFromName("vana-vehicles")
    if vres and getResourceState(vres) == "running" then pcall(function() exports["vana-vehicles"]:tuneRandomly(vehicle) end) end
    local ped = spawnOccupant(spec.driver, vehicle, 0, x, y, node.z + 2)
    if not ped then destroyElement(vehicle) return false end
    local passengers = {}
    for seat = 1, math.min(#(spec.passengers or {}), getVehicleMaxPassengers(vehicle) or 0) do
        local passenger = spawnOccupant(spec.passengers[seat], vehicle, seat, x, y, node.z + 2)
        if passenger then passengers[#passengers + 1] = { ped = passenger, spec = spec.passengers[seat] } end
    end

    startUnit(vehicle, ped, spec.driver, passengers, spec.kind, spec.gang, route, player)
    return true
end

-- Hands a traffic unit over to another resource (the police taking over a patrol car for a chase):
-- the unit stops being traffic, but its vehicle and occupants stay as they are, owner included.
-- Returns the occupant peds, driver first.
function handOverUnit(vehicle)
    local unit = units[vehicle]
    if not unit or unit.exiting then return false end
    units[vehicle] = nil
    removeElementData(vehicle, "vana:trafficCar")
    if isElement(unit.owner) then triggerClientEvent(unit.owner, "vana-traffic:release", resourceRoot, vehicle, unit.ped) end
    local peds = {}
    for _, o in ipairs(occupants(unit)) do
        if isElement(o.ped) and not isPedDead(o.ped) then peds[#peds + 1] = o.ped end
    end
    return peds, unit.owner
end

-- A ped who has just taken a car (e.g. jacked a player's) drives off with it as traffic.
function adoptVehicle(vehicle, ped, kind, gang, personality)
    if units[vehicle] or not isElement(vehicle) or getVehicleOccupant(vehicle, 0) ~= ped then return false end
    local x, y, z = getElementPosition(vehicle)
    local owner = nearestPlayer(x, y, z, eligiblePlayers(), CONFIG.despawn)
    local area, id = paths:findNearestNode(x, y, z, "vehicle", 80)
    local route = owner and area and Planner.newRoute(area, id)
    if not route then return false end
    route.idx = 1
    released[ped], released[vehicle] = nil, nil
    setElementData(ped, "vana:traffic", kind or "civilian")
    local unit = startUnit(vehicle, ped, { kind = kind or "civilian", gang = gang, personality = personality }, {}, kind or "civilian", gang, route, owner)
    unit.panicUntil = getTickCount() + rules.collision.panicSeconds * 1000
    return true
end

-- Keeps a unit driving in a panic (fast, running lights) for the next `seconds`: a car being chased.
function panicUnit(vehicle, seconds)
    local unit = units[vehicle]
    if not unit then return false end
    unit.panicUntil = math.max(unit.panicUntil or 0, getTickCount() + (seconds or 10) * 1000)
    return true
end

local function updateUnit(unit, players, lightState)
    local vehicle, ped = unit.vehicle, unit.ped
    if not isElement(vehicle) then return removeUnit(unit) end
    if isVehicleBlown(vehicle) or not isElement(ped) or isPedDead(ped) or getPedOccupiedVehicle(ped) ~= vehicle
        or getVehicleOccupant(vehicle, 0) ~= ped then
        -- Jacked, killed, wrecked or got out: leave it all to the world (on-foot occupants become pedestrians).
        -- A player who took the car gets an answer from everyone in it: cops and gangs fight, civilians
        -- by temper and fear.
        local jacker = getVehicleController(vehicle)
        if not unit.exiting and jacker and getElementType(jacker) == "player" then
            return removeUnit(unit, true, function(o) return encounterFor(o.spec, unit.kind, "jacked", jacker) end)
        end
        return removeUnit(unit, true, unit.exiting)
    end
    -- Passengers who left on their own (or were pulled out) walk on separately.
    for i = #unit.passengers, 1, -1 do
        local p = unit.passengers[i]
        if not isElement(p.ped) or isPedDead(p.ped) or getPedOccupiedVehicle(p.ped) ~= vehicle then
            releasePed(p.ped, p.spec, p.encounter or (unit.kind ~= "civilian" and unit.exiting or nil))
            table.remove(unit.passengers, i)
        end
    end

    local x, y, z = getElementPosition(vehicle)
    local owner, ownerDist = nearestPlayer(x, y, z, players, CONFIG.despawn)
    if not owner then return removeUnit(unit) end
    local ownerGone = not isElement(unit.owner) or select(2, nearestPlayer(x, y, z, { unit.owner })) > CONFIG.ownerRadius
    if ownerGone and unit.owner ~= owner then setOwner(unit, owner) end
    if unit.exiting then
        -- Occupants are getting out; if the owner never makes them, carry on driving.
        if getTickCount() - unit.exitingAt < 8000 then return end
        unit.exiting = nil
    end

    local route = unit.route
    Planner.advance(route, x, y)
    if not Planner.extend(route) and route.idx >= #route then return removeUnit(unit) end
    -- Stuck turning back and forth in a dead-end fragment: let it go once nobody is close enough to notice.
    if (route.turnBacks or 0) > 3 and ownerDist > 80 then return removeUnit(unit) end

    local vx, vy, vz = getElementVelocity(vehicle)
    local speed = math.sqrt(vx * vx + vy * vy + vz * vz) * 50
    -- Panicking drivers run lights (state 9: lights off).
    local target = Planner.chooseTarget(route, x, y, speed, panicking(unit) and 9 or lightState, unit.front)
    local panicChanged = unit.wasPanicking ~= panicking(unit)
    unit.wasPanicking = panicking(unit)
    if panicChanged or Planner.needsNewTarget(unit.target, target, x, y, getTickCount() - (unit.sentAt or 0)) then
        sendTarget(unit, target)
    end

    -- Stuck recovery: re-send the target, then give up when nobody is close enough to notice.
    local now = getTickCount()
    if getDistanceBetweenPoints2D(x, y, unit.lastX, unit.lastY) > 2 or target.hold then
        unit.lastX, unit.lastY, unit.lastMoved = x, y, now
    elseif now - unit.lastMoved > 20000 then
        if ownerDist > 60 and now - unit.lastMoved > 45000 then return removeUnit(unit) end
        if not unit.retried or now - unit.retried > 20000 then
            unit.retried = now
            sendTarget(unit, target)
        end
    end
end

setTimer(function()
    local players = eligiblePlayers()
    local lightState = getTrafficLightState()
    for _, unit in pairs(units) do updateUnit(unit, players, lightState) end

    for element, info in pairs(released) do
        if not isElement(element) then
            released[element] = nil
        elseif getElementType(element) == "ped" and not isPedDead(element) and not getPedOccupiedVehicle(element)
            and adoptAsPedestrian(element, info) then
            -- An occupant out of the car (pulled out, fled, crashed, picking a fight) walks on as a pedestrian.
            released[element] = nil
        elseif getElementType(element) == "ped" and not isPedDead(element) and getPedOccupiedVehicle(element) then
            -- Still seated (a passenger of a jacked car, say): told to get out again, by whoever syncs it
            -- now, every EXIT_RETRY_MS; after EXIT_TRIES, taken out of the car (then adopted above).
            local now = getTickCount()
            if now - (info.exitAt or 0) >= EXIT_RETRY_MS then
                info.exitAt, info.exitTries = now, (info.exitTries or 0) + 1
                local vehicle = getPedOccupiedVehicle(element)
                if info.exitTries > EXIT_TRIES then
                    removePedFromVehicle(element)
                    local vx, vy, vz = getElementPosition(vehicle)
                    local ex, ey, ez = getElementPosition(element)
                    -- Beside the car, on its side, rather than inside it.
                    local dx, dy = ex - vx, ey - vy
                    local len = math.max(0.1, math.sqrt(dx * dx + dy * dy))
                    setElementPosition(element, vx + dx / len * 2.2, vy + dy / len * 2.2, math.max(ez, vz) + 0.3)
                else
                    local to = getElementSyncer(element)
                    if not isElement(to) then
                        local px, py, pz = getElementPosition(element)
                        to = nearestPlayer(px, py, pz, players)
                    end
                    if isElement(to) then triggerClientEvent(to, "vana-traffic:exit", resourceRoot, vehicle, { element }) end
                end
            end
        else
            local x, y, z = getElementPosition(element)
            local occupied = getElementType(element) == "vehicle" and next(getVehicleOccupants(element) or {})
            if not occupied and not nearestPlayer(x, y, z, players, CONFIG.despawn) and not (getElementType(element) == "vehicle" and kept(element)) then
                released[element] = nil
                destroyElement(element)
            end
        end
    end

    if not enabled then return end
    for _, player in ipairs(players) do
        local counts, total = countsNear(getElementPosition(player))
        if total < CONFIG.maxPerPlayer then trySpawnNear(player, players, counts) end
    end
end, CONFIG.tick, 0)

-- A player hit, kicked or shot one of our cars or its occupants: kind and the driver's personality
-- decide (config/personalities.lua). incident: "collision" (magnitude = collision force), "melee" or "shot".
local function decide(unit, player, incident, magnitude)
    local r = rules.collision
    local p = unit.driver.personality or {}
    local fear, temper = p.fear or 50, p.temper or 50
    -- A gun pointed at the car: crews fight, civilians abandon the car (fear), fight (temper) or speed off.
    if incident == "aimed" then
        if unit.kind ~= "civilian" then return "fight", 100 end
        if fear >= r.bailFear then return "bail", 100 end
        return temper >= r.jackTemper and "fight" or "panic", 100
    end
    local severity = incident == "shot" and 100 or incident == "melee" and r.meleeSeverity
        or math.min(100, (magnitude or 0) / r.forcePerSeverity)
    if severity < r.ignoreBelow then return "ignore", severity end
    if incident == "shot" then
        if unit.kind ~= "civilian" then return "fight", severity end
        return fear >= r.bailFear and "bail" or "panic", severity
    end
    if unit.kind ~= "civilian" and temper >= r.fightTemper - 15 then return "fight", severity end
    if fear >= r.fleeFear then return "panic", severity end
    if temper >= r.fightTemper or (severity >= r.angerSeverity and temper >= r.fightTemper - 15) then
        local theirCar = getPedOccupiedVehicle(player)
        if theirCar and getVehicleOccupant(theirCar, 0) == player and temper >= r.jackTemper and math.random() < r.jackChance then
            return "jack", severity
        end
        return "fight", severity
    end
    return "honk", severity
end


-- Forwards a crime to vana-services (wanted levels), when it runs.
local function reportCrime(player, crime, x, y, z)
    local res = getResourceFromName("vana-services")
    if not res or getResourceState(res) ~= "running" then return end
    pcall(function() exports["vana-services"]:reportCrime(player, crime, x, y, z) end)
end

addEvent("vana-traffic:incident", true)
addEventHandler("vana-traffic:incident", resourceRoot, function(vehicle, player, incident, magnitude)
    local unit = units[vehicle]
    if not unit or unit.exiting or not isElement(player) or getElementType(player) ~= "player" then return end
    -- Reported by the car's owner, or by the player who caused it.
    if client ~= unit.owner and client ~= player then return end
    if incident ~= "collision" and incident ~= "melee" and incident ~= "shot" and incident ~= "aimed" then return end
    local x, y, z = getElementPosition(vehicle)
    local px, py, pz = getElementPosition(player)
    if getDistanceBetweenPoints3D(x, y, z, px, py, pz) > (incident == "shot" and 120 or 30) then return end
    local now = getTickCount()
    if unit.lastIncident and now - unit.lastIncident < 3000 then return end

    local action, severity = decide(unit, player, incident, tonumber(magnitude))
    if incident ~= "aimed" and (incident ~= "collision" or severity >= rules.collision.ignoreBelow) then
        reportCrime(player, unit.kind == "cop" and "damage_cop_car" or incident == "collision" and "hit_car" or "damage_car", x, y, z)
    end
    if debugging() then
        outputServerLog(("[traffic-debug] %s by %s on %s: severity %.0f -> %s"):format(incident, getPlayerName(player),
            getVehicleNameFromModel(getElementModel(vehicle)), severity, action))
    end
    if action == "ignore" then return end
    unit.lastIncident = now

    if action == "panic" then
        unit.panicUntil = now + rules.collision.panicSeconds * 1000
    elseif action == "honk" then
        triggerClientEvent(unit.owner, "vana-traffic:honk", resourceRoot, unit.ped)
    else
        local encounter = { mode = action == "bail" and "flee" or "fight", target = player }
        if action == "jack" then encounter = { mode = "jack", target = player, vehicle = getPedOccupiedVehicle(player) } end
        -- Gang and cop crews pile out with the driver; when bailing, everyone gets out. Civilian
        -- passengers of a driver picking a fight join in, run, or stay put, each by personality.
        unit.exiting, unit.exitingAt = encounter, now
        local peds = { unit.ped }
        for _, o in ipairs(unit.passengers) do
            if unit.kind ~= "civilian" or action == "bail" then
                peds[#peds + 1] = o.ped
            elseif action == "fight" then
                o.encounter = encounterFor(o.spec, unit.kind, "fight", player)
                if o.encounter then peds[#peds + 1] = o.ped end
            end
        end
        triggerClientEvent(unit.owner, "vana-traffic:exit", resourceRoot, vehicle, peds)
    end
end)

addEventHandler("onPlayerQuit", root, function()
    for _, unit in pairs(units) do
        if unit.owner == source then unit.owner = nil end
    end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for _, unit in pairs(units) do removeUnit(unit) end
end)

-- Admin control. Restricted: needs command.traffic in the ACL (see docs/setup.md).
addCommandHandler("traffic", function(source, _, action, value)
    local reply = function(msg)
        if getElementType(source) == "console" then outputServerLog("[traffic] " .. msg) else outputChatBox(msg, source, 200, 200, 255) end
    end
    local count = 0
    for _ in pairs(units) do count = count + 1 end
    if action == "on" then
        enabled = true
        reply("Traffic spawning on.")
    elseif action == "off" then
        enabled = false
        reply("Traffic spawning off; existing traffic drives on until out of range.")
    elseif action == "clear" then
        for _, unit in pairs(units) do removeUnit(unit) end
        reply(("Removed %d traffic vehicles."):format(count))
    elseif action == "debug" then
        local core = getResourceFromName("vana-core")
        if not core or getResourceState(core) ~= "running" then return reply("Traffic debug needs vana-core (its /vanadebug switches).") end
        exports["vana-core"]:setDebug("vana-traffic", value == "on" and "telemetry" or nil)
        reply("Traffic debug telemetry " .. (value == "on" and "on: slow units are logged to the server log." or "off.") .. " (as /vanadebug traffic)")
    elseif action == "density" and tonumber(value) then
        Settings.set("density", math.max(0, math.min(300, tonumber(value))) / 100) -- kept across restarts
        reply(("Traffic density set to %d%% of vanilla."):format(CONFIG.density * 100))
    else
        reply(("Traffic is %s: %d vehicles, density %d%% of vanilla. Usage: /traffic on|off|clear|density <percent>|debug on|off")
            :format(enabled and "on" or "off", count, CONFIG.density * 100))
    end
end, true)

-- The owning client reports the distance from the vehicle's position to its front bumper.
addEvent("vana-traffic:front", true)
addEventHandler("vana-traffic:front", resourceRoot, function(vehicle, front)
    local unit = units[vehicle]
    if not unit or unit.owner ~= client or type(front) ~= "number" then return end
    unit.front = math.max(1, math.min(8, front))
end)

-- Debug telemetry from owning clients: { vehicle, speed (m/s), native autopilot fields } per unit.
addEvent("vana-traffic:telemetry", true)
addEventHandler("vana-traffic:telemetry", resourceRoot, function(samples)
    if not debugging() or type(samples) ~= "table" then return end
    for _, sample in ipairs(samples) do
        local unit = type(sample) == "table" and units[sample.vehicle]
        if unit and unit.owner == client and unit.target and not unit.target.hold and (tonumber(sample.speed) or 99) < 4 then
            local x, y, z = getElementPosition(unit.vehicle)
            local ox, oy, oz = getElementPosition(client)
            local road = unit.route[unit.route.idx]
            outputServerLog(("[traffic-debug] slow %s at %s (%.0f, %.0f, %.0f, road z %.0f, owner %.0fm): %.1f m/s, target %.0fm %s, sends %d, mission %s, temp %s, stuck %s, style %s")
                :format(getVehicleNameFromModel(getElementModel(unit.vehicle)), getZoneName(x, y, z), x, y, z, road and road.z or -1,
                    getDistanceBetweenPoints3D(x, y, z, ox, oy, oz), sample.speed,
                    getDistanceBetweenPoints2D(x, y, unit.target.x, unit.target.y), unit.target.mode, unit.sends or 0,
                    tostring(sample.mission), tostring(sample.temp), tostring(sample.stuck), tostring(sample.style)))
        end
    end
end)
