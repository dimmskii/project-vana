-- Random world events near players (config/events.lua): muggings, car thefts, gang shootouts, car
-- and street fires, someone collapsing, and police chasing a car. Each is staged with the ordinary
-- systems: vana-peds pedestrians and encounters, vana-traffic units, and this resource's responders.
local E = WorldEvents
local paths = exports["vana-paths"]
local rules = exports["vana-population"]:getPersonalityRules()

local active = {}    -- list of { kind, x, y, z, started, update = fn(ev, now) -> finished }
local lastKind = {}  -- player -> { [kind] = tick }

local function call(resource, fn, ...)
    if not Services.running(resource) then return end
    local result = { pcall(function(...) return exports[resource][fn](exports[resource], ...) end, ...) }
    if result[1] then return unpack(result, 2) end
end

local function randomFrom(list) return list[math.random(#list)] end

-- A path node of `kind` ("ped" or "vehicle") the right distance from the player and not too close to anyone.
local function spotNear(player, kind)
    local px, py, pz = getElementPosition(player)
    local players = Services.eligiblePlayers()
    for _ = 1, 10 do
        local angle, r = math.random() * 2 * math.pi, E.distance[1] + math.random() * (E.distance[2] - E.distance[1])
        local area, id = paths:findNearestNode(px + math.cos(angle) * r, py + math.sin(angle) * r, pz, kind, 30)
        local node = area and paths:getNode(area, id)
        if node and (kind ~= "vehicle" or node.floodFill == 1 and not node.boats) then
            local _, nearest = Services.nearestPlayer(node.x, node.y, node.z, players)
            if nearest >= E.minToAnyone then return node.x, node.y, node.z end
        end
    end
end

-- A ped for the scene, standing at (x, y, z) with its weapon (drawn) and kind.
local function scenePed(x, y, z, kind, gang, weapon)
    local spec = call("vana-population", "pickScenePed", x, y, z, kind, gang)
    if not spec then return end
    local ped = createPed(spec.model, x, y, z + 1, math.random(0, 359))
    if not ped then return end
    weapon = weapon or spec.weapon
    if weapon and weapon > 0 then giveWeapon(ped, weapon, 500, true) end
    return ped, spec
end

local function walkAway(ped, spec, encounter)
    return call("vana-peds", "adoptPed", ped, spec.kind, spec.gang, spec.personality, encounter)
end

-- Cops walking nearby step in.
local function copsStepIn(x, y, z, radius, criminal)
    for _, cop in ipairs(call("vana-peds", "findPeds", x, y, z, radius, "cop") or {}) do
        call("vana-peds", "engagePed", cop, "fight", criminal)
    end
end

-- An unoccupied car parked near (x, y, z) nobody owns or remembers (vana-vehicles).
local function parkedCarNear(x, y, z, radius)
    local list = {}
    for _, car in ipairs(getElementsWithinRange(x, y, z, radius, "vehicle")) do
        if getElementData(car, "vana:parked") and not getElementData(car, "vana:kept") and not isVehicleBlown(car)
            and not next(getVehicleOccupants(car) or {}) and getVehicleType(car) == "Automobile" then
            list[#list + 1] = car
        end
    end
    return #list > 0 and randomFrom(list)
end

---------------------------------------------------------------------------------------------------

local Kinds = {}

-- A street criminal goes for a pedestrian; the victim answers as anyone attacked would.
function Kinds.mugging(player)
    local x, y, z = spotNear(player, "ped")
    if not x then return end
    local victims = call("vana-peds", "findPeds", x, y, z, 40, "civilian") or {}
    if #victims == 0 then return end
    local victim = randomFrom(victims)
    local vx, vy, vz = getElementPosition(victim)
    local mugger, spec = scenePed(vx + 3, vy + 3, vz, "criminal", nil, randomFrom(E.mugging.weapons))
    if not mugger then return end
    spec.personality = { fear = 10, temper = 95, lawfulness = 0 }
    if not walkAway(mugger, spec, { mode = "fight", target = victim }) then destroyElement(mugger) return end
    copsStepIn(vx, vy, vz, E.mugging.copRadius, mugger)
    return { x = vx, y = vy, z = vz }
end

-- A thief walks up to a parked car, breaks in and drives off in it as traffic.
function Kinds.carTheft(player)
    local x, y, z = spotNear(player, "ped")
    if not x then return end
    local car = parkedCarNear(x, y, z, E.carTheft.searchRadius)
    if not car then return end
    local cx, cy, cz = getElementPosition(car)
    local thief, spec = scenePed(cx + 5, cy + 3, cz, "criminal")
    if not thief then return end
    spec.personality = { fear = 30, temper = 60, lawfulness = 0 }
    if not walkAway(thief, spec, { mode = "jack", target = car, vehicle = car }) then destroyElement(thief) return end
    copsStepIn(cx, cy, cz, E.carTheft.copRadius, thief)
    return { x = cx, y = cy, z = cz }
end

-- Two rival crews meet and open fire.
function Kinds.shootout(player)
    local x, y, z = spotNear(player, "ped")
    if not x then return end
    local gangs = {}
    for gang in pairs(rules.rivals) do gangs[#gangs + 1] = gang end
    local a = randomFrom(gangs)
    local enemies = {}
    for gang in pairs(rules.rivals[a]) do enemies[#enemies + 1] = gang end
    local b = randomFrom(enemies)
    local angle = math.random() * 2 * math.pi
    local sides = { { gang = a, x = x, y = y, peds = {} },
                    { gang = b, x = x + math.cos(angle) * E.shootout.apart, y = y + math.sin(angle) * E.shootout.apart, peds = {} } }
    for _, side in ipairs(sides) do
        for i = 1, math.random(E.shootout.perSide[1], E.shootout.perSide[2]) do
            local ped, spec = scenePed(side.x + i * 1.2, side.y, z, "gang", side.gang)
            if ped then side.peds[#side.peds + 1] = { ped = ped, spec = spec } end
        end
    end
    if #sides[1].peds == 0 or #sides[2].peds == 0 then
        for _, side in ipairs(sides) do for _, p in ipairs(side.peds) do destroyElement(p.ped) end end
        return
    end
    for i, side in ipairs(sides) do
        local other = sides[3 - i]
        for _, p in ipairs(side.peds) do
            if not walkAway(p.ped, p.spec, { mode = "fight", target = randomFrom(other.peds).ped }) then destroyElement(p.ped) end
        end
    end
    return { x = x, y = y, z = z }
end

-- A parked car's engine catches fire; it burns out and explodes, and a fire truck always comes.
function Kinds.carFire(player)
    local x, y, z = spotNear(player, "vehicle")
    if not x then return end
    local car = parkedCarNear(x, y, z, 60)
    if not car then return end
    setElementData(car, "vana:eventFire", true, false)
    setElementHealth(car, 245) -- below 250 the engine burns
    local cx, cy, cz = getElementPosition(car)
    return { x = cx, y = cy, z = cz }
end

-- Something burning in the street, kept alight until the firefighters have hosed it down.
function Kinds.streetFire(player)
    local x, y, z = spotNear(player, "ped")
    if not x then return end
    local ev = { x = x, y = y, z = z, done = false, lit = 0 }
    local size = E.streetFire.size
    local r = Services.callout("fire", Firefighters, x, y, z, { site = { x = x, y = y, z = z }, onDone = function() ev.done = true end }, true)
    if not r then return end
    ev.update = function(e, now)
        if e.done or now - e.started > E.lifetimeMs then
            triggerClientEvent(root, "vana-services:fire", resourceRoot, x, y, z, size, false)
            return true
        end
        if now - e.lit > E.streetFire.rekindleMs then
            e.lit = now
            triggerClientEvent(root, "vana-services:fire", resourceRoot, x, y, z, size, true)
        end
    end
    return ev
end

-- Someone on the street collapses; an ambulance comes, and the medics may bring them round.
function Kinds.collapse(player)
    local x, y, z = spotNear(player, "ped")
    if not x then return end
    local list = call("vana-peds", "findPeds", x, y, z, E.collapse.searchRadius, "civilian") or {}
    if #list == 0 then return end
    local ped = randomFrom(list)
    setElementData(ped, "vana:eventVictim", true, false)
    local px, py, pz = getElementPosition(ped)
    killPed(ped)
    return { x = px, y = py, z = pz }
end

-- A police car chases a criminal's car through traffic; when it stops, everyone gets out and fights.
local function chaseUpdate(r, players, now)
    local c = r.chase
    local criminals = {}
    for _, ped in ipairs(c.peds) do
        if isElement(ped) and not isPedDead(ped) then criminals[#criminals + 1] = ped end
    end
    if #criminals == 0 or now - c.started > E.chase.timeoutMs then return Services.leave(r, players) end
    local car = c.vehicle
    local carDriven = isElement(car) and not isVehicleBlown(car) and getVehicleController(car) == criminals[1]
    local tx, ty, tz = getElementPosition(carDriven and car or criminals[1])
    if Services.distanceTo(r.vehicle, tx, ty, tz) > E.chase.giveUp and r.state == "driving" then return Services.leave(r, players) end

    if r.state == "driving" then
        if carDriven then call("vana-traffic", "panicUnit", car, 10) end
        local vx, vy, vz = 0, 0, 0
        if carDriven then vx, vy, vz = getElementVelocity(car) end
        local stopped = (vx * vx + vy * vy + vz * vz) * 2500 < E.chase.stopSpeed ^ 2
        c.stoppedSince = stopped and (c.stoppedSince or now) or nil
        local close = Services.distanceTo(r.vehicle, tx, ty, tz) < 35
        if close and (not carDriven or (c.stoppedSince and now - c.stoppedSince >= E.chase.stopMs)) then
            r.state, r.since = "engaging", now
            Services.send(r, "vana-services:exit", r.vehicle, Services.crewAlive(r))
        elseif not r.lastOrder or now - r.lastOrder > 2000 then
            r.lastOrder = now
            Services.driveTo(r, tx, ty, tz)
        end
    elseif r.state == "engaging" then
        c.orders = c.orders or {}
        for i, cop in ipairs(Services.crewAlive(r)) do
            local criminal = criminals[(i - 1) % #criminals + 1]
            if not getPedOccupiedVehicle(cop) and c.orders[cop] ~= criminal then
                c.orders[cop] = criminal
                setPedWeaponSlot(cop, Services.bestGunSlot(cop))
                Services.send(r, "vana-services:kill", cop, criminal)
            end
        end
        -- Criminals out of the car (pedestrians by now) fight back.
        for _, criminal in ipairs(criminals) do
            if not getPedOccupiedVehicle(criminal) and not c.orders[criminal] then
                local cop = Services.crewAlive(r)[1]
                if cop and call("vana-peds", "engagePed", criminal, "fight", cop) then c.orders[criminal] = cop end
            end
        end
    end
end

function Kinds.chase(player)
    local x, y, z = spotNear(player, "vehicle")
    if not x then return end
    local car = createVehicle(randomFrom(E.chase.cars), x, y, z + 1, 0, 0, math.random(0, 359))
    if not car then return end
    call("vana-vehicles", "tuneRandomly", car)
    local driver = scenePed(x, y, z, "criminal", nil, randomFrom(E.chase.weapons))
    if not driver or not warpPedIntoVehicle(driver, car, 0) then
        if driver then destroyElement(driver) end
        destroyElement(car)
        return
    end
    setElementData(driver, "vana:traffic", "civilian")
    if not call("vana-traffic", "adoptVehicle", car, driver, "civilian", nil, { fear = 20, temper = 85, lawfulness = 0 }) then
        destroyElement(driver)
        destroyElement(car)
        return
    end
    local r = Services.spawnResponder("police", x, y, z, Services.eligiblePlayers(), player, 2)
    if not r then return { x = x, y = y, z = z } end -- no road for the police: just a fast car
    r.chase, r.update = { vehicle = car, peds = { driver }, started = getTickCount() }, chaseUpdate
    return { x = x, y = y, z = z }
end

---------------------------------------------------------------------------------------------------

local function weightedKind()
    local total = 0
    for _, w in pairs(E.weights) do total = total + w end
    local r = math.random() * total
    for kind, w in pairs(E.weights) do
        r = r - w
        if r <= 0 then return kind end
    end
end

-- Starts an event of `kind` (or a random one) near the player; returns the kind, or nil.
function startWorldEvent(player, kind)
    kind = kind or weightedKind()
    if not Kinds[kind] or #active >= E.maxActive then return end
    local ev = Kinds[kind](player)
    if not ev then return end
    ev.kind, ev.started = kind, getTickCount()
    active[#active + 1] = ev
    lastKind[player] = lastKind[player] or {}
    lastKind[player][kind] = ev.started
    return kind
end

setTimer(function()
    local now = getTickCount()
    for _, player in ipairs(Services.eligiblePlayers()) do
        if math.random() < E.chance then
            local kind = weightedKind()
            local last = lastKind[player] and lastKind[player][kind]
            if not last or now - last > E.kindCooldownMs then startWorldEvent(player, kind) end
        end
    end
end, E.checkEveryMs, 0)

setTimer(function()
    local now = getTickCount()
    for i = #active, 1, -1 do
        local ev = active[i]
        local finished = ev.update and ev.update(ev, now) or (not ev.update and now - ev.started > 60000)
        if finished or now - ev.started > E.lifetimeMs then table.remove(active, i) end
    end
end, 1000, 0)

addEventHandler("onPlayerQuit", root, function() lastKind[source] = nil end)

-- Admin: start a world event near you. Restricted: command.event in the ACL.
addCommandHandler("event", function(player, _, kind)
    if getElementType(player) ~= "player" then return end
    if kind and not Kinds[kind] then
        local names = {}
        for name in pairs(Kinds) do names[#names + 1] = name end
        table.sort(names)
        return outputChatBox("Usage: /event [" .. table.concat(names, "|") .. "]", player, 200, 200, 255)
    end
    local started = startWorldEvent(player, kind)
    outputChatBox(started and ("World event: " .. started .. ".") or "No spot for that event here right now; try again.", player, 200, 200, 255)
end, true)

-- Console-only: every event kind has a weight and a starter, and the config is sane.
addCommandHandler("eventtest", function(source)
    if getElementType(source) ~= "console" then return end
    local ok = true
    for kind in pairs(E.weights) do
        if not Kinds[kind] then ok = false outputServerLog("[eventtest] no starter for " .. kind) end
    end
    for kind in pairs(Kinds) do
        if not E.weights[kind] then ok = false outputServerLog("[eventtest] no weight for " .. kind) end
    end
    local spec = call("vana-population", "pickScenePed", 2495, -1687, 13, "gang", "ballas")
    local crook = call("vana-population", "pickScenePed", 2495, -1687, 13, "criminal")
    ok = ok and spec and spec.gang == "ballas" and crook and crook.model and true
    outputServerLog(("[eventtest] %d kinds; scene peds: a Ballas member (model %s), a street criminal (model %s)")
        :format(#(function() local t = {} for k in pairs(Kinds) do t[#t + 1] = k end return t end)(),
            tostring(spec and spec.model), tostring(crook and crook.model)))
    outputServerLog("[eventtest] " .. (ok and "PASS" or "FAIL"))
end)
