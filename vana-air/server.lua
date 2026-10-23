-- Aircraft: airliners on the timetable (schedule.lua), the Verdant Meadows circuit, news helicopters
-- and helicopters and airliners passing now and then. The server keeps every one where its legs
-- (legs.lua) put it at the time; elements exist only near players (dimension 0, outside interiors),
-- flown by the nearest player's client along the same legs from the same clock, so a handover just
-- carries on. A pilot shot or pulled out ends the flying: what's in the air comes down. No blips.
local population = exports["vana-population"]
local rules = population:getPersonalityRules()
local C = AirConfig

local counts = {} -- fleet counts, from the meta.xml settings (/vanaset air at400 2)
for _, f in ipairs(C.fleet) do counts[f.setting] = f.count end

local crafts = {}   -- id -> craft: { id, kind, model, crew = { model, ... }, heli, current = fn(now) -> leg }
local live = {}     -- craft -> { vehicle, crew = { ped, ... }, owner, sentLeg, ... }
local released = {} -- peds no longer ours: ped -> { kind, personality, encounter }
local wrecks = {}   -- vehicles left to the world (taken, crashed): vehicle -> { since, taken }
local planes = {}   -- the airliners (AirSchedule planes) by craft id
local nextId = 0
local enabled = true
local t0 = getTickCount()

local function sync(text) if Debug.on("sync") then Debug.log("sync", text) end end

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

local function newCraft(kind, model, crew, heli, current)
    nextId = nextId + 1
    local craft = { id = nextId, kind = kind, model = model, crew = crew, heli = heli, current = current }
    crafts[nextId] = craft
    return craft
end

-- Where a craft is now: its leg { desc, frames, start, loop } and the sample.
local function where(craft, now)
    local leg = craft.current(now)
    if not leg then return nil end
    local t = now - leg.start
    if leg.loop then t = t % leg.loop end
    return leg, Legs.sample(leg.frames, t)
end

---------------------------------------------------------------------------------------------------
-- Elements

local function aboard(l)
    for _, occupant in pairs(getVehicleOccupants(l.vehicle) or {}) do
        if getElementType(occupant) == "player" then return occupant end
    end
    return false
end

-- The leg to the owner: what to fly and how far into it they are.
local function order(craft, l, now)
    local leg = craft.current(now)
    if not leg or not isElement(l.owner) then return end
    l.sentLeg = leg
    triggerClientEvent(l.owner, "vana-air:fly", resourceRoot, l.vehicle, l.crew[1], leg.desc, now - leg.start, leg.loop, craft.heli)
end

local function setOwner(craft, l, owner, now)
    if l.owner == owner then return end
    if isElement(l.owner) then triggerClientEvent(l.owner, "vana-air:stop", resourceRoot, l.vehicle) end
    l.owner = owner
    if not owner then return end
    setElementSyncer(l.vehicle, owner, true, true)
    for _, ped in ipairs(l.crew) do if isElement(ped) then setElementSyncer(ped, owner, true, true) end end
    order(craft, l, now)
    sync(("%s %d (%d): flown by %s"):format(craft.kind, craft.id, craft.model, getPlayerName(owner)))
end

local function materialize(craft, owner, now)
    local _, x, y, z, fx, fy = where(craft, now)
    if not x then return end
    local vehicle = createVehicle(craft.model, x, y, z, 0, 0, math.deg(math.atan2(-fx, fy)))
    if not vehicle then return end
    setElementData(vehicle, "vana:managed", true, false) -- ours: never kept by vana-vehicles
    setElementData(vehicle, "vana:air", craft.kind)
    -- Flown by script, it can't avoid anything: proof against damage while it's ours (its pilot isn't).
    setVehicleDamageProof(vehicle, true)
    setVehicleEngineState(vehicle, true)
    local l = { vehicle = vehicle, crew = {} }
    for seat, model in ipairs(craft.crew) do
        local ped = createPed(model, x, y, z + 2)
        if ped and warpPedIntoVehicle(ped, vehicle, seat - 1) then
            setElementData(ped, "vana:air", craft.kind)
            l.crew[#l.crew + 1] = ped
        elseif ped then
            destroyElement(ped)
        end
    end
    live[craft] = l
    setOwner(craft, l, owner, now)
    sync(("%s %d (%d): made at %.0f, %.0f, %.0f (%s)"):format(craft.kind, craft.id, craft.model, x, y, z, getZoneName(x, y, z)))
end

local function dematerialize(craft)
    local l = live[craft]
    if not l then return end
    live[craft] = nil
    for _, ped in ipairs(l.crew) do if isElement(ped) and not released[ped] then destroyElement(ped) end end
    if isElement(l.vehicle) then destroyElement(l.vehicle) end
    sync(("%s %d (%d): removed"):format(craft.kind, craft.id, craft.model))
end

-- A crew member walks off (pulled out, got out) as one of vana-peds' pedestrians.
local function releasePed(ped, encounter)
    if not isElement(ped) or released[ped] then return end
    setElementSyncer(ped, true)
    removeElementData(ped, "vana:air")
    released[ped] = { kind = "civilian", personality = population:getPersonality(getElementModel(ped)), encounter = encounter }
end

local function reactionTo(ped, attacker)
    local p = population:getPersonality(getElementModel(ped)) or {}
    local fight = (p.temper or 50) >= rules.collision.fightTemper and (p.fear or 50) < rules.collision.fleeFear
    return { mode = fight and "fight" or "flee", target = attacker }
end

-- The craft stops being ours: its vehicle is left to the world (a player took it, or it's coming
-- down), its crew let go; `replace` puts another of its kind back where nobody sees it.
local craftEnd
local function letGo(craft, why, jacker)
    local l = live[craft]
    crafts[craft.id] = nil
    if l then
        live[craft] = nil
        if isElement(l.owner) then triggerClientEvent(l.owner, "vana-air:stop", resourceRoot, l.vehicle) end
        if isElement(l.vehicle) then
            setElementSyncer(l.vehicle, true)
            setVehicleDamageProof(l.vehicle, false)
            wrecks[l.vehicle] = { since = getTickCount(), taken = jacker ~= nil }
        end
        for _, ped in ipairs(l.crew) do
            if isElement(ped) and not isPedDead(ped) then releasePed(ped, jacker and reactionTo(ped, jacker) or nil) end
        end
    end
    sync(("%s %d (%d): %s"):format(craft.kind, craft.id, craft.model, why))
    if craftEnd then craftEnd(craft) end
end

---------------------------------------------------------------------------------------------------
-- The airliners

local function obstacleAt(spotId)
    local s = AirSpots[spotId]
    for vehicle in pairs(wrecks) do
        if isElement(vehicle) then
            local x, y, z = getElementPosition(vehicle)
            if getDistanceBetweenPoints3D(x, y, z, s.x, s.y, s.z) < C.spotRadius then return true end
        end
    end
    return false
end

local function planeCraft(plane)
    local craft = newCraft("plane", plane.model, { C.pilot }, false, function(now)
        local leg = AirSchedule.at(plane, now)
        return leg
    end)
    craft.plane = plane
    planes[craft.id] = plane
    return craft
end

local function buildFleet(now)
    for id, plane in pairs(planes) do
        local craft = crafts[id]
        if craft then dematerialize(craft) crafts[id] = nil end
        planes[id] = nil
    end
    AirSchedule.prepare()
    for _, plane in pairs(AirSchedule.build(counts, now)) do planeCraft(plane) end
end

-- Another airliner of that model, in the air on its way in.
local function replacePlane(model, now)
    local plane = { id = 0, model = model }
    if AirSchedule.launch(plane, now) then planeCraft(plane) end
end

---------------------------------------------------------------------------------------------------
-- The circuit, news helicopters, passers-by

local function circuitCrafts(now)
    for _, c in ipairs(Circuits) do
        local desc = { kind = "spline", points = c.points, closed = true }
        local frames = Legs.build(desc)
        local lap = Legs.duration(frames)
        for i, model in ipairs(c.models or {}) do
            local offset = (i - 1) * lap / #c.models
            local leg = { desc = desc, frames = frames, start = now - offset, loop = lap }
            local craft = newCraft("circuit", model, { C.pilot }, false, function() return leg end)
            craft.circuit = c
        end
    end
end

-- A one-off flight through points (news helicopters, passers-by): its leg from `now`.
local function oneOff(kind, model, crew, heli, points, now)
    local desc = { kind = "spline", points = points, heli = heli, gearMs = 0 }
    local frames = Legs.build(desc)
    local leg = { desc = desc, frames = frames, start = now }
    local craft = newCraft(kind, model, crew, heli, function() return leg end)
    craft.ends = now + Legs.duration(frames)
    return craft
end

-- A news helicopter's session over a spot: in from far away, laps of the circle, away again.
local news = {} -- city -> { craft, nextAt }
local function newsSession(spot, now)
    local cfg = C.news
    local a = math.random() * 2 * math.pi
    local far = 1500
    local points = { { spot.x + math.cos(a) * far, spot.y + math.sin(a) * far, spot.z, cfg.speed * 2 } }
    local laps = math.max(1, math.floor(math.random(cfg.onAir[1], cfg.onAir[2]) / 1000 / (2 * math.pi * spot.radius / cfg.speed)))
    for _ = 1, laps do
        for k = 0, 7 do
            local b = a + k * math.pi / 4
            points[#points + 1] = { spot.x + math.cos(b) * spot.radius, spot.y + math.sin(b) * spot.radius, spot.z, cfg.speed }
        end
    end
    local out = a + math.pi * (0.5 + math.random())
    points[#points + 1] = { spot.x + math.cos(out) * far, spot.y + math.sin(out) * far, spot.z + 40, cfg.speed * 2 }
    return oneOff("news", cfg.model, cfg.crew, true, points, now)
end

local function updateNews(now)
    local hour = getTime()
    local byCity = {}
    for _, s in ipairs(HeliSpots) do
        if s.kind == "news" and s.city then
            byCity[s.city] = byCity[s.city] or {}
            table.insert(byCity[s.city], s)
        end
    end
    for city, spots in pairs(byCity) do
        local n = news[city] or { nextAt = now + math.random(0, C.news.offAir[1]) }
        news[city] = n
        local onAir = n.craft and crafts[n.craft.id]
        if n.craft and not onAir then
            -- Came down (or was taken): back on air later.
            n.craft, n.nextAt = nil, now + math.random(C.news.offAir[1], C.news.offAir[2])
        elseif onAir and now >= n.craft.ends then
            dematerialize(n.craft)
            crafts[n.craft.id] = nil
            n.craft, n.nextAt = nil, now + math.random(C.news.offAir[1], C.news.offAir[2])
        elseif not onAir and now >= n.nextAt and hour >= C.news.hours[1] and hour < C.news.hours[2] then
            n.craft = newsSession(spots[math.random(#spots)], now)
        end
    end
end

local function inZone(x, y, zones)
    for _, z in ipairs(zones) do if (x - z[1]) ^ 2 + (y - z[2]) ^ 2 < z[3] ^ 2 then return true end end
    return false
end

local function noPlanes(x, y)
    if inZone(x, y, C.noPlaneZones.circles) then return true end
    for _, b in ipairs(C.noPlaneZones.boxes) do
        if x > b[1] and x < b[3] and y > b[2] and y < b[4] then return true end
    end
    return false
end

local function weighted(weights)
    local total = 0
    for _, w in pairs(weights) do total = total + w end
    local r = math.random() * total
    for model, w in pairs(weights) do
        r = r - w
        if r <= 0 then return model end
    end
end

-- Passing by a player: from `distance` away, past them 150-400 m off, as far on the other side.
local function pass(player, kind, model, heli, speed, height, distance, now)
    local px, py, pz = getElementPosition(player)
    local a = math.random() * 2 * math.pi
    local side = (math.random() < 0.5 and -1 or 1) * math.random(150, 400)
    local cx, cy = px + math.cos(a + math.pi / 2) * side, py + math.sin(a + math.pi / 2) * side
    local z = math.max(pz, 0) + math.random(height[1], height[2])
    local points = {
        { cx - math.cos(a) * distance, cy - math.sin(a) * distance, z, speed },
        { cx, cy, z, speed },
        { cx + math.cos(a) * distance, cy + math.sin(a) * distance, z, speed },
    }
    local craft = oneOff(kind, model, { C.pilot }, heli, points, now)
    craft.ambient = true
    return craft
end

local lastAmbient, lastOverflight = 0, 0
local function updatePassersBy(players, now)
    local function anyNear(px, py, pz, range)
        for _, c in pairs(crafts) do
            if c.ambient then
                local _, x, y, z = where(c, now)
                if x and getDistanceBetweenPoints3D(px, py, pz, x, y, z) < range then return true end
            end
        end
        return false
    end
    if now - lastAmbient >= C.ambient.every then
        lastAmbient = now
        for _, player in ipairs(players) do
            local px, py, pz = getElementPosition(player)
            if math.random() < C.ambient.chance and not anyNear(px, py, pz, 1500) then
                pass(player, "heli", weighted(C.ambient.models), true, C.ambient.speed, C.ambient.height, C.ambient.distance, now)
            end
        end
    end
    if now - lastOverflight >= C.overflights.every then
        lastOverflight = now
        for _, player in ipairs(players) do
            local px, py, pz = getElementPosition(player)
            if math.random() < C.overflights.chance and not noPlanes(px, py) and not anyNear(px, py, pz, 2500) then
                local list = inZone(px, py, C.noBigPlaneZones) and C.overflights.small or C.overflights.big
                pass(player, "overflight", list[math.random(#list)], false, C.overflights.speed, C.overflights.height, C.overflights.distance, now)
            end
        end
    end
    -- One-off flights that are over.
    for id, craft in pairs(crafts) do
        if craft.ends and now >= craft.ends and craft.kind ~= "news" then
            dematerialize(craft)
            crafts[id] = nil
        end
    end
end

-- What replaces a craft that was taken or came down.
craftEnd = function(craft)
    if craft.kind == "plane" then
        local plane = craft.plane
        AirSchedule.release(plane)
        plane.state = "out"
        planes[craft.id] = nil
        replacePlane(craft.model, getTickCount() - t0)
    elseif craft.kind == "circuit" then
        -- Back in the circuit once nobody would see it appear.
        craft.backAt = getTickCount() + 60000
        crafts[craft.id] = craft
        craft.resting = true
    end
end

---------------------------------------------------------------------------------------------------
-- The tick

local function clock() return getTickCount() - t0 end

local function updateLive(craft, l, players, now)
    if not isElement(l.vehicle) or isVehicleBlown(l.vehicle) then
        live[craft] = nil
        return letGo(craft, "wrecked")
    end
    local pilot = l.crew[1]
    local controller = getVehicleController(l.vehicle)
    if controller and getElementType(controller) == "player" then
        return letGo(craft, "taken by " .. getPlayerName(controller), controller)
    end
    if not isElement(pilot) or isPedDead(pilot) or getPedOccupiedVehicle(pilot) ~= l.vehicle then
        return letGo(craft, "lost its pilot")
    end
    local x, y, z = getElementPosition(l.vehicle)
    local owner, dist = nearestPlayer(x, y, z, players, C.despawn)
    if not owner and not aboard(l) then return dematerialize(craft) end
    local ownerGone = not isElement(l.owner) or select(2, nearestPlayer(x, y, z, { l.owner })) > C.ownerRadius
    if owner and ownerGone and dist <= C.ownerRadius then setOwner(craft, l, owner, now) end
    -- A new leg (the timetable moved on): the owner gets it.
    local leg = craft.current(now)
    if leg and leg ~= l.sentLeg then order(craft, l, now) end
end

local function tick()
    local players = eligiblePlayers()
    local now = clock()
    for _, plane in pairs(planes) do AirSchedule.step(plane, now, math.random, obstacleAt, planes) end
    AirSchedule.prune(now)
    updateNews(now)
    updatePassersBy(players, now)
    for _, craft in pairs(crafts) do
        local l = live[craft]
        if l then
            updateLive(craft, l, players, now)
        elseif craft.resting then
            if getTickCount() >= craft.backAt then
                local _, x, y, z = where(craft, now)
                if x and not nearestPlayer(x, y, z, players, C.spawnRange) then craft.resting = nil end
            end
        elseif enabled then
            local _, x, y, z = where(craft, now)
            local owner = x and nearestPlayer(x, y, z, players, C.spawnRange)
            if owner then materialize(craft, owner, now) end
        end
    end
    -- Crew let go: on foot, to vana-peds; still seated after a while, taken out.
    for ped, info in pairs(released) do
        if not isElement(ped) then
            released[ped] = nil
        elseif not isPedDead(ped) and not getPedOccupiedVehicle(ped) then
            local res = getResourceFromName("vana-peds")
            if res and getResourceState(res) == "running" then
                local ok, adopted = pcall(function() return exports["vana-peds"]:adoptPed(ped, info.kind, nil, info.personality, info.encounter) end)
                if ok and adopted then released[ped] = nil end
            end
        end
        if isElement(ped) and released[ped] then
            local x, y, z = getElementPosition(ped)
            if not nearestPlayer(x, y, z, players, C.despawn) then
                released[ped] = nil
                destroyElement(ped)
            end
        end
    end
    -- Wrecks and taken aircraft: gone once nobody is aboard or near (taken ones after abandonedMs).
    for vehicle, w in pairs(wrecks) do
        if not isElement(vehicle) then
            wrecks[vehicle] = nil
        else
            local occupied = next(getVehicleOccupants(vehicle) or {})
            local x, y, z = getElementPosition(vehicle)
            local old = not w.taken or getTickCount() - w.since > C.abandonedMs
            if not occupied and old and not nearestPlayer(x, y, z, players, C.despawn) then
                wrecks[vehicle] = nil
                destroyElement(vehicle)
            end
        end
    end
end

local function rebuild()
    for craft in pairs(live) do dematerialize(craft) end
    crafts, planes, news = {}, {}, {}
    local now = clock()
    buildFleet(now)
    circuitCrafts(now)
end

Settings.bind(counts, { at400 = "number", andromada = "number", shamal = "number", nevada = "number" }, rebuild)
rebuild()
setTimer(tick, C.tick, 0)

-- The owner needs a flight recording's frames (once per flight).
addEvent("vana-air:needFlight", true)
addEventHandler("vana-air:needFlight", resourceRoot, function(id)
    local flight = Flights[id]
    if not flight then return end
    local packed = {}
    for _, f in ipairs(flight.frames) do
        packed[#packed + 1] = { f.t, f.x, f.y, f.z, f.fx, f.fy, f.fz, f.rx, f.ry, f.rz, f.vx, f.vy, f.vz, f.gear and 1 or 0 }
    end
    triggerLatentClientEvent(client, "vana-air:flight", 200000, false, resourceRoot, id, packed)
end)

addEventHandler("onPlayerQuit", root, function()
    for _, l in pairs(live) do if l.owner == source then l.owner = nil end end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for craft in pairs(live) do dematerialize(craft) end
end)

-- Admin control. Restricted: needs command.air in the ACL (vana-player grants it to Admin).
addCommandHandler("air", function(source, _, action, value)
    local reply = function(msg)
        if getElementType(source) == "console" then outputServerLog("[air] " .. msg) else outputChatBox(msg, source, 200, 200, 255) end
    end
    local fleetSetting = {}
    for _, f in ipairs(C.fleet) do fleetSetting[f.setting] = true end
    if action == "on" then
        enabled = true
        reply("Aircraft appear near players again.")
    elseif action == "off" then
        enabled = false
        for craft in pairs(live) do dematerialize(craft) end
        reply("Aircraft off: they keep to their timetable, out of the world.")
    elseif action == "reset" then
        rebuild()
        reply("Aircraft reset.")
    elseif action == "debug" then
        local core = getResourceFromName("vana-core")
        if not core or getResourceState(core) ~= "running" then return reply("Aircraft debug needs vana-core (its /vanadebug switches).") end
        exports["vana-core"]:setDebug("vana-air", value == "on" and "sync" or nil)
        reply("Aircraft debug " .. (value == "on" and "on: aircraft lines in the server log." or "off.") .. " (as /vanadebug air sync)")
    elseif fleetSetting[action] and tonumber(value) then
        Settings.set(action, math.max(0, math.min(6, math.floor(tonumber(value)))))
        reply(("%d %s (aircraft reset)."):format(counts[action], action))
    elseif action == "pass" and getElementType(source) == "player" then
        pass(source, "heli", weighted(C.ambient.models), true, C.ambient.speed, C.ambient.height, C.ambient.distance, clock())
        reply("A helicopter is on its way past you.")
    else
        local now = clock()
        local lines = {}
        for _, craft in pairs(crafts) do
            local leg, x, y, z = where(craft, now)
            if x then
                local what = craft.plane and (craft.plane.state .. (craft.plane.holding and " (holding)" or "")) or (leg.desc.kind == "spline" and "flying" or leg.desc.kind)
                lines[#lines + 1] = ("%d %s %s: %s, %.0f m up, over %s%s"):format(craft.id, craft.kind, getVehicleNameFromModel(craft.model), what,
                    z, getZoneName(x, y, z), live[craft] and " (in the world)" or "")
            end
        end
        table.sort(lines)
        reply(("Aircraft are %s. Usage: /air on|off|reset|at400|andromada|shamal|nevada <count>|pass|debug on|off"):format(enabled and "on" or "off"))
        for _, line in ipairs(lines) do reply(line) end
    end
end, true)
