-- Wildlife: animals at their places ([data]/vana-data-wildlife's spawners, from Myths Maker 2.7's
-- animal pack; how each species behaves: config/wildlife.lua; the levers: this resource's settings).
-- A spawner wakes when a player comes within its findRadius, at its hours, and keeps up to its
-- quantity (times the density setting) alive, within the per-player and total caps, never appearing
-- within minSpawnDistance of a player. Each animal has a small brain here: it idles and wanders round
-- its spot, prey runs from people near it, predators may go for one they see (aggroChance every
-- aggroCheckMs within aggroRange), anything hurt flees or fights back; an attack is a chase and a bite
-- (the spawner's damage times damageScale). The owning client (the nearest player) runs a ped's
-- orders; an object is moved here. Gone when nobody is near.
local CONFIG = {
    enabled = true, species = "hare,deer,boar,cat,dog,wolf,brownbear,blackbear,puma,leopard",
    density = 1, maxPerPlayer = 12, maxTotal = 60, minSpawnDistance = 30, despawnMargin = 60,
    aggroChance = 0.5, aggroCheckMs = 5000, aggroRange = 25, fleeRange = 14, leash = 60, damageScale = 0.5, tick = 1000,
}
Settings.bind(CONFIG, { enabled = "bool", species = "string", density = "number", maxPerPlayer = "number", maxTotal = "number",
    minSpawnDistance = "number", despawnMargin = "number", aggroChance = "number", aggroCheckMs = "number", aggroRange = "number",
    fleeRange = "number", leash = "number", damageScale = "number" }, function(name)
    if name == "enabled" and not CONFIG.enabled then for _, a in pairs(Wildlife.animals) do Wildlife.remove(a) end end
    if name == "species" then Wildlife.readSpecies() end
end)

Wildlife = { animals = {} } -- element -> animal
local spawners = {}         -- index -> { alive, nextAt }
local allowed = {}          -- species -> true (the species setting, of those config/wildlife.lua knows)
local count = 0
local ready = {}            -- players whose client has started this resource (the files downloaded)

function Wildlife.readSpecies()
    allowed = {}
    for id in CONFIG.species:gmatch("[%w_]+") do
        if WildlifeKinds[id] and WildlifeSpecies[id] then allowed[id] = true end
    end
end
Wildlife.readSpecies()

local function debugLog(text) if Debug.on("brains") then Debug.log("brains", text) end end

-- Players outdoors: alive ones wake spawners and draw animals' attention; dead ones (waiting to
-- respawn) still keep the animals round them.
local function outdoorPlayers(withDead)
    local list = {}
    for _, p in ipairs(getElementsByType("player")) do
        if getElementInterior(p) == 0 and getElementDimension(p) == 0 and (withDead or not isPedDead(p)) then list[#list + 1] = p end
    end
    return list
end

local function nearest(x, y, z, players)
    local best, who = math.huge, nil
    for _, p in ipairs(players) do
        local px, py, pz = getElementPosition(p)
        local d = getDistanceBetweenPoints3D(x, y, z, px, py, pz)
        if d < best then best, who = d, p end
    end
    return best, who
end

local function open(s, hour)
    if s.startHour == s.endHour then return true end
    if s.startHour < s.endHour then return hour >= s.startHour and hour < s.endHour end
    return hour >= s.startHour or hour < s.endHour
end

-- Orders: a ped's go to the owning client; an object is moved here.
local function order(a, mode, x, y, z, target)
    a.mode, a.target = mode, target
    if a.kind.driver == "object" then
        if mode == "attack" or not x then return end
        local ox, oy, oz = getElementPosition(a.element)
        local d = getDistanceBetweenPoints2D(ox, oy, x, y)
        local speed = mode == "flee" and 6 or 1.4
        setElementRotation(a.element, 0, 0, math.deg(math.atan2(x - ox, y - oy)) * -1)
        moveObject(a.element, math.max(50, d / speed * 1000), x, y, z or oz)
        return
    end
    if isElement(a.owner) and ready[a.owner] then triggerClientEvent(a.owner, "vana-wildlife:order", resourceRoot, a.element, mode, x, y, z, target) end
end

function Wildlife.remove(a, keepCount)
    if Wildlife.animals[a.element] then
        Wildlife.animals[a.element] = nil
        count = count - 1
        local sp = spawners[a.spawner]
        if sp and not keepCount then sp.alive = math.max(0, sp.alive - 1) end
    end
    if isElement(a.element) then destroyElement(a.element) end
end

local function setOwner(a, player)
    if a.owner == player or a.kind.driver ~= "ped" then return end
    a.owner = player
    if isElement(player) then
        setElementSyncer(a.element, player, true, true)
        if a.mode then order(a, a.mode, a.tx, a.ty, a.tz, a.target) end
    end
end

-- Spawns one round the spot, out of every player's sight distance (minSpawnDistance from the point it
-- appears at, not the spot: the pack scatters them up to spawnRadius); false when no point is far enough.
local function spawn(index, s, owner, players)
    local kind, species = WildlifeKinds[s.species], WildlifeSpecies[s.species]
    local variant = math.random(#species.variants)
    local x, y, z
    for _ = 1, 6 do
        local angle, r = math.random() * 2 * math.pi, math.random() * (s.spawnRadius or 10)
        x, y, z = s[1] + math.cos(angle) * r, s[2] + math.sin(angle) * r, s[3]
        if not players or nearest(x, y, z, players) > CONFIG.minSpawnDistance then break end
        x = nil
    end
    if not x then return false end
    local element
    if kind.driver == "ped" then
        element = createPed(7, x, y, z + 0.5, s.angle or math.random(0, 359))
        if not element then return end
        setPedWalkingStyle(element, 54) -- "man": the walkcycle the species' own animations take the place of
    else
        element = createObject(1337, x, y, z, 0, 0, s.angle or 0)
        if not element then return end
    end
    setElementData(element, "vana:animal", s.species .. "|" .. variant)
    setElementData(element, "vana:animalHealth", s.health or 100)
    setElementData(element, "vana:fairGame", true) -- no crime for killing one, no ambulance for the body
    -- Home is where it appeared (the pack scatters them up to spawnRadius, often 100 m, round the spot).
    local a = { element = element, spawner = index, species = s.species, kind = kind, home = { x, y, z },
                wander = math.max(8, math.min(30, (s.spawnRadius or 10) * 1.5)), mode = nil, nextAt = getTickCount() + math.random(2000, 8000) }
    Wildlife.animals[element] = a
    count = count + 1
    spawners[index].alive = spawners[index].alive + 1
    setOwner(a, owner)
    order(a, "idle")
    debugLog(("%s spawned at %.0f, %.0f, %.0f (spot %d, %d/%d there; %s simulates)"):format(s.species, x, y, z, index,
        spawners[index].alive, math.ceil((s.quantity or 1) * CONFIG.density), isElement(owner) and getPlayerName(owner) or "nobody"))

    return true
end

-- The brain, once a tick.
local function think(a, players, everyone, now)
    local e = a.element
    local x, y, z = getElementPosition(e)
    if a.kind.driver == "ped" and isPedDead(e) then
        if not a.deadSince then debugLog(("%s died"):format(a.species)) end
        a.deadSince = a.deadSince or now
        if now - a.deadSince > 20000 then
            local sp = spawners[a.spawner]
            if sp then sp.nextAt = now + (WildlifeSpawners[a.spawner].respawn or 10) * 1000 end
            Wildlife.remove(a)
        end
        return
    end
    local dist, who = nearest(x, y, z, players)
    local s = WildlifeSpawners[a.spawner]
    -- Gone once nobody is near its spot (as it woke), or far from the animal itself.
    local fromSpot = nearest(s[1], s[2], s[3], everyone)
    if fromSpot > (s.findRadius or 80) + CONFIG.despawnMargin or nearest(x, y, z, everyone) > 250 then
        debugLog(("%s despawned (nearest player %.0f m from its spot, %.0f m from it)"):format(a.species, fromSpot, dist))
        return Wildlife.remove(a)
    end
    -- Simulated by the nearest player, unless it's going for someone.
    if a.mode ~= "attack" and who and getElementSyncer(e) ~= who then setOwner(a, who) end

    local behaviour = a.kind.behaviour
    if a.mode == "attack" then
        local t = a.target
        if not isElement(t) or isPedDead(t) or now > a.untilTick or getDistanceBetweenPoints3D(x, y, z, getElementPosition(t)) > 50 then
            debugLog(("%s gives up the chase"):format(a.species))
            a.nextAt = now
            order(a, "idle")
        end
        return
    end
    if a.mode == "flee" and now < a.untilTick then return end
    -- Prey runs from anyone close.
    if behaviour == "prey" and who and dist < CONFIG.fleeRange then
        local px, py = getElementPosition(who)
        local dx, dy = x - px, y - py
        local len = math.max(0.1, math.sqrt(dx * dx + dy * dy))
        a.tx, a.ty, a.tz, a.untilTick = x + dx / len * 35, y + dy / len * 35, z, now + 8000
        debugLog(("%s flees from %s (%.0f m)"):format(a.species, getPlayerName(who), dist))
        order(a, "flee", a.tx, a.ty, a.tz)
        return
    end
    -- A predator may go for someone it sees.
    if behaviour == "predator" and who and dist < CONFIG.aggroRange and now >= (a.aggroAt or 0) then
        a.aggroAt = now + CONFIG.aggroCheckMs
        if math.random() < CONFIG.aggroChance then
            debugLog(("%s goes for %s (%.0f m)"):format(a.species, getPlayerName(who), dist))
            a.untilTick = now + 25000
            setOwner(a, who)
            order(a, "attack", nil, nil, nil, who)
            return
        end
    end
    -- Too far from home: back.
    if getDistanceBetweenPoints2D(x, y, a.home[1], a.home[2]) > CONFIG.leash then
        a.tx, a.ty, a.tz = a.home[1], a.home[2], a.home[3]
        order(a, "walk", a.tx, a.ty, a.tz)
        a.nextAt = now + 20000
        return
    end
    -- Idle a while, wander a little.
    if now >= a.nextAt then
        if a.mode == "walk" or a.mode == "flee" then
            order(a, "idle")
            a.nextAt = now + math.random(4000, 14000)
        else
            local ang, r = math.random() * 2 * math.pi, math.random() * a.wander
            a.tx, a.ty, a.tz = a.home[1] + math.cos(ang) * r, a.home[2] + math.sin(ang) * r, a.home[3]
            order(a, "walk", a.tx, a.ty, a.tz)
            a.nextAt = now + math.random(10000, 20000)
        end
    end
end

-- Hurt by a player (reported by them): prey runs, the rest fight back.
addEvent("vana-wildlife:hurt", true)
addEventHandler("vana-wildlife:hurt", resourceRoot, function(element)
    local a = Wildlife.animals[element]
    if not a or a.kind.driver ~= "ped" or isPedDead(element) or a.target == client then return end
    local now = getTickCount()
    debugLog(("%s hurt by %s: %s"):format(a.species, getPlayerName(client), a.kind.behaviour == "prey" and "flees" or "fights back"))
    if a.kind.behaviour == "prey" then
        local x, y, z = getElementPosition(element)
        local px, py = getElementPosition(client)
        local dx, dy = x - px, y - py
        local len = math.max(0.1, math.sqrt(dx * dx + dy * dy))
        a.tx, a.ty, a.tz, a.untilTick = x + dx / len * 40, y + dy / len * 40, z, now + 10000
        order(a, "flee", a.tx, a.ty, a.tz)
    else
        a.untilTick = now + 25000
        setOwner(a, client)
        order(a, "attack", nil, nil, nil, client)
    end
end)

-- Killed where it's simulated (its toughness is applied there): only its syncer says so.
addEvent("vana-wildlife:killed", true)
addEventHandler("vana-wildlife:killed", resourceRoot, function(element, attacker)
    local a = Wildlife.animals[element]
    if not a or a.kind.driver ~= "ped" or isPedDead(element) or getElementSyncer(element) ~= client then return end
    killPed(element, isElement(attacker) and attacker or nil)
end)

-- A bite, from the client chasing with it: only while it's going for that one, close, now and then.
addEvent("vana-wildlife:bite", true)
addEventHandler("vana-wildlife:bite", resourceRoot, function(element, target)
    local a = Wildlife.animals[element]
    if not a or a.mode ~= "attack" or a.target ~= target or a.owner ~= client or isPedDead(element) then return end
    if not isElement(target) or isPedDead(target) then return end
    local now = getTickCount()
    if now < (a.biteAt or 0) then return end
    local x, y, z = getElementPosition(element)
    if getDistanceBetweenPoints3D(x, y, z, getElementPosition(target)) > 3.5 then return end
    a.biteAt = now + 1000
    local loss = (WildlifeSpawners[a.spawner].damage or 0) * CONFIG.damageScale
    local health = getElementHealth(target) - loss
    if health <= 0 then killPed(target, element) else setElementHealth(target, health) end
end)

setTimer(function()
    if not CONFIG.enabled then return end
    local players, everyone, now, hour = outdoorPlayers(), outdoorPlayers(true), getTickCount(), getTime()
    for _, a in pairs(Wildlife.animals) do
        if isElement(a.element) then think(a, players, everyone, now) else Wildlife.remove(a) end
    end
    -- Spawning, near each player, within the caps.
    for _, player in ipairs(players) do
        local px, py, pz = getElementPosition(player)
        local near = 0
        for _, a in pairs(Wildlife.animals) do
            local x, y, z = getElementPosition(a.element)
            if getDistanceBetweenPoints3D(x, y, z, px, py, pz) < 200 then near = near + 1 end
        end
        local made = 0
        for i, s in ipairs(WildlifeSpawners) do
            if near + made >= CONFIG.maxPerPlayer or count >= CONFIG.maxTotal or made >= 2 then break end
            if allowed[s.species] and open(s, hour) then
                local d = getDistanceBetweenPoints3D(s[1], s[2], s[3], px, py, pz)
                local sp = spawners[i]
                if not sp then sp = { alive = 0, nextAt = 0 } spawners[i] = sp end
                if d < (s.findRadius or 80) and now >= sp.nextAt
                    and sp.alive < math.ceil((s.quantity or 1) * CONFIG.density)
                then
                    if spawn(i, s, player, players) then made = made + 1 end
                    sp.nextAt = now + 3000 -- one at a time per spot
                end
            end
        end
    end
end, CONFIG.tick, 0)

addEventHandler("onResourceStop", resourceRoot, function()
    for _, a in pairs(Wildlife.animals) do if isElement(a.element) then destroyElement(a.element) end end
end)

-- A client ready for orders: those of the animals it already simulates, again.
addEvent("vana-wildlife:ready", true)
addEventHandler("vana-wildlife:ready", resourceRoot, function()
    ready[client] = true
    for _, a in pairs(Wildlife.animals) do
        if a.owner == client and a.mode then order(a, a.mode, a.tx, a.ty, a.tz, a.target) end
    end
end)

addEventHandler("onPlayerQuit", root, function()
    ready[source] = nil
    for _, a in pairs(Wildlife.animals) do if a.owner == source then a.owner = nil end end
end)

-- Admin: an animal 8 m in front of you. Restricted: command.animal.
addCommandHandler("animal", function(player, _, species)
    if getElementType(player) ~= "player" then return end
    if not species or not WildlifeKinds[species] then
        local list = {}
        for id in pairs(WildlifeKinds) do list[#list + 1] = id end
        table.sort(list)
        return outputChatBox("Usage: /animal <" .. table.concat(list, "|") .. ">", player, 200, 200, 255)
    end
    local x, y, z = getElementPosition(player)
    local _, _, rz = getElementRotation(player)
    local h = math.rad(rz)
    local index = #WildlifeSpawners + 1 -- a spot of its own, not saved
    WildlifeSpawners[index] = { x - math.sin(h) * 8, y + math.cos(h) * 8, z, species = species, quantity = 1, startHour = 0, endHour = 0,
        findRadius = 120, spawnRadius = 0, health = 200, damage = 20, respawn = 3600, angle = rz + 180, temporary = true }
    spawners[index] = { alive = 0, nextAt = math.huge }
    spawn(index, WildlifeSpawners[index], player)
    outputChatBox(("A %s, 8 m ahead of you."):format(WildlifeSpecies[species].name:lower()), player, 200, 200, 255)
end, true)

-- Console-only: every spawner names a known species, and every species' files are here.
addCommandHandler("wildlifetest", function(source)
    if getElementType(source) ~= "console" then return end
    local ok, bySpecies, unknown = true, {}, 0
    for _, s in ipairs(WildlifeSpawners) do
        if WildlifeSpecies[s.species] then
            if not s.temporary then bySpecies[s.species] = (bySpecies[s.species] or 0) + 1 end
        else
            unknown = unknown + 1
        end
    end
    if unknown > 0 or #WildlifeSpawners == 0 then ok = false end -- none at all: vana-data-wildlife is missing
    local missing, files = {}, 0
    for id, sp in pairs(WildlifeSpecies) do
        local list = {}
        for _, v in ipairs(sp.variants) do list[#list + 1] = v[1] list[#list + 1] = v[2] end
        for _, p in ipairs(sp.ifps) do list[#list + 1] = p end
        for _, p in ipairs(sp.sounds.random) do list[#list + 1] = p end
        for _, p in ipairs(sp.sounds.damage) do list[#list + 1] = p end
        if #sp.variants == 0 then missing[#missing + 1] = id .. ": no model" end
        for _, p in ipairs(list) do
            files = files + 1
            if not fileExists(p) then missing[#missing + 1] = p end
        end
    end
    for id, k in pairs(WildlifeKinds) do
        if not WildlifeSpecies[id] then missing[#missing + 1] = id .. ": no species" end
        if k.walk and not fileExists(k.walk.ifp) then missing[#missing + 1] = k.walk.ifp end
    end
    if #missing > 0 then ok = false end
    local counts = {}
    for id, n in pairs(bySpecies) do counts[#counts + 1] = ("%s %d"):format(id, n) end
    table.sort(counts)
    outputServerLog(("[wildlifetest] %d spawners (%s), %d of unknown species"):format(#WildlifeSpawners, table.concat(counts, ", "), unknown))
    outputServerLog(("[wildlifetest] %d files listed, %d missing%s"):format(files, #missing, #missing > 0 and (": " .. table.concat(missing, ", "):sub(1, 300)) or ""))
    local on = {}
    for id in pairs(allowed) do on[#on + 1] = id end
    table.sort(on)
    outputServerLog(("[wildlifetest] spawning: %s; %d alive; caps %d per player, %d total, density %.2f, aggro %.0f%% every %.1f s within %d m")
        :format(table.concat(on, ", "), count, CONFIG.maxPerPlayer, CONFIG.maxTotal, CONFIG.density, CONFIG.aggroChance * 100,
            CONFIG.aggroCheckMs / 1000, CONFIG.aggroRange))
    outputServerLog("[wildlifetest] " .. (ok and "PASS" or "FAIL"))
end)
