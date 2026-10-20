-- Server-owned ambient pedestrians. The server plans walking routes and road crossings
-- (planner.lua); the owning client runs GTA's native follow-node-route task toward the targets sent
-- here, and GTA's own event responses (avoid, flee, fight) via the ambient-wander event profile.
local paths = exports["vana-paths"]
local population = exports["vana-population"]
local rules = population:getPersonalityRules()
local companions = population:getCompanionRules()

local CONFIG = {
    density = 1,        -- multiplies vanilla popcycle targets
    maxPerPlayer = 40,  -- hard cap on peds around one player
    spawnMin = 40, spawnMax = 110,
    despawn = 200,
    ownerRadius = 150,
    pedSpacing = 6,
    tick = 500,
    clearRadius = 18,   -- an unlit crossing is clear when no moving vehicle is this close to it
    stuckMs = 8000,     -- not moving this long (and not holding at a kerb): the target is sent again
    resends = 2,        -- after this many sends in vain, a fresh route from where the ped stands
    maxHoldMs = 60000,  -- the longest a ped waits at a kerb before walking somewhere else
    followLost = 25,    -- a follower this far (m) from its slot leaves the group and walks on alone
}
Settings.bind(CONFIG, { density = "number", maxPerPlayer = "number" }) -- meta.xml settings (/vanaset)

local walkers = {}    -- ped -> walker
local released = {}
local Holdup = {}     -- aiming a gun at someone (filled in below)
local challengePlayers -- rival gangs picking fights (below)
local enabled = true

-- vana-peds:orders (docs/debug.md): vana-core's debug switch on this resource's root element.
local function debugOn(topic)
    local v = getElementData(resourceRoot, "vana:debug")
    return v == "all" or (type(v) == "string" and ("," .. v .. ","):find("," .. topic .. ",", 1, true) ~= nil)
end

local function debugLog(text) if debugOn("orders") then outputServerLog("[debug vana-peds:orders] " .. text) end end

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

local function isCrossingClear(from, to)
    local mx, my, mz = (from.x + to.x) / 2, (from.y + to.y) / 2, (from.z + to.z) / 2
    for _, vehicle in ipairs(getElementsWithinRange(mx, my, mz, CONFIG.clearRadius, "vehicle")) do
        local vx, vy, vz = getElementVelocity(vehicle)
        if (vx * vx + vy * vy + vz * vz) * 2500 > 1 then return false end
    end
    return true
end

local function sendTarget(walker, target)
    walker.target, walker.sentAt = target, getTickCount()
    if isElement(walker.owner) then
        triggerClientEvent(walker.owner, "vana-peds:walk", resourceRoot, walker.ped, target.x, target.y, target.z, target.hold)
    end
end

local function sendEngage(walker)
    local e = walker.encounter
    if e and isElement(walker.owner) then
        triggerClientEvent(walker.owner, "vana-peds:engage", resourceRoot, walker.ped, e.mode, e.target, e.vehicle,
            math.max(1000, e.untilTick - getTickCount()))
    end
end

local function setOwner(walker, owner)
    if walker.owner == owner then return end
    if isElement(walker.owner) then triggerClientEvent(walker.owner, "vana-peds:release", resourceRoot, walker.ped) end
    walker.owner = owner
    if owner then
        setElementSyncer(walker.ped, owner, true, true)
        if walker.encounter then sendEngage(walker) elseif walker.target then sendTarget(walker, walker.target) end
    end
end

local function removeWalker(walker, keepElement)
    walkers[walker.ped] = nil
    if isElement(walker.owner) then triggerClientEvent(walker.owner, "vana-peds:release", resourceRoot, walker.ped) end
    if not isElement(walker.ped) then return end
    if keepElement then
        -- Back to automatic syncing: a ped (or body) nobody syncs freezes wherever it was.
        setElementSyncer(walker.ped, true)
        released[walker.ped] = true
    else
        destroyElement(walker.ped)
    end
end

-- What already walks around a point, by population kind (for vana-population's picks).
local function countsNear(x, y, z)
    local counts, total = { gangs = {} }, 0
    for ped, walker in pairs(walkers) do
        local wx, wy, wz = getElementPosition(ped)
        if getDistanceBetweenPoints3D(x, y, z, wx, wy, wz) < CONFIG.spawnMax + 30 then
            total = total + 1
            counts[walker.kind] = (counts[walker.kind] or 0) + 1
            if walker.gang then counts.gangs[walker.gang] = (counts.gangs[walker.gang] or 0) + 1 end
        end
    end
    return counts, total
end

local function startWalker(ped, route, owner, kind, gang, personality)
    -- Clients lease GTA's ambient event profile (cops: the safe cop profile) for peds carrying this.
    setElementData(ped, "vana:ambient", kind)
    local x, y = getElementPosition(ped)
    local walker = { ped = ped, route = route, kind = kind, gang = gang, lastX = x, lastY = y, lastMoved = getTickCount(),
                     personality = personality or population:getPersonality(getElementModel(ped)) }
    walkers[ped] = walker
    setOwner(walker, owner)
    return walker
end

-- Where companion number `slot` walks relative to a leader at (x, y) facing `heading` (degrees):
-- alternately to the right and left, further rows slightly behind.
local function followerSlot(x, y, heading, slot)
    local h = math.rad(heading)
    local fx, fy = -math.sin(h), math.cos(h)
    local rx, ry = fy, -fx
    local row = math.ceil(slot / 2)
    local side = (slot % 2 == 1) and 1 or -1
    local across, back = side * companions.spacing * row, 0.6 * (row - 1)
    return x + rx * across - fx * back, y + ry * across - fy * back
end

local function trySpawnNear(player, players, counts)
    local px, py, pz = getElementPosition(player)
    local angle, r = math.random() * 2 * math.pi, CONFIG.spawnMin + math.random() * (CONFIG.spawnMax - CONFIG.spawnMin)
    local area, id = paths:findNearestNode(px + math.cos(angle) * r, py + math.sin(angle) * r, pz, "ped", 30)
    if not area then return false end

    local node = PedPlanner.getNode(area, id)
    if not node or node.spawnProbability == 0 then return false end
    local _, nearest = nearestPlayer(node.x, node.y, node.z, players)
    if nearest < CONFIG.spawnMin * 0.8 then return false end
    for ped in pairs(walkers) do
        local wx, wy, wz = getElementPosition(ped)
        if getDistanceBetweenPoints3D(wx, wy, wz, node.x, node.y, node.z) < CONFIG.pedSpacing then return false end
    end

    local route = PedPlanner.newRoute(area, id)
    if not route or route[2].crossing or not PedPlanner.isRouteOpen(route) then return false end
    local nxt = route[2]

    -- Vanilla population rules decide who walks here, or that the area is already full.
    local spec = population:pickPed(node.x, node.y, node.z, counts, CONFIG.density)
    if not spec then return false end

    local ped = createPed(spec.model, node.x, node.y, node.z + 1, math.deg(math.atan2(nxt.y - node.y, nxt.x - node.x)) - 90)
    if not ped then return false end
    if spec.weapon then giveWeapon(ped, spec.weapon, 500, spec.weaponDrawn) end
    if spec.kind == "cop" then giveWeapon(ped, 3, 1, false) end
    local leader = startWalker(ped, route, player, spec.kind, spec.gang, spec.personality)

    -- Couples and gang groups: companions keep a slot beside the leader, who walks the route.
    local size = 0
    if spec.kind == "civilian" and math.random() < companions.coupleChance then
        size = 1
    elseif spec.kind == "gang" and math.random() < companions.gangGroupChance then
        size = math.random(companions.gangGroupSize[1], companions.gangGroupSize[2])
    end
    local heading = math.deg(math.atan2(nxt.y - node.y, nxt.x - node.x)) - 90
    for slot = 1, size do
        local cspec = population:pickCompanion(node.x, node.y, node.z, spec)
        if not cspec then break end
        local cx, cy = followerSlot(node.x, node.y, heading, slot)
        local companion = createPed(cspec.model, cx, cy, node.z + 1, heading)
        if companion then
            if cspec.weapon then giveWeapon(companion, cspec.weapon, 500, cspec.weaponDrawn) end
            local follower = startWalker(companion, nil, player, cspec.kind, cspec.gang, cspec.personality)
            follower.leader, follower.slot = leader, slot
        end
    end
    return true
end

-- A fresh walking route from wherever the ped is now.
local function routeFromHere(ped)
    local x, y, z = getElementPosition(ped)
    -- Nearby first; a ped dropped far from any sidewalk (dragged out of a car on a highway) still
    -- gets somewhere to walk to rather than standing still.
    local area, id = paths:findNearestNode(x, y, z, "ped", 60)
    if not area then area, id = paths:findNearestNode(x, y, z, "ped", 250) end
    local route = area and PedPlanner.newRoute(area, id)
    if route then route.idx = 1 end -- head for the nearest sidewalk node first
    return route
end

-- Encounters: the server decides (personality, kind), the owner runs native tasks:
-- fight (kill on foot), flee (smart flee), jack (enter the target's car) or react (leave GTA's own
-- event response alone). Walking resumes from the nearest sidewalk when it ends.
local function startEncounter(walker, mode, target, vehicle)
    local e = rules.encounter
    local seconds = (mode == "fight" or mode == "jack" or mode == "arrest") and e.fightSeconds or mode == "flee" and e.fleeSeconds or e.reactSeconds
    walker.encounter = { mode = mode, target = target, vehicle = vehicle, untilTick = getTickCount() + seconds * 1000 }
    walker.target = nil
    if mode == "fight" then
        -- Draw the best carried weapon (cops and gang members holster theirs while walking).
        for slot = 7, 2, -1 do
            if (getPedWeapon(walker.ped, slot) or 0) > 0 then setPedWeaponSlot(walker.ped, slot) break end
        end
    elseif mode == "arrest" then
        -- Nightstick out: beat the player down for the bust, no shooting.
        if (getPedWeapon(walker.ped, 1) or 0) == 0 then giveWeapon(walker.ped, 3, 1, false) end
        setPedWeaponSlot(walker.ped, 1)
    end
    sendEngage(walker)
end

local function endEncounter(walker)
    if walker.encounter and walker.encounter.mode == "holdup" and isElement(walker.ped) then setPedAnimation(walker.ped) end
    walker.encounter, walker.target = nil, nil
    walker.route = routeFromHere(walker.ped) or walker.route
end

-- Takes over an existing ped as a pedestrian, e.g. an occupant who got out of (or was pulled from)
-- a traffic car, so car occupants and sidewalk pedestrians are one population. An encounter (from
-- the traffic collision that made them get out) starts straight away.
function adoptPed(ped, kind, gang, personality, encounter)
    if walkers[ped] or not isElement(ped) or isPedDead(ped) or getPedOccupiedVehicle(ped) then return false end
    local x, y, z = getElementPosition(ped)
    local owner = nearestPlayer(x, y, z, eligiblePlayers(), CONFIG.despawn)
    local route = owner and routeFromHere(ped)
    if not route then return false end
    local walker = startWalker(ped, route, owner, kind or "civilian", gang, personality)
    if encounter and isElement(encounter.target) then startEncounter(walker, encounter.mode, encounter.target, encounter.vehicle) end
    return true
end

-- A ped who has jacked a car drives off in it as traffic.
local function handToTraffic(walker, vehicle)
    local res = getResourceFromName("vana-traffic")
    if not res or getResourceState(res) ~= "running" then return false end
    local ok, adopted = pcall(function()
        return exports["vana-traffic"]:adoptVehicle(vehicle, walker.ped, walker.kind, walker.gang, walker.personality)
    end)
    if ok and adopted then
        walkers[walker.ped] = nil
        removeElementData(walker.ped, "vana:ambient")
        return true
    end
    return false
end

local function updateWalker(walker, players, signal, walkMsLeft)
    local ped = walker.ped
    if not isElement(ped) then return removeWalker(walker) end
    local e = walker.encounter
    local inVehicle = getPedOccupiedVehicle(ped)
    if e and e.mode == "jack" and inVehicle == e.vehicle and getVehicleOccupant(inVehicle, 0) == ped and handToTraffic(walker, inVehicle) then
        return
    end
    if isPedDead(ped) or inVehicle then return removeWalker(walker, true) end

    local x, y, z = getElementPosition(ped)
    local owner = nearestPlayer(x, y, z, players, CONFIG.despawn)
    if not owner then return removeWalker(walker) end
    local ownerGone = not isElement(walker.owner) or select(2, nearestPlayer(x, y, z, { walker.owner })) > CONFIG.ownerRadius
    if ownerGone and walker.owner ~= owner then setOwner(walker, owner) end
    -- Nobody simulating it (it freezes in its pose): hand it back to its owner, with its orders.
    local now0 = getTickCount()
    if isElement(walker.owner) and getElementSyncer(ped) ~= walker.owner and now0 - (walker.resynced or 0) > 2000 then
        walker.resynced = now0
        debugLog(("ped %s lost its syncer (%s): back to %s"):format(tostring(ped):sub(-8), tostring(getElementSyncer(ped)), getPlayerName(walker.owner)))
        setElementSyncer(ped, walker.owner, true, true)
        if walker.encounter then sendEngage(walker) elseif walker.target then sendTarget(walker, walker.target) end
    end

    if e then
        local target = e.target
        local tx, ty, tz
        if isElement(target) then tx, ty, tz = getElementPosition(target) end
        local over = getTickCount() > e.untilTick or not tx or (getElementType(target) ~= "vehicle" and isPedDead(target))
            or getDistanceBetweenPoints3D(x, y, z, tx, ty, tz) > rules.encounter.giveUpDistance
            -- An arrest is off once the player isn't wanted any more.
            or (e.mode == "arrest" and getElementType(target) == "player" and getPlayerWantedLevel(target) == 0)
        -- A jack that can't happen any more (the car drove off, or the ped got thrown aside): cops
        -- and gang members go for whoever has the car; others give up.
        if not over and e.mode == "jack" and isElement(e.vehicle) then
            local vx, vy, vz = getElementVelocity(e.vehicle)
            local ex, ey, ez = getElementPosition(e.vehicle)
            if (vx * vx + vy * vy + vz * vz) * 2500 > 36 or getDistanceBetweenPoints3D(x, y, z, ex, ey, ez) > 12 then
                local driver = getVehicleController(e.vehicle)
                if (walker.kind == "cop" or walker.kind == "gang") and driver then
                    startEncounter(walker, "fight", driver)
                    return
                end
                over = true
            end
        end
        if not over and e.mode == "holdup" then
            over = Holdup.update(walker)
            if over == "flee" then
                endEncounter(walker)
                startEncounter(walker, "flee", target)
                return
            end
        end
        if not over then
            walker.lastX, walker.lastY, walker.lastMoved = x, y, getTickCount()
            return
        end
        endEncounter(walker)
    end

    -- Companions follow their leader instead of planning a route; on their own once the leader is gone.
    local leader = walker.leader
    if leader and (walkers[leader.ped] ~= leader or not isElement(leader.ped)) then
        walker.leader = nil
        walker.route = routeFromHere(ped)
        if not walker.route then return removeWalker(walker) end
    elseif leader then
        local le = leader.encounter
        if le and isElement(le.target) and (le.mode == "fight" or le.mode == "flee") then
            -- A gang fights alongside; a civilian partner runs from a fight their partner picks.
            startEncounter(walker, (le.mode == "fight" and walker.kind ~= "gang") and "flee" or le.mode, le.target)
            return
        end
        local lx, ly, lz = getElementPosition(leader.ped)
        local _, _, rz = getElementRotation(leader.ped)
        local sx, sy = followerSlot(lx, ly, rz, walker.slot)
        local hold = leader.target and leader.target.hold or false
        local current = walker.target
        if not current or current.hold ~= hold or (current.x - sx) ^ 2 + (current.y - sy) ^ 2 > 6 then
            sendTarget(walker, { x = sx, y = sy, z = lz, hold = hold })
        end
        -- A follower left behind (far from its slot, not moving) gets its slot again; one that's lost its
        -- leader for good (FOLLOW_LOST m behind) walks on alone.
        local now = getTickCount()
        if (x - sx) ^ 2 + (y - sy) ^ 2 > CONFIG.followLost ^ 2 then
            debugLog(("follower %s %.0f m behind its leader: walks on alone"):format(tostring(ped):sub(-8), math.sqrt((x - sx) ^ 2 + (y - sy) ^ 2)))
            walker.leader, walker.target = nil, nil
            walker.route = routeFromHere(ped)
            if not walker.route then return removeWalker(walker) end
            return
        end
        if getDistanceBetweenPoints2D(x, y, walker.lastX, walker.lastY) > 1.5 or (x - sx) ^ 2 + (y - sy) ^ 2 < 16 then
            walker.lastX, walker.lastY, walker.lastMoved = x, y, now
        elseif now - walker.lastMoved > CONFIG.stuckMs and now - (walker.retried or 0) > CONFIG.stuckMs then
            walker.retried = now
            debugLog(("follower %s stuck %.0f m from its slot: sent again"):format(tostring(ped):sub(-8), math.sqrt((x - sx) ^ 2 + (y - sy) ^ 2)))
            sendTarget(walker, { x = sx, y = sy, z = lz, hold = hold })
        end
        return
    end

    local route = walker.route
    if not route then
        walker.route = routeFromHere(ped)
        if not walker.route then return removeWalker(walker, true) end
        route = walker.route
    end
    PedPlanner.advance(route, x, y)
    if not PedPlanner.extend(route) and route.idx >= #route then return removeWalker(walker) end

    local target = PedPlanner.chooseTarget(route, x, y, signal, walkMsLeft, isCrossingClear)
    if PedPlanner.needsNewTarget(walker.target, target, x, y, getTickCount() - (walker.sentAt or 0)) then
        sendTarget(walker, target)
    end

    -- Stuck recovery, as for traffic. Fleeing or fighting peds also land here and get re-tasked: the
    -- target again, then (after CONFIG.resends in vain) a fresh route from here. Holding at a kerb
    -- isn't stuck, up to CONFIG.maxHoldMs.
    local now = getTickCount()
    if getDistanceBetweenPoints2D(x, y, walker.lastX, walker.lastY) > 1.5 then
        walker.lastX, walker.lastY, walker.lastMoved, walker.resends, walker.holdSince = x, y, now, 0, nil
    elseif target.hold then
        walker.lastMoved = now
        walker.holdSince = walker.holdSince or now
        if now - walker.holdSince > CONFIG.maxHoldMs then
            debugLog(("ped %s waited %.0fs at a kerb: a new route"):format(tostring(ped):sub(-8), (now - walker.holdSince) / 1000))
            walker.holdSince, walker.target = nil, nil
            walker.route = routeFromHere(ped) or walker.route
        end
    elseif now - walker.lastMoved > CONFIG.stuckMs then
        local _, ownerDist = nearestPlayer(x, y, z, players)
        if ownerDist > 50 and now - walker.lastMoved > 60000 then return removeWalker(walker) end
        if now - (walker.retried or 0) > CONFIG.stuckMs then
            walker.retried = now
            walker.resends = (walker.resends or 0) + 1
            if walker.resends > CONFIG.resends then
                debugLog(("ped %s stuck %.0fs after %d sends: a new route"):format(tostring(ped):sub(-8), (now - walker.lastMoved) / 1000, walker.resends - 1))
                walker.resends, walker.target = 0, nil
                walker.route = routeFromHere(ped) or walker.route
            else
                sendTarget(walker, target)
            end
        end
    end
end

setTimer(function()
    local players = eligiblePlayers()
    local signal = paths:getPedSignal()
    local _, _, walkMsLeft = exports["vana-lights"]:getPhase()
    if signal ~= "walk" then walkMsLeft = 0 end
    for _, walker in pairs(walkers) do updateWalker(walker, players, signal, walkMsLeft or 0) end
    challengePlayers(players)

    for ped in pairs(released) do
        if not isElement(ped) then
            released[ped] = nil
        else
            local x, y, z = getElementPosition(ped)
            if not nearestPlayer(x, y, z, players, CONFIG.despawn) then
                released[ped] = nil
                destroyElement(ped)
            end
        end
    end

    if not enabled then return end
    for _, player in ipairs(players) do
        local counts, total = countsNear(getElementPosition(player))
        if total < CONFIG.maxPerPlayer then trySpawnNear(player, players, counts) end
    end
end, CONFIG.tick, 0)

addEventHandler("onPlayerQuit", root, function()
    for _, walker in pairs(walkers) do
        if walker.owner == source then walker.owner = nil end
    end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for _, walker in pairs(walkers) do removeWalker(walker) end
end)

-- Admin control. Restricted: needs command.peds in the ACL (see docs/setup.md).
addCommandHandler("peds", function(source, _, action, value)
    local reply = function(msg)
        if getElementType(source) == "console" then outputServerLog("[peds] " .. msg) else outputChatBox(msg, source, 200, 200, 255) end
    end
    local count = 0
    for _ in pairs(walkers) do count = count + 1 end
    if action == "on" then
        enabled = true
        reply("Pedestrian spawning on.")
    elseif action == "off" then
        enabled = false
        reply("Pedestrian spawning off; existing pedestrians walk on until out of range.")
    elseif action == "clear" then
        for _, walker in pairs(walkers) do removeWalker(walker) end
        reply(("Removed %d pedestrians."):format(count))
    elseif action == "density" and tonumber(value) then
        Settings.set("density", math.max(0, math.min(300, tonumber(value))) / 100) -- kept across restarts
        reply(("Pedestrian density set to %d%% of vanilla."):format(CONFIG.density * 100))
    else
        reply(("Pedestrians are %s: %d walking, density %d%% of vanilla. Usage: /peds on|off|clear|density <percent>")
            :format(enabled and "on" or "off", count, CONFIG.density * 100))
    end
end, true)


-- Forwards a crime to vana-services (wanted levels), when it runs.
local function reportCrime(player, crime, x, y, z)
    local res = getResourceFromName("vana-services")
    if not res or getResourceState(res) ~= "running" then return end
    pcall(function() exports["vana-services"]:reportCrime(player, crime, x, y, z) end)
end

-- Our pedestrians of a kind ("civilian", "cop", "gang", or nil for any) within radius of a point,
-- not already in an encounter.
function findPeds(x, y, z, radius, kind)
    local list = {}
    for ped, w in pairs(walkers) do
        if (not kind or w.kind == kind) and not w.encounter and isElement(ped) and not isPedDead(ped) then
            local px, py, pz = getElementPosition(ped)
            if getDistanceBetweenPoints3D(x, y, z, px, py, pz) < radius then list[#list + 1] = ped end
        end
    end
    return list
end

-- Lets other resources (police response) send one of our peds into an encounter.
function engagePed(ped, mode, target)
    local walker = walkers[ped]
    if not walker or not isElement(target) then return false end
    local e = walker.encounter
    if e and e.mode == mode and e.target == target then return true end
    startEncounter(walker, mode, target)
    return true
end

local function rivals(a, b)
    return a and b and rules.rivals[a] and rules.rivals[a][b] or false
end

-- Members of `gang` near (x, y, z) join a fight against `attacker` (not hitting each other).
local function backup(gang, x, y, z, attacker, except)
    if not gang or not isElement(attacker) then return end
    for other, w in pairs(walkers) do
        if w ~= except and w.gang == gang and other ~= attacker and not (w.encounter and w.encounter.mode == "fight") then
            local ox, oy, oz = getElementPosition(other)
            if getDistanceBetweenPoints3D(x, y, z, ox, oy, oz) < rules.gangBackupRadius then startEncounter(w, "fight", attacker) end
        end
    end
end

-- Someone attacked one of our peds: kind and personality decide. attacker: a player or a ped.
local function attacked(walker, attacker, weapon)
    local ped = walker.ped
    local x, y, z = getElementPosition(ped)
    local byPlayer = getElementType(attacker) == "player"
    if byPlayer then
        local stab = weapon == 4
        if walker.kind == "cop" then
            reportCrime(attacker, stab and "stab_cop" or "damaged_cop", x, y, z)
        else
            reportCrime(attacker, stab and "stab_ped" or "damaged_ped", x, y, z)
        end
    end
    local current = walker.encounter
    if current and current.target == attacker and current.mode ~= "react" and current.mode ~= "holdup" then return end
    if current and current.mode == "holdup" then endEncounter(walker) end

    local p = walker.personality or {}
    local mode
    if walker.kind == "cop" then
        -- Hitting a cop makes the player wanted (vana-services). Under two stars with nothing in hand
        -- cops arrest (nightstick); otherwise they shoot.
        mode = (byPlayer and getPlayerWantedLevel(attacker) <= 1 and (getPedWeapon(attacker) or 0) == 0) and "arrest" or "fight"
    elseif walker.kind == "gang" then
        mode = (p.fear or 0) >= 70 and "flee" or "fight"
    elseif (p.fear or 50) >= rules.collision.fleeFear then
        mode = "flee"
    elseif (p.temper or 50) >= 70 then
        mode = "fight"
    else
        mode = "react"
    end
    startEncounter(walker, mode, attacker)

    -- Gang members come to each other's aid; the player's own gang also helps against its rivals.
    if walker.kind == "gang" then
        local attackerGang = byPlayer and rules.playerGang or (walkers[attacker] and walkers[attacker].gang)
        if attackerGang ~= walker.gang then backup(walker.gang, x, y, z, attacker, walker) end
        if byPlayer and rivals(rules.playerGang, walker.gang) then backup(rules.playerGang, x, y, z, ped) end
    end
end

-- A ped we simulate was hurt (reported by its owner) by a player or another ped.
-- The owner's client gave up on an order (it never took, several times): a fight is called off, a
-- walk gets a fresh route.
addEvent("vana-peds:stuck", true)
addEventHandler("vana-peds:stuck", resourceRoot, function(ped)
    local walker = walkers[ped]
    if not walker or walker.owner ~= client then return end
    if walker.encounter then
        debugLog(("ped %s: its %s never took on %s's client: called off"):format(tostring(ped):sub(-8), walker.encounter.mode, getPlayerName(client)))
        return endEncounter(walker)
    end
    debugLog(("ped %s: its walk never took on %s's client: a new route"):format(tostring(ped):sub(-8), getPlayerName(client)))
    walker.target = nil
    walker.route = routeFromHere(ped) or walker.route
end)

-- The owner's client found the ped hanging in the air: no ground loaded under it and out of view, or
-- still hanging after being put down twice.
addEvent("vana-peds:lost", true)
addEventHandler("vana-peds:lost", resourceRoot, function(ped)
    local walker = walkers[ped]
    if not walker or walker.owner ~= client then return end
    debugLog(("ped %s hanging in the air on %s's client: removed"):format(tostring(ped):sub(-8), getPlayerName(client)))
    removeWalker(walker)
end)

addEvent("vana-peds:attacked", true)
addEventHandler("vana-peds:attacked", resourceRoot, function(ped, attacker, weapon)
    local walker = walkers[ped]
    if not walker or walker.owner ~= client or not isElement(attacker) or attacker == ped then return end
    local kind = getElementType(attacker)
    if kind ~= "player" and kind ~= "ped" then return end
    local x, y, z = getElementPosition(ped)
    local ax, ay, az = getElementPosition(attacker)
    if getDistanceBetweenPoints3D(x, y, z, ax, ay, az) > 60 then return end
    attacked(walker, attacker, weapon)
end)

-- A player was hurt by a ped (reported by that player): their gang's members nearby defend them.
addEvent("vana-peds:playerAttacked", true)
addEventHandler("vana-peds:playerAttacked", resourceRoot, function(attacker)
    if not isElement(attacker) or getElementType(attacker) ~= "ped" or isPedDead(client) then return end
    local w = walkers[attacker]
    if w and w.gang == rules.playerGang then return end -- a homie hitting back stays between the two
    local x, y, z = getElementPosition(client)
    local ax, ay, az = getElementPosition(attacker)
    if getDistanceBetweenPoints3D(x, y, z, ax, ay, az) > 60 then return end
    backup(rules.playerGang, x, y, z, attacker)
end)

-- Rival gang members start fights with players close by (on foot, or crawling along in a car).
local lastChallenge = {} -- walker -> { [player] = tick }
function challengePlayers(players)
    local now = getTickCount()
    for _, player in ipairs(players) do
        local car = getPedOccupiedVehicle(player)
        local slow = true
        if car then
            local vx, vy, vz = getElementVelocity(car)
            slow = (vx * vx + vy * vy + vz * vz) * 2500 < rules.initiateMaxCarSpeed ^ 2
        end
        if slow and not isPedDead(player) then
            local px, py, pz = getElementPosition(player)
            for ped, w in pairs(walkers) do
                if not w.encounter and not w.leader and rivals(rules.playerGang, w.gang) then
                    local x, y, z = getElementPosition(ped)
                    local seen = lastChallenge[w] and lastChallenge[w][player]
                    if getDistanceBetweenPoints3D(x, y, z, px, py, pz) < rules.initiateRadius
                        and (not seen or now - seen > rules.initiateCooldown * 1000)
                        and math.random() < rules.initiateChance * CONFIG.tick / 1000 then
                        lastChallenge[w] = lastChallenge[w] or {}
                        lastChallenge[w][player] = now
                        startEncounter(w, "fight", player)
                    end
                end
            end
        end
    end
end

-- Dead ambient peds and traffic occupants drop their weapons and sometimes cash (config/drops.lua).
local drops = population:getDropRules()

local function temporaryPickup(pickup, onHit)
    if not pickup then return end
    setTimer(function() if isElement(pickup) then destroyElement(pickup) end end, drops.lifetimeSeconds * 1000, 1)
    addEventHandler("onPickupHit", pickup, function(player)
        if getElementType(player) ~= "player" or isPedDead(player) then return end
        if onHit then onHit(player) end
        setTimer(function() if isElement(pickup) then destroyElement(pickup) end end, 50, 1)
    end)
end

addEventHandler("onPedWasted", root, function()
    local ped = source
    local kind = getElementData(ped, "vana:ambient") or getElementData(ped, "vana:traffic")
    if not kind then return end
    local x, y, z = getElementPosition(ped)
    for slot = 1, 12 do
        local weapon, ammo = getPedWeapon(ped, slot), getPedTotalAmmo(ped, slot)
        if weapon and weapon > 0 and ammo and ammo > 0 then
            -- Weapon pickups hand over the weapon themselves when walked over.
            temporaryPickup(createPickup(x + math.random() - 0.5, y + math.random() - 0.5, z - 0.5, 2, weapon, 3600000,
                math.min(ammo, drops.maxAmmo)))
        end
    end
    local money = drops.money[kind] or drops.money.civilian
    if money and math.random() < money.chance then
        local amount = math.random(money.min, money.max)
        temporaryPickup(createPickup(x, y, z - 0.5, 3, 1212, 3600000), function(player) givePlayerMoney(player, amount) end)
    end
end)

---------------------------------------------------------------------------------------------------
-- Holdups: a player aiming a gun at one of our peds (reported by that player's client while aiming).

local H = rules.holdup
local aims = {} -- ped -> { player, first, last, cash }

local function armed(ped)
    for slot = 2, 7 do
        if (getPedWeapon(ped, slot) or 0) > 0 then return true end
    end
    return false
end

-- Keeps a holdup going; returns "flee" once the player stops aiming (or someone else took over).
function Holdup.update(walker)
    local ped, e = walker.ped, walker.encounter
    local a = aims[ped]
    local now = getTickCount()
    if not a or a.player ~= e.target or not isElement(a.player) or now - a.last > H.releaseMs then return "flee" end
    if not a.cash and now - a.first >= H.cashSeconds * 1000 then
        a.cash = true
        local x, y, z = getElementPosition(ped)
        reportCrime(a.player, "holdup", x, y, z)
        local range = H.cash[walker.kind] or H.cash.civilian
        if range[2] > 0 then
            local amount = math.random(range[1], range[2])
            temporaryPickup(createPickup(x + 0.6, y, z - 0.5, 3, 1212, 3600000), function(player) givePlayerMoney(player, amount) end)
        end
    end
    return false
end

addEvent("vana-peds:aimed", true)
addEventHandler("vana-peds:aimed", resourceRoot, function(ped)
    local walker = walkers[ped]
    if not walker or isPedDead(client) or not isElement(ped) or isPedDead(ped) then return end
    local x, y, z = getElementPosition(ped)
    local px, py, pz = getElementPosition(client)
    if getDistanceBetweenPoints3D(x, y, z, px, py, pz) > H.maxDistance then return end
    local now = getTickCount()
    local a = aims[ped]
    if a and a.player == client and now - a.last < H.releaseMs then a.last = now return end
    aims[ped] = { player = client, first = now, last = now }
    local e = walker.encounter
    if e and e.target == client and e.mode ~= "react" then return end

    local p = walker.personality or {}
    if walker.kind == "cop" then
        reportCrime(client, "threaten_cop", x, y, z)
        startEncounter(walker, "fight", client)
    elseif walker.kind == "gang" then
        if walker.gang == rules.playerGang then return end -- a homie lets it go
        startEncounter(walker, (p.fear or 0) >= 70 and "flee" or "fight", client)
        backup(walker.gang, x, y, z, client, walker)
    elseif (p.temper or 50) >= H.fightTemper and armed(ped) then
        startEncounter(walker, "fight", client)
    elseif (p.fear or 50) >= H.handsUpFear then
        startEncounter(walker, "holdup", client)
        walker.encounter.untilTick = now + H.maxSeconds * 1000
        setPedAnimation(ped, "ped", "handsup", -1, false, false, false, true)
    else
        startEncounter(walker, "flee", client)
    end
end)

addEventHandler("onElementDestroy", root, function()
    if getElementType(source) == "ped" then aims[source] = nil end
end)

-- For vana-core's stuck-ped debug (docs/debug.md): what this resource last told a ped.
function describePed(ped)
    local w = walkers[ped]
    if not w then return released[ped] and "released (no orders, automatic sync)" or nil end
    local now = getTickCount()
    local function ago(t) return t and ("%.0fs ago"):format((now - t) / 1000) or "never" end
    local order
    if w.encounter then
        local e = w.encounter
        order = ("encounter %s on %s, %.0fs left"):format(e.mode, isElement(e.target) and getElementType(e.target) or "nothing", (e.untilTick - now) / 1000)
    elseif w.target then
        local t = w.target
        order = ("%s to %.1f, %.1f%s, sent %s"):format(w.leader and "follow" or "walk", t.x, t.y, t.hold and " (hold at kerb)" or "", ago(w.sentAt))
    else
        order = "no target"
    end
    return ("%s%s, %s; moved %s, re-sent %s; owner %s"):format(w.kind, w.gang and (" " .. w.gang) or "", order, ago(w.lastMoved), ago(w.retried),
        isElement(w.owner) and (getPlayerName(w.owner):gsub("#%x%x%x%x%x%x", "")) or "none")
end
