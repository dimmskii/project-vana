-- Burglary, the burglar's side: door arrows near you, going in and out, picking loot up (Neon's
-- native pickUpPedObject), loading it into the van, the noise meter (the engine's own noise level,
-- vanilla's formula) and finding free floor for loot in a house. The server decides everything.
local B = Burglary
local active = false
local van, texts
local inside    -- { house, interior, dimension, loot = { objects }, resident, arrivedAt, leftArrival }
local arrows = {} -- door index -> marker (local, only near the player)
local noise = 0
local lastEnter = 0
local loadZone = false

-- Picking loot up and loading it are offers to vana-controls' /use (F), which shows their prompts.
local ID = "vana-activities:burglary"
local offered
local function offer(text)
    if text == offered then return end
    offered = text
    local res = getResourceFromName("vana-controls")
    if not res or getResourceState(res) ~= "running" then return end
    if text then exports["vana-controls"]:offer(ID, text) else exports["vana-controls"]:withdraw(ID) end
end

local function tidyArrows()
    for i, m in pairs(arrows) do if isElement(m) then destroyElement(m) end arrows[i] = nil end
end

addEvent("vana-burglary:doors", true)
addEventHandler("vana-burglary:doors", resourceRoot, function(on, vehicle, strings)
    active = on
    if on then van, texts = vehicle, strings else tidyArrows() offer(nil) end
end)

addEvent("vana-burglary:objective", true)
addEventHandler("vana-burglary:objective", resourceRoot, function() end)

addEvent("vana-burglary:inside", true)
addEventHandler("vana-burglary:inside", resourceRoot, function(house, interior, dimension, _, loot, resident)
    local h = BurglaryHouses[house]
    local previous = inside
    inside = { house = house, interior = interior, dimension = dimension, loot = loot or {}, resident = resident,
               arrivedAt = previous and previous.house == house and previous.arrivedAt or getTickCount(),
               leftArrival = previous and previous.house == house and previous.leftArrival or false, hub = h }
    tidyArrows()
    noise = 0
    if resident then Hud.counter("noise", texts and texts.noise or "Noise", 0, "bar") end
end)

addEvent("vana-burglary:outside", true)
addEventHandler("vana-burglary:outside", resourceRoot, function()
    inside = nil
    Hud.counter("noise", nil)
end)

-- A resident who woke up reacts as BURG_BRAINS has them: men fight or give up, women cower or give
-- up, gang members fight. This client simulates them (the server pinned it as their syncer).
addEvent("vana-burglary:wake", true)
addEventHandler("vana-burglary:wake", resourceRoot, function(ped, kind)
    if not isElement(ped) then return end
    Hud.counter("noise", nil)
    if inside then inside.resident = nil end
    local fight = kind == "gang" or (kind == "male" and math.random() < 0.6)
    if fight then
        setPedKillOnFoot(ped, localPlayer)
    elseif kind == "female" and math.random() < 0.7 then
        setPedAnimation(ped, "ped", "cower", -1, true, false, false)
    else
        setPedAnimation(ped, "ped", "handsup", -1, false, false, false)
    end
end)

-- Free floor in the house for the loot (and a sleeper): downward rays on a grid around the arrival
-- point, keeping spots on this floor with a ceiling above and room around them.
local function floorAt(x, y, z)
    local hit, _, _, hz = processLineOfSight(x, y, z + 1.5, x, y, z - 1.6, true, false, false, true, false, true, false, false)
    if not hit or math.abs(hz - (z - 1)) > 0.6 then return nil end
    if not processLineOfSight(x, y, hz + 0.3, x, y, hz + 4, true, false, false, true, false, false, false, false) then return nil end
    for _, d in ipairs({ { 0.5, 0 }, { -0.5, 0 }, { 0, 0.5 }, { 0, -0.5 } }) do
        if processLineOfSight(x, y, hz + 0.4, x + d[1], y + d[2], hz + 0.4, true, false, false, true, false, false, false, false) then return nil end
    end
    return hz
end

local function baseOffset(model)
    local probe = createObject(model, 0, 0, -50)
    if not probe then return 0 end
    local _, _, minZ = getElementBoundingBox(probe)
    destroyElement(probe)
    return -(minZ or 0)
end

addEvent("vana-burglary:place", true)
addEventHandler("vana-burglary:place", resourceRoot, function(models, wantsResident)
    -- Give the interior's collision a moment to stream in.
    setTimer(function()
        if not inside then return end
        local h = inside.hub
        local x0, y0, z0 = h.ex, h.ey, h.ez + 1
        local candidates = {}
        for dx = -12, 12, 0.9 do
            for dy = -12, 12, 0.9 do
                local x, y = x0 + dx, y0 + dy
                if dx * dx + dy * dy > 6 then
                    local fz = floorAt(x, y, z0)
                    if fz then candidates[#candidates + 1] = { x, y, fz } end
                end
            end
        end
        -- Shuffle, then take spots at least 2 m apart.
        for i = #candidates, 2, -1 do
            local j = math.random(i)
            candidates[i], candidates[j] = candidates[j], candidates[i]
        end
        local chosen = {}
        for _, c in ipairs(candidates) do
            local free = true
            for _, o in ipairs(chosen) do
                if getDistanceBetweenPoints2D(c[1], c[2], o[1], o[2]) < 2 then free = false break end
            end
            if free then chosen[#chosen + 1] = c end
            if #chosen >= #models + 1 then break end
        end
        local spots = {}
        for i, model in ipairs(models) do
            local c = chosen[i]
            if c then spots[i] = { c[1], c[2], c[3] + baseOffset(model), math.random(0, 359) } end
        end
        local residentSpot = wantsResident and chosen[#models + 1] or nil
        triggerServerEvent("vana-burglary:spots", resourceRoot, spots, residentSpot)
    end, 1500, 1)
end)

local function carried()
    local object, state = getPedCarriedObject(localPlayer)
    return object or nil, state
end

local function nearestLoot()
    if not inside then return nil end
    local x, y, z = getElementPosition(localPlayer)
    local best, bestD
    for _, obj in ipairs(inside.loot) do
        if isElement(obj) then
            local ox, oy, oz = getElementPosition(obj)
            local d = getDistanceBetweenPoints3D(x, y, z, ox, oy, oz)
            if d < 1.7 and (not bestD or d < bestD) then best, bestD = obj, d end
        end
    end
    return best
end

local function vanBack()
    if not isElement(van) then return nil end
    local vx, vy = getElementPosition(van)
    local _, _, rz = getElementRotation(van)
    local h = math.rad(rz)
    return vx + math.sin(h) * B.vanBack, vy - math.cos(h) * B.vanBack
end

-- Doors, exits, help prompts.
setTimer(function()
    if not active then return end
    local x, y, z = getElementPosition(localPlayer)
    if inside then
        local h = inside.hub
        local d = getDistanceBetweenPoints3D(x, y, z, h.x, h.y, h.z + 1)
        if d > 2.5 then inside.leftArrival = true end
        if inside.leftArrival and d < 1.2 and getTickCount() - lastEnter > 2000 then
            lastEnter = getTickCount()
            triggerServerEvent("vana-burglary:leave", resourceRoot)
            return
        end
        offer(not carried() and nearestLoot() and texts and texts.pick or nil)
        return
    end
    -- Outside: arrows on doors within 120 m, entering when stepping into one.
    local near = {}
    for i, door in ipairs(BurglaryDoors) do
        local d = getDistanceBetweenPoints2D(x, y, door.x, door.y)
        if d < 120 and math.abs(z - door.z) < 30 then
            near[i] = true
            if not arrows[i] then
                arrows[i] = createMarker(door.x, door.y, door.z + 1.5, "arrow", 0.8, 255, 220, 0, 170)
            end
            if d < B.doorRadius and math.abs(z - (door.z + 1)) < 1.5 and not getPedOccupiedVehicle(localPlayer)
                and getTickCount() - lastEnter > 2000 then
                lastEnter = getTickCount()
                triggerServerEvent("vana-burglary:enter", resourceRoot, i)
            end
        end
    end
    for i, m in pairs(arrows) do
        if not near[i] then destroyElement(m) arrows[i] = nil end
    end
    -- Holding loot behind the van: /use loads it (and doesn't climb in).
    local obj = carried()
    local bx, by = vanBack()
    loadZone = obj and bx and getDistanceBetweenPoints2D(x, y, bx, by) < B.vanReach and not getPedOccupiedVehicle(localPlayer) or false
    offer(loadZone and texts and texts.load or nil)
end, 200, 0)

addEvent("onClientVanaUse", false)
addEventHandler("onClientVanaUse", root, function(id)
    if id ~= ID or not active then return end
    local obj, state = carried()
    if inside and not obj then
        local loot = nearestLoot()
        if loot and pickUpPedObject(localPlayer, loot) then
            triggerServerEvent("vana-burglary:carry", resourceRoot, loot)
            offer(nil)
        end
    elseif obj and loadZone and state == "holding" then
        cancelPedCarryObject(localPlayer)
        triggerServerEvent("vana-burglary:load", resourceRoot, obj)
        loadZone = false
        offer(nil)
    end
end)
addEvent("onClientVanaUseReset", false)
addEventHandler("onClientVanaUseReset", root, function()
    local text = offered
    offered = nil
    offer(text)
end)

-- Dropped (hit, interrupted): the item stays where it fell, still loot.
addEventHandler("onClientPedCarryStateChange", localPlayer, function(object, state)
    if active and state == "released" then triggerServerEvent("vana-burglary:carry", resourceRoot, nil) end
end)

-- Noise: vanilla adds (level * 1.6 - 20) each frame while someone is asleep here, decaying 1% a frame.
addEventHandler("onClientPreRender", root, function(dt)
    if not active or not inside or not inside.resident then return end
    local level = getPedNoiseLevel(localPlayer)
    local n = B.noise
    if level then
        local v = level * n.scale
        if v > n.floor then noise = noise + (v - n.floor) * dt / 33 end
    end
    noise = noise * n.decay ^ (dt / 33)
    local shown = math.min(100, math.floor(noise))
    Hud.counter("noise", texts and texts.noise or "Noise", shown, "bar")
    if shown >= 100 then
        inside.resident = nil
        triggerServerEvent("vana-burglary:noise", resourceRoot, 100)
    end
end)

addEvent("vana-activities:session", true)
addEventHandler("vana-activities:session", resourceRoot, function(name)
    if name ~= "burglary" and active then
        active, inside = false, nil
        tidyArrows()
        loadZone = false
        offer(nil)
    end
end)
