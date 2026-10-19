-- Emergency services: wanted levels with the police response (cars, SWAT, FBI, army, helicopter,
-- roadblocks), ambulances for bodies and fire trucks for wrecks. The server runs each responder's
-- state machine; the owning client runs native tasks (client.lua).
local paths = exports["vana-paths"]
local population = exports["vana-population"]

local CONFIG = {
    tick = 500,
    dispatchMin = 140, dispatchMax = 200,  -- responders start on a road this far away, out of sight
    despawn = 230,
    arriveDistance = 20,
    engageDistance = 25,                   -- crews get out when this close to an on-foot player
    rechaseDistance = 70,                  -- crews on foot get back in when the player gets this far
    responseSpeed = 30,
}

local POLICE_UNITS = { police = true, swat = true, fbi = true, army = true, tank = true }

local responders = {}   -- vehicle -> responder
local roadblocks = {}   -- list of { player, vehicles, cops, at }
local wanted = {}       -- player -> { chaos, lastDecay, lastRoadblock }
local recentCalls = {}  -- recent medic/fire call positions { kind, x, y, z, at }

local function eligiblePlayers()
    local list = {}
    for _, player in ipairs(getElementsByType("player")) do
        if getElementDimension(player) == 0 and getElementInterior(player) == 0 and not isPedDead(player) then list[#list + 1] = player end
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

local function running(name)
    local res = getResourceFromName(name)
    return res and getResourceState(res) == "running"
end

local function weightedPick(weights)
    local total = 0
    for _, w in pairs(weights) do total = total + w end
    local r = math.random() * total
    for key, w in pairs(weights) do
        r = r - w
        if r <= 0 then return key end
    end
    return next(weights)
end

---------------------------------------------------------------------------------------------------
-- Wanted levels

local function levelFor(chaos)
    local level = 0
    for i, threshold in ipairs(Wanted.thresholds) do
        if chaos >= threshold then level = i end
    end
    return level
end

local function addChaos(player, points, minStars)
    local w = wanted[player] or { chaos = 0, lastDecay = getTickCount() }
    wanted[player] = w
    w.chaos = w.chaos + points
    if minStars and minStars > 0 then w.chaos = math.max(w.chaos, Wanted.thresholds[minStars]) end
    setPlayerWantedLevel(player, levelFor(w.chaos))
end

local function isCop(ped)
    return isElement(ped) and not isPedDead(ped)
        and (getElementData(ped, "vana:ambient") == "cop" or getElementData(ped, "vana:traffic") == "cop" or getElementData(ped, "vana:service") == "police")
end

local function copWithin(x, y, z, radius)
    for _, ped in ipairs(getElementsWithinRange(x, y, z, radius, "ped")) do
        if isCop(ped) then return true end
    end
    return false
end

-- A crime counts if a cop sees it; otherwise a civilian may call it in a little later. Crimes
-- against the police raise the level to at least Wanted.minStars at once.
function reportCrime(player, crime, x, y, z)
    local points = Wanted.crimes[crime]
    if not points or not isElement(player) or getElementType(player) ~= "player" then return false end
    if not x then x, y, z = getElementPosition(player) end
    local minStars = Wanted.minStars[crime]
    if copWithin(x, y, z, Wanted.witnessRadius) then
        -- Vanilla CCrime::ReportCrime: anything the police see makes you wanted at once.
        addChaos(player, points, math.max(minStars or 0, 1))
    elseif minStars then
        addChaos(player, points, minStars)
    elseif crime ~= "hit_car" and math.random() < Wanted.reportChance then
        setTimer(function() if isElement(player) then addChaos(player, points) end end, Wanted.reportDelay, 1)
    end
    return true
end

-- Raises the wanted level to at least this many stars (vanilla alter_wanted_level_no_drop); for
-- activities, e.g. a burglar who stays too long after being seen.
function setMinimumWanted(player, stars)
    if not isElement(player) or getElementType(player) ~= "player" or not Wanted.thresholds[stars] then return false end
    addChaos(player, 0, stars)
    return true
end

-- Peds (players and cops) knocked down or getting up, as reported by the clients simulating them.
local down = {}

addEvent("vana-services:down", true)
addEventHandler("vana-services:down", resourceRoot, function(states)
    if type(states) ~= "table" then return end
    for ped, isDown in pairs(states) do
        -- Only the client simulating a ped (or the player themselves) may report it.
        if isElement(ped) and (ped == client or getElementSyncer(ped) == client) then down[ped] = isDown or nil end
    end
end)

addEventHandler("onElementDestroy", root, function() down[source] = nil end)
addEventHandler("onPlayerQuit", root, function() down[source] = nil end)

-- Cops arrest while the player is under two stars with nothing in hand (melee weapons count);
-- otherwise they shoot. This baseline is meant to grow (surrendering, and so on).
function getCopMode(player)
    local level = getPlayerWantedLevel(player)
    return (level <= 1 and (getPedWeapon(player) or 0) == 0) and "arrest" or "fight"
end

local function copStandingWithin(x, y, z, radius)
    for _, ped in ipairs(getElementsWithinRange(x, y, z, radius, "ped")) do
        if isCop(ped) and not down[ped] and not getPedOccupiedVehicle(ped) then return true end
    end
    return false
end

-- Busted: in arrest mode, a cop on his feet right next to the player, who is on foot, up, and
-- (nearly) standing still.
local bustTimers = {}
local function checkBusted(player, now)
    local x, y, z = getElementPosition(player)
    local vx, vy = getElementVelocity(player)
    local still = not getPedOccupiedVehicle(player) and not down[player] and (vx * vx + vy * vy) * 2500 < Wanted.bustMaxSpeed ^ 2
    if still and getCopMode(player) == "arrest" and copStandingWithin(x, y, z, Wanted.bustRadius) then
        bustTimers[player] = bustTimers[player] or now
        if now - bustTimers[player] >= Wanted.bustMs and running("vana-player") then
            bustTimers[player] = nil
            local ok, busted = pcall(function() return exports["vana-player"]:bustPlayer(player) end)
            if ok and busted then
                wanted[player] = nil
                setPlayerWantedLevel(player, 0)
            end
        end
    else
        bustTimers[player] = nil
    end
end

local function updateWanted(player, now)
    local w = wanted[player]
    if not w then return 0 end
    if now - w.lastDecay >= 1000 then
        w.lastDecay = now
        local x, y, z = getElementPosition(player)
        if not copWithin(x, y, z, Wanted.presenceRadius) then
            local _, zone = population:getZoneAt(x, y, z)
            local elusive = zone and (zone.type == "countryside" or zone.type == "desert")
            w.chaos = math.max(0, w.chaos - Wanted.decayPerSecond * (elusive and 2 or 1))
        end
    end
    local level = levelFor(w.chaos)
    if getPlayerWantedLevel(player) ~= level then setPlayerWantedLevel(player, level) end
    if w.chaos == 0 then wanted[player] = nil end
    return level
end

addEventHandler("onPlayerWasted", root, function()
    wanted[source] = nil
    setPlayerWantedLevel(source, 0)
end)

addEventHandler("onPlayerQuit", root, function() wanted[source] = nil end)

-- Taking someone's car.
addEventHandler("onPlayerVehicleEnter", root, function(vehicle, seat, jacked)
    if seat == 0 and isElement(jacked) and getElementType(jacked) == "ped" then
        local copKind = getElementData(jacked, "vana:service") or getElementData(jacked, "vana:traffic")
        reportCrime(source, (copKind == "police" or copKind == "cop") and "jack_cop" or "car_steal")
    end
end)

---------------------------------------------------------------------------------------------------
-- Responders: a vehicle and crew sent by the server, run by the nearest player's client.

local function send(r, event, ...)
    if isElement(r.owner) then triggerClientEvent(r.owner, event, resourceRoot, ...) end
end

local function setOwner(r, owner)
    if r.owner == owner then return end
    r.owner = owner
    if not owner then return end
    setElementSyncer(r.vehicle, owner, true, true)
    for _, ped in ipairs(r.crew) do
        if isElement(ped) then setElementSyncer(ped, owner, true, true) end
    end
    r.lastOrder = nil -- re-issue the current orders to the new owner
    if r.kind == "heli" then send(r, "vana-services:heli", r.vehicle, r.crew, r.target, r.state == "leaving") end
end

local function driveTo(r, x, y, z, mode)
    r.driveTarget = { x, y, z }
    send(r, "vana-services:drive", r.vehicle, r.crew[1], x, y, z, CONFIG.responseSpeed, mode or "normal")
end

-- Crew on foot become ordinary pedestrians (vana-peds); the vehicle is left to the world.
local function release(r)
    responders[r.vehicle] = nil
    send(r, "vana-services:release", r.vehicle, r.crew)
    for _, ped in ipairs(r.crew) do
        if isElement(ped) then
            setElementSyncer(ped, true)
            removeElementData(ped, "vana:service")
            if not isPedDead(ped) and not getPedOccupiedVehicle(ped) and running("vana-peds") then
                local kind = POLICE_UNITS[r.kind] and "cop" or "civilian"
                pcall(function() exports["vana-peds"]:adoptPed(ped, kind) end)
            end
        end
    end
    if isElement(r.vehicle) then
        setVehicleSirensOn(r.vehicle, false)
        setElementSyncer(r.vehicle, true)
    end
end

local function destroyResponder(r)
    responders[r.vehicle] = nil
    for _, ped in ipairs(r.crew) do
        if isElement(ped) then destroyElement(ped) end
    end
    -- A car a player has been in is remembered by vana-vehicles: it stays.
    if isElement(r.vehicle) and not getElementData(r.vehicle, "vana:kept") then destroyElement(r.vehicle) end
end

-- A road node out of sight of every player, between dispatchMin and dispatchMax from (x, y).
local function roadSpawnNear(x, y, z, players)
    for _ = 1, 12 do
        local angle = math.random() * 2 * math.pi
        local r = CONFIG.dispatchMin + math.random() * (CONFIG.dispatchMax - CONFIG.dispatchMin)
        local area, id = paths:findNearestNode(x + math.cos(angle) * r, y + math.sin(angle) * r, z, "vehicle", 40)
        local node = area and paths:getNode(area, id)
        if node and node.floodFill == 1 and not node.boats then
            local _, nearest = nearestPlayer(node.x, node.y, node.z, players)
            if nearest > 100 then return node end
        end
    end
    return false
end

-- kind: police | swat | fbi | army | tank | medics | fire; level picks police weapons.
local function spawnResponder(kind, x, y, z, players, owner, level)
    local node = roadSpawnNear(x, y, z, players)
    if not node then return false end
    local unit = population:getServiceUnit(x, y, z, kind)
    local crewRules = Wanted.crews[kind] or { size = 2 }
    local heading = math.deg(math.atan2(y - node.y, x - node.x)) - 90
    local vehicle = createVehicle(unit.car, node.x, node.y, node.z + 1, 0, 0, heading)
    if not vehicle then return false end
    setVehicleEngineState(vehicle, true)
    setVehicleSirensOn(vehicle, true)
    local weapon = crewRules.weapon
    if kind == "police" and level and level >= 3 and crewRules.weaponFrom3Stars then weapon = crewRules.weaponFrom3Stars end
    local crew = {}
    for seat = 0, math.min(crewRules.size, (getVehicleMaxPassengers(vehicle) or 1) + 1) - 1 do
        local ped = createPed(unit.ped, node.x, node.y, node.z + 2)
        if ped and warpPedIntoVehicle(ped, vehicle, seat) then
            setElementData(ped, "vana:service", POLICE_UNITS[kind] and "police" or kind)
            setElementData(ped, "vana:traffic", POLICE_UNITS[kind] and "cop" or "civilian") -- drops on death
            if weapon then giveWeapon(ped, weapon, 500, false) end
            if POLICE_UNITS[kind] then giveWeapon(ped, 3, 1, false) end
            if kind == "fire" then giveWeapon(ped, 42, 5000, true) end
            crew[#crew + 1] = ped
        elseif ped then
            destroyElement(ped)
        end
    end
    if #crew == 0 then destroyElement(vehicle) return false end
    local r = { kind = kind, vehicle = vehicle, crew = crew, state = "driving", since = getTickCount() }
    responders[vehicle] = r
    setOwner(r, owner)
    return r
end

-- The strongest gun a ped carries: rifles (5), SMGs (4), shotguns (3), handguns (2); else the nightstick.
local function bestGunSlot(ped)
    for _, slot in ipairs({ 5, 4, 3, 2 }) do
        if (getPedWeapon(ped, slot) or 0) > 0 then return slot end
    end
    return 1
end

local function crewAlive(r)
    local alive = {}
    for _, ped in ipairs(r.crew) do
        if isElement(ped) and not isPedDead(ped) then alive[#alive + 1] = ped end
    end
    return alive
end

local function allInVehicle(r)
    for _, ped in ipairs(crewAlive(r)) do
        if getPedOccupiedVehicle(ped) ~= r.vehicle then return false end
    end
    return true
end

local function allOnFoot(r)
    for _, ped in ipairs(crewAlive(r)) do
        if getPedOccupiedVehicle(ped) then return false end
    end
    return true
end

local function distanceTo(element, x, y, z)
    local ex, ey, ez = getElementPosition(element)
    return getDistanceBetweenPoints3D(ex, ey, ez, x, y, z)
end

-- Leaving: drive away from everyone and disappear out of range.
local function leave(r, players)
    r.state, r.since = "leaving", getTickCount()
    setVehicleSirensOn(r.vehicle, false)
    if r.kind == "heli" then return send(r, "vana-services:heli", r.vehicle, r.crew, r.target, true) end
    local x, y, z = getElementPosition(r.vehicle)
    local node = roadSpawnNear(x, y, z, players)
    if node then driveTo(r, node.x, node.y, node.z) end
end

local function regroup(r)
    r.state, r.since = "regrouping", getTickCount()
    for seat, ped in ipairs(r.crew) do
        if isElement(ped) and not isPedDead(ped) and not getPedOccupiedVehicle(ped) then
            send(r, "vana-services:enter", ped, r.vehicle, seat - 1)
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Police units: pursue, get out and arrest (one star) or fight (more), get back in when the
-- player gets away. Tanks never get out: they keep driving at the player.

-- A player drove off in the unit's car: whoever is on foot fights them; once they're away, the
-- crew stays behind as walking cops (vana-peds) instead of waiting to get back into a car that's gone.
local function stolenBy(r)
    local driver = isElement(r.vehicle) and getVehicleController(r.vehicle)
    return driver and getElementType(driver) == "player" and driver
end

local function updatePolice(r, players, now)
    local thief = stolenBy(r)
    if thief then
        if r.target ~= thief or r.state ~= "engaging" then
            r.target, r.state, r.since, r.mode, r.ordered, r.stolen = thief, "engaging", now, nil, nil, true
        end
    elseif r.stolen then
        return release(r)
    end
    local target = r.target
    local level = isElement(target) and getPlayerWantedLevel(target) or 0
    if r.state ~= "leaving" and not r.stolen and (level == 0 or isPedDead(target)) then
        if allInVehicle(r) then return leave(r, players) end
        if r.state ~= "regrouping" then regroup(r) end
    end

    if r.state == "driving" then
        local tx, ty, tz = getElementPosition(target)
        local car = getPedOccupiedVehicle(target)
        if r.kind ~= "tank" and not car and distanceTo(r.vehicle, tx, ty, tz) < CONFIG.engageDistance then
            r.state, r.since = "engaging", now
            send(r, "vana-services:exit", r.vehicle, crewAlive(r))
        elseif not r.driveTarget or getDistanceBetweenPoints3D(tx, ty, tz, unpack(r.driveTarget)) > 10 or not r.lastOrder or now - r.lastOrder > 4000 then
            r.lastOrder = now
            driveTo(r, tx, ty, tz)
        end
    elseif r.state == "engaging" then
        if allOnFoot(r) or now - r.since > 6000 then
            -- Arresting: nightsticks out to beat the player down for the bust. Otherwise guns.
            local mode = getCopMode(target)
            -- Orders go out when the mode changes (or a crew member is new to the fight), not on a timer:
            -- re-issuing attack tasks to peds already attacking is what can crash GTA's seek task.
            if mode ~= r.mode or not r.lastOrder or (r.ordered or 0) < #crewAlive(r) then
                r.mode, r.lastOrder, r.ordered = mode, now, #crewAlive(r)
                for _, ped in ipairs(crewAlive(r)) do
                    if not getPedOccupiedVehicle(ped) then
                        setPedWeaponSlot(ped, mode == "arrest" and 1 or bestGunSlot(ped))
                        send(r, "vana-services:kill", ped, target)
                    end
                end
            end
            -- The player got away (in a car, or just far): back in and after them, unless they
            -- took the car itself.
            local tx, ty, tz = getElementPosition(target)
            if r.stolen then
                local away = true
                for _, ped in ipairs(crewAlive(r)) do
                    if distanceTo(ped, tx, ty, tz) < CONFIG.rechaseDistance then away = false end
                end
                if away then return release(r) end
            elseif distanceTo(r.vehicle, tx, ty, tz) > CONFIG.rechaseDistance then
                regroup(r)
            end
        end
    elseif r.state == "regrouping" then
        if allInVehicle(r) or now - r.since > 20000 then
            if level > 0 and allInVehicle(r) then
                r.state, r.lastOrder = "driving", nil
            elseif allInVehicle(r) then
                leave(r, players)
            else
                release(r) -- the crew couldn't get back in: they stay as walking cops
            end
        end
    end
end

-- Keep each wanted player's pursuit at the vanilla size, with the units their level calls for.
local function dispatchPolice(player, level, players)
    local want = Wanted.pursuit[level].cars
    local have = 0
    for _, r in pairs(responders) do
        if POLICE_UNITS[r.kind] and r.target == player and r.state ~= "leaving" then have = have + 1 end
    end
    if have >= want then return end
    local x, y, z = getElementPosition(player)
    local r = spawnResponder(weightedPick(Wanted.units[level]), x, y, z, players, player, level)
    if r then r.target = player end
end

-- Walking cops near a wanted player: arrest or fight (getCopMode).
local function engageWalkingCops(player, level)
    if not running("vana-peds") then return end
    local x, y, z = getElementPosition(player)
    local mode = getCopMode(player)
    for _, ped in ipairs(getElementsWithinRange(x, y, z, Wanted.engageRadius, "ped")) do
        if getElementData(ped, "vana:ambient") == "cop" and not isPedDead(ped) then
            pcall(function() exports["vana-peds"]:engagePed(ped, mode, player) end)
        end
    end
end

-- Patrol cars already in traffic near a wanted player join the chase.
local function recruitPatrols(player, players)
    if not running("vana-traffic") then return end
    local x, y, z = getElementPosition(player)
    for _, vehicle in ipairs(getElementsWithinRange(x, y, z, Wanted.recruitRadius, "vehicle")) do
        local driver = getElementData(vehicle, "vana:trafficCar") and getVehicleOccupant(vehicle, 0)
        if driver and getElementData(driver, "vana:traffic") == "cop" then
            local ok, peds = pcall(function() return exports["vana-traffic"]:handOverUnit(vehicle) end)
            if ok and peds and #peds > 0 then
                for _, ped in ipairs(peds) do
                    setElementData(ped, "vana:service", "police")
                    giveWeapon(ped, 3, 1, false)
                end
                setVehicleSirensOn(vehicle, true)
                local r = { kind = "police", vehicle = vehicle, crew = peds, state = "driving", since = getTickCount(), target = player }
                responders[vehicle] = r
                setOwner(r, player)
            end
        end
    end
end

-- Hits on service crews (reported by the client simulating them) are crimes like any other.
addEvent("vana-services:crewHit", true)
addEventHandler("vana-services:crewHit", resourceRoot, function(ped, attacker, weapon)
    local service = isElement(ped) and getElementData(ped, "vana:service")
    if not service or getElementSyncer(ped) ~= client or not isElement(attacker) or getElementType(attacker) ~= "player" then return end
    local stab = weapon == 4
    local crime = service == "police" and (stab and "stab_cop" or "damaged_cop") or (stab and "stab_ped" or "damaged_ped")
    local x, y, z = getElementPosition(ped)
    reportCrime(attacker, crime, x, y, z)
end)

---------------------------------------------------------------------------------------------------
-- Police helicopter: flown by the owning client around the player; the gunner fires drive-by.

local function dispatchHeli(player, level, players)
    if level < Wanted.heliFromStars then return end
    for _, r in pairs(responders) do
        if r.kind == "heli" and r.target == player and r.state ~= "leaving" then return end
    end
    local x, y, z = getElementPosition(player)
    local angle = math.random() * 2 * math.pi
    local hx, hy = x + math.cos(angle) * CONFIG.dispatchMax, y + math.sin(angle) * CONFIG.dispatchMax
    local unit = population:getServiceUnit(x, y, z, "heli")
    local vehicle = createVehicle(unit.car, hx, hy, z + 60, 0, 0, math.deg(math.atan2(y - hy, x - hx)) - 90)
    if not vehicle then return end
    setVehicleEngineState(vehicle, true)
    local crew = {}
    for seat = 0, 1 do
        local ped = createPed(unit.ped, hx, hy, z + 62)
        if ped and warpPedIntoVehicle(ped, vehicle, seat) then
            setElementData(ped, "vana:service", "police")
            setElementData(ped, "vana:traffic", "cop")
            if seat == 1 then giveWeapon(ped, Wanted.heliWeapon, 9999, true) end
            crew[#crew + 1] = ped
        elseif ped then
            destroyElement(ped)
        end
    end
    local r = { kind = "heli", vehicle = vehicle, crew = crew, state = "pursuing", since = getTickCount(), target = player }
    responders[vehicle] = r
    setOwner(r, player)
end

local function updateHeli(r, players, now)
    local level = isElement(r.target) and getPlayerWantedLevel(r.target) or 0
    if r.state ~= "leaving" and (level < Wanted.heliFromStars or isPedDead(r.target)) then leave(r, players) end
end

---------------------------------------------------------------------------------------------------
-- Roadblocks: two police cars across the road ahead of a wanted player in a vehicle, cops behind
-- them shooting as the player comes through.

local function clearRoadblock(i)
    local rb = table.remove(roadblocks, i)
    for _, e in ipairs(rb.elements) do
        if isElement(e) and not getElementData(e, "vana:kept") then destroyElement(e) end
    end
end

local function tryRoadblock(player, level, players, now)
    local w = wanted[player]
    local car = getPedOccupiedVehicle(player)
    if not w or not car or (w.lastRoadblock and now - w.lastRoadblock < Wanted.roadblockEveryMs) then return end
    w.lastRoadblock = now
    if math.random(100) > (Wanted.roadblockChance[level] or 0) then return end

    local x, y, z = getElementPosition(player)
    local vx, vy = getElementVelocity(car)
    local speed = math.sqrt(vx * vx + vy * vy)
    if speed < 0.1 then return end
    local ahead = Wanted.roadblockAhead[1] + math.random() * (Wanted.roadblockAhead[2] - Wanted.roadblockAhead[1])
    local area, id = paths:findNearestNode(x + vx / speed * ahead, y + vy / speed * ahead, z, "vehicle", 30)
    local node = area and paths:getNode(area, id)
    local links = node and paths:getNodeLinks(area, id)
    if not links or #links == 0 then return end
    local _, nearest = nearestPlayer(node.x, node.y, node.z, players)
    if nearest < 90 then return end

    -- Across the road: the road runs from this node to its first neighbour.
    local nx, ny = paths:getNodePosition(links[1].area, links[1].id)
    local dx, dy = nx - node.x, ny - node.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.5 then return end
    dx, dy = dx / len, dy / len
    local roadHeading = math.deg(math.atan2(dy, dx)) - 90
    local unit = population:getServiceUnit(node.x, node.y, node.z, "police")
    local rb = { player = player, elements = {}, cops = {}, x = node.x, y = node.y, z = node.z, at = now }
    for _, side in ipairs({ -3.2, 3.2 }) do
        local cx, cy = node.x + dy * side, node.y - dx * side
        local vehicle = createVehicle(unit.car, cx, cy, node.z + 1, 0, 0, roadHeading + 90)
        if vehicle then
            setVehicleSirensOn(vehicle, true)
            rb.elements[#rb.elements + 1] = vehicle
            -- A cop behind each car, weapon out, facing the player's approach.
            local px, py = cx - dx * 3, cy - dy * 3
            local cop = createPed(unit.ped, px, py, node.z + 1, roadHeading + 180)
            if cop then
                giveWeapon(cop, level >= 3 and 25 or 22, 500, true)
                setElementData(cop, "vana:service", "police")
                setElementData(cop, "vana:traffic", "cop")
                setElementSyncer(cop, player, true, true)
                rb.elements[#rb.elements + 1] = cop
                rb.cops[#rb.cops + 1] = cop
            end
        end
    end
    roadblocks[#roadblocks + 1] = rb
end

local function updateRoadblocks(players, now)
    for i = #roadblocks, 1, -1 do
        local rb = roadblocks[i]
        local level = isElement(rb.player) and getPlayerWantedLevel(rb.player) or 0
        local _, nearest = nearestPlayer(rb.x, rb.y, rb.z, players)
        if (level == 0 or now - rb.at > 90000) and nearest > 150 or nearest > CONFIG.despawn then
            clearRoadblock(i)
        elseif level > 0 and isElement(rb.player) and distanceTo(rb.player, rb.x, rb.y, rb.z) < 60 then
            for _, cop in ipairs(rb.cops) do
                if isElement(cop) and not isPedDead(cop) and (not rb.lastOrder or now - rb.lastOrder > 4000) then
                    triggerClientEvent(rb.player, "vana-services:kill", resourceRoot, cop, rb.player)
                end
            end
            if not rb.lastOrder or now - rb.lastOrder > 4000 then rb.lastOrder = now end
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Medics and firefighters: drive to a body (or a wreck), work on it, then leave.

local function updateCallout(r, players, now)
    local site = r.body or r.site
    local siteGone = r.body and not isElement(r.body)
    if r.state ~= "leaving" and r.state ~= "regrouping" and siteGone then
        if allInVehicle(r) then return leave(r, players) end
        return regroup(r)
    end
    local sx, sy, sz
    if not r.body then
        sx, sy, sz = site.x, site.y, site.z
    elseif isElement(r.body) then
        sx, sy, sz = getElementPosition(r.body)
    else
        sx, sy, sz = getElementPosition(r.vehicle) -- body gone (cleaned up) while heading back
    end

    if r.state == "driving" then
        if distanceTo(r.vehicle, sx, sy, sz) < CONFIG.arriveDistance or now - r.since > 90000 then
            r.state, r.since = "exiting", now
            send(r, "vana-services:exit", r.vehicle, crewAlive(r))
        elseif not r.lastOrder or now - r.lastOrder > 5000 then
            r.lastOrder = now
            driveTo(r, sx, sy, sz)
        end
    elseif r.state == "exiting" then
        if allOnFoot(r) or now - r.since > 6000 then
            r.state, r.since = "walking", now
            local reach = r.kind == "fire" and 5 or 0.8
            for i, ped in ipairs(crewAlive(r)) do
                send(r, "vana-services:walk", ped, sx + (i == 1 and reach or -reach), sy, sz, true)
            end
        end
    elseif r.state == "walking" then
        local reach = r.kind == "fire" and 7 or 2.5
        local arrived = true
        for _, ped in ipairs(crewAlive(r)) do
            if distanceTo(ped, sx, sy, sz) > reach then arrived = false end
        end
        if arrived or now - r.since > 25000 then
            r.state, r.since = "working", now
            for _, ped in ipairs(crewAlive(r)) do
                if r.kind == "fire" then
                    send(r, "vana-services:spray", ped, sx, sy, sz, Firefighters.sprayMs)
                else
                    setPedAnimation(ped, "MEDIC", "CPR", -1, true, false, false, false)
                end
            end
        end
    elseif r.state == "working" then
        if now - r.since > (r.kind == "fire" and Firefighters.sprayMs or Medics.cprMs) then
            if r.kind == "medics" then
                for _, ped in ipairs(crewAlive(r)) do setPedAnimation(ped) end
                if math.random() < Medics.reviveChance and isElement(r.body) then
                    -- Back on their feet: the same person, walking on as a pedestrian.
                    local model, _, _, rz = getElementModel(r.body), getElementRotation(r.body)
                    destroyElement(r.body)
                    local ped = createPed(model, sx, sy, sz + 0.5, rz or 0)
                    if ped and running("vana-peds") then
                        pcall(function() exports["vana-peds"]:adoptPed(ped, "civilian") end)
                    end
                end
            end
            if r.onDone then r.onDone(r) end
            regroup(r)
        end
    elseif r.state == "regrouping" then
        if allInVehicle(r) then
            leave(r, players)
        elseif now - r.since > 25000 then
            release(r)
        end
    end
end

-- One medic or fire call per area at a time. force: always answered (world events), still one per area.
local function callout(kind, rules, x, y, z, fields, force)
    if not force and math.random() >= rules.callChance then return end
    local players = eligiblePlayers()
    local owner = nearestPlayer(x, y, z, players, rules.callRadius)
    if not owner then return end
    local now = getTickCount()
    for i = #recentCalls, 1, -1 do
        local call = recentCalls[i]
        if now - call.at > rules.cooldownMs then
            table.remove(recentCalls, i)
        elseif call.kind == kind and getDistanceBetweenPoints3D(call.x, call.y, call.z, x, y, z) < 150 then
            return
        end
    end
    local r = spawnResponder(kind, x, y, z, players, owner)
    if r then
        for k, v in pairs(fields) do r[k] = v end
        recentCalls[#recentCalls + 1] = { kind = kind, x = x, y = y, z = z, at = now }
    end
    return r
end

addEventHandler("onPedWasted", root, function(_, killer, weapon)
    local ped = source
    -- Activity targets (vigilante criminals and the like) are fair game.
    if getElementData(ped, "vana:fairGame") then return end
    local x, y, z = getElementPosition(ped)

    local player = isElement(killer) and (getElementType(killer) == "vehicle" and getVehicleController(killer) or killer)
    if player and isElement(player) and getElementType(player) == "player" then
        local byCar = getElementType(killer) == "vehicle" or weapon == 49 or weapon == 50
        if isCop(ped) or getElementData(ped, "vana:service") == "police" then
            reportCrime(player, byCar and "kill_cop_with_car" or "kill_cop", x, y, z)
        elseif byCar then
            reportCrime(player, "kill_ped_with_car", x, y, z)
        end
    end

    if getElementData(ped, "vana:service") then return end
    callout("medics", Medics, x, y, z, { body = ped }, getElementData(ped, "vana:eventVictim"))
end)

addEventHandler("onVehicleExplode", root, function()
    if responders[source] then return end
    local x, y, z = getElementPosition(source)
    for _, occupant in pairs(getVehicleOccupants(source) or {}) do
        if getElementType(occupant) == "player" then return end -- the player's own car: no audience
    end
    callout("fire", Firefighters, x, y, z, { site = { x = x, y = y, z = z } }, getElementData(source, "vana:eventFire"))
end)

---------------------------------------------------------------------------------------------------

setTimer(function()
    local players = eligiblePlayers()
    local now = getTickCount()

    for _, player in ipairs(players) do
        local level = updateWanted(player, now)
        if level > 0 then
            recruitPatrols(player, players)
            dispatchPolice(player, level, players)
            dispatchHeli(player, level, players)
            tryRoadblock(player, level, players, now)
            engageWalkingCops(player, level)
            checkBusted(player, now)
        end
    end
    updateRoadblocks(players, now)

    for _, r in pairs(responders) do
        if not isElement(r.vehicle) or isVehicleBlown(r.vehicle) or #crewAlive(r) == 0 then
            release(r)
        else
            local x, y, z = getElementPosition(r.vehicle)
            local owner, ownerDist = nearestPlayer(x, y, z, players, CONFIG.despawn + (r.kind == "heli" and 100 or 0))
            if not owner then
                destroyResponder(r)
            else
                if not isElement(r.owner) or select(2, nearestPlayer(x, y, z, { r.owner })) > CONFIG.despawn then setOwner(r, owner) end
                if r.state == "leaving" then
                    if ownerDist > 150 or now - r.since > 60000 then destroyResponder(r) end
                elseif r.update then
                    r.update(r, players, now) -- world events (events.lua) run their own units
                elseif r.kind == "heli" then
                    updateHeli(r, players, now)
                elseif POLICE_UNITS[r.kind] then
                    updatePolice(r, players, now)
                else
                    updateCallout(r, players, now)
                end
            end
        end
    end
end, CONFIG.tick, 0)

addEventHandler("onResourceStop", resourceRoot, function()
    for _, r in pairs(responders) do destroyResponder(r) end
    for i = #roadblocks, 1, -1 do clearRoadblock(i) end
    for _, player in ipairs(getElementsByType("player")) do setPlayerWantedLevel(player, 0) end
end)

-- Admin: set a player's wanted level (restricted: command.wanted in the ACL).
addCommandHandler("wanted", function(source, _, level, name)
    local target = name and getPlayerFromName(name) or (getElementType(source) == "player" and source)
    level = tonumber(level)
    local reply = function(msg)
        if getElementType(source) == "console" then outputServerLog("[wanted] " .. msg) else outputChatBox(msg, source, 200, 200, 255) end
    end
    if not target or not level or level < 0 or level > 6 then return reply("Usage: /wanted <0-6> [player]") end
    wanted[target] = { chaos = level > 0 and Wanted.thresholds[level] or 0, lastDecay = getTickCount() }
    setPlayerWantedLevel(target, level)
    reply(("%s's wanted level set to %d."):format(getPlayerName(target), level))
end, true)

-- Console-only: checks the wanted rules against vanilla thresholds and the unit tables.
addCommandHandler("wantedtest", function(source)
    if getElementType(source) ~= "console" then return end
    local ok = true
    local expect = { [0] = 0, [49] = 0, [50] = 1, [179] = 1, [180] = 2, [550] = 3, [1200] = 4, [2400] = 5, [4600] = 6, [9999] = 6 }
    for chaos, level in pairs(expect) do
        if levelFor(chaos) ~= level then ok = false; outputServerLog(("[wantedtest] FAIL chaos %d -> %d, expected %d"):format(chaos, levelFor(chaos), level)) end
    end
    -- Ten punches on a civilian (5 each) reach one star; a cop crime is one star at once.
    ok = ok and levelFor(10 * Wanted.crimes.damaged_ped) == 1 and Wanted.minStars.damaged_cop == 1
    for level, units in ipairs(Wanted.units) do
        for kind in pairs(units) do
            local unit = population:getServiceUnit(2495, -1687, 13, kind)
            if not (unit and unit.car and unit.ped and Wanted.crews[kind]) then ok = false; outputServerLog("[wantedtest] FAIL unit " .. kind) end
        end
    end
    for _, kind in ipairs({ "heli", "medics", "fire" }) do
        local unit = population:getServiceUnit(2495, -1687, 13, kind)
        if not (unit and unit.car and unit.ped) then ok = false; outputServerLog("[wantedtest] FAIL unit " .. kind) end
    end
    outputServerLog("[wantedtest] " .. (ok and "PASS" or "FAIL"))
end)

-- For events.lua (world events): the responder machinery.
Services = {
    responders = responders, eligiblePlayers = eligiblePlayers, nearestPlayer = nearestPlayer, running = running,
    spawnResponder = spawnResponder, callout = callout, send = send, driveTo = driveTo, leave = leave,
    release = release, crewAlive = crewAlive, allOnFoot = allOnFoot, distanceTo = distanceTo, bestGunSlot = bestGunSlot,
}
