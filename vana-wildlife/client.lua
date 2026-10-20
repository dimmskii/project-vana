-- Wildlife on this client: each species' look (a model of our own per variant, the pack's DFF and
-- TXD, loaded the first time one shows), its walk (its own walkcycle in place of GTA's, on each of its
-- peds), its sounds, the orders for the animals we simulate, and how hard they are to kill.
local models = {} -- "species|variant" -> model id, or false
local blocks = {} -- IFP path -> its animation block, or false
local blockCount = 0

local function animalOf(e)
    local key = getElementData(e, "vana:animal")
    if type(key) ~= "string" then return end
    local species, variant = key:match("^([%w_]+)|(%d+)$")
    local kind = species and WildlifeKinds[species]
    if kind then return species, kind, tonumber(variant), key end
end

local function modelFor(key, species, variant, driver)
    if models[key] ~= nil then return models[key] end
    local v = WildlifeSpecies[species] and WildlifeSpecies[species].variants[variant]
    local id = v and engineRequestModel(driver, driver == "ped" and 7 or 1337)
    if id then
        local txd = engineLoadTXD(v[2])
        if txd then engineImportTXD(txd, id) end
        local dff = engineLoadDFF(v[1])
        if dff then engineReplaceModel(dff, id) end
    elseif v then
        outputDebugString("[vana-wildlife] no free model for " .. key, 2)
    end
    models[key] = id or false
    return models[key]
end

local function blockFor(path)
    if blocks[path] ~= nil then return blocks[path] end
    blockCount = blockCount + 1
    local name = "vana_wildlife_" .. blockCount
    blocks[path] = engineLoadIFP(path, name) and name or false
    if not blocks[path] then outputDebugString("[vana-wildlife] can't load " .. path, 2) end
    return blocks[path]
end

-- Put down on the ground where we simulate it: the server only knows its spot's height, and the pack
-- scatters animals up to 100 m round it (under a hill they'd fall through the world). Held still until
-- the collision there has loaded.
local placed = {} -- ped -> true
local function place(ped, tries)
    if not isElement(ped) or placed[ped] then return end
    if not (isElementStreamedIn(ped) and isElementSyncer(ped)) then
        if tries < 40 then setTimer(place, 250, 1, ped, tries + 1) end
        return
    end
    local x, y, z = getElementPosition(ped)
    local gz = getGroundPosition(x, y, z + 40)
    if (not gz or gz == 0) and tries < 40 then
        setElementFrozen(ped, true)
        return setTimer(place, 250, 1, ped, tries + 1)
    end
    placed[ped] = true
    if gz and gz ~= 0 and math.abs(gz - z) > 1.2 then setElementPosition(ped, x, y, gz + 1) end
    setElementFrozen(ped, false)
end

local function dress(e)
    local species, kind, variant, key = animalOf(e)
    if not species then return end
    local id = modelFor(key, species, variant, kind.driver)
    if id and getElementModel(e) ~= id then setElementModel(e, id) end
    if kind.driver ~= "ped" then return end
    setPedVoice(e, "PED_TYPE_DISABLED") -- no human pain cries or chatter (its own sounds are ours)
    place(e, 0)
    if not kind.walk then return end
    local block = blockFor(kind.walk.ifp)
    if not block then return end
    for gta, suffix in pairs(WildlifeWalkcycle) do engineReplaceAnimation(e, "ped", gta, block, kind.walk.prefix .. "_" .. suffix) end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    for _, t in ipairs({ "ped", "object" }) do
        for _, e in ipairs(getElementsByType(t, root, true)) do dress(e) end
    end
    triggerServerEvent("vana-wildlife:ready", resourceRoot)
end)
addEventHandler("onClientElementStreamIn", root, function() dress(source) end)
addEventHandler("onClientElementDataChange", root, function(key) if key == "vana:animal" then dress(source) end end)

-- Orders for the animals we simulate (the server's brain): idle, walk, flee, attack. Given once the
-- ped is streamed in and ours; an attack is a chase and a bite, re-aimed while it lasts (the pack has
-- no attack animations, and GTA's fist fight would be a bear throwing punches).
local orders = {} -- ped -> { mode, x, y, z, target, given, biteAt }
local BITE_RANGE, BITE_MS = 2.0, 1400

local function goTo(ped, x, y, z, movement)
    if isPedDoingTask(ped, "TASK_COMPLEX_USE_SEQUENCE") then killPedTask(ped, "primary", 3, false) end
    return setPedTaskSequence(ped, { { task = "go_to", x = x, y = y, z = z, movement = movement, radius = 1.5, slowdownRadius = 1.5 } })
end

local function run(ped, o, now)
    if o.mode == "idle" then
        if isPedDoingTask(ped, "TASK_COMPLEX_USE_SEQUENCE") then killPedTask(ped, "primary", 3, false) end
        return true
    elseif o.mode == "walk" or o.mode == "flee" then
        return goTo(ped, o.x, o.y, o.z, o.mode == "flee" and "run" or "walk")
    elseif o.mode == "attack" then
        local t = o.target
        if not isElement(t) or isPedDead(t) then return true end
        local px, py, pz = getElementPosition(ped)
        local tx, ty, tz = getElementPosition(t)
        if getDistanceBetweenPoints3D(px, py, pz, tx, ty, tz) <= BITE_RANGE then
            if isPedDoingTask(ped, "TASK_COMPLEX_USE_SEQUENCE") then killPedTask(ped, "primary", 3, false) end
            setElementRotation(ped, 0, 0, -math.deg(math.atan2(tx - px, ty - py)), "default", true)
            if now >= (o.biteAt or 0) then
                o.biteAt = now + BITE_MS
                triggerServerEvent("vana-wildlife:bite", resourceRoot, ped, t)
            end
            return true
        end
        return goTo(ped, tx, ty, tz, "run")
    end
    return true
end

addEvent("vana-wildlife:order", true)
addEventHandler("vana-wildlife:order", resourceRoot, function(ped, mode, x, y, z, target)
    if not isElement(ped) then return end
    orders[ped] = { mode = mode, x = x, y = y, z = z, target = target, since = getTickCount() }
end)

setTimer(function()
    local now = getTickCount()
    for ped, o in pairs(orders) do
        if not isElement(ped) or isPedDead(ped) or (not o.given and now - o.since > 10000) then
            orders[ped] = nil
        elseif isElementStreamedIn(ped) and isElementSyncer(ped) then
            -- The attack is re-aimed each round; the rest once (a refused one tried again).
            if o.mode == "attack" or not o.given then
                local ok = run(ped, o, now)
                o.given = o.given or ok
                if Debug.on("brains") and not ok then Debug.log("brains", ("refused %s for %s"):format(o.mode, tostring(getElementData(ped, "vana:animal")))) end
            end
        end
    end
end, 300, 0)

-- Sounds: now and then a call from each animal streamed in near us; a cry when hurt.
local nextCall, nextCry = {}, {}

local function play(e, list, maxDistance)
    if not list or #list == 0 then return end
    local x, y, z = getElementPosition(e)
    local sound = playSound3D(list[math.random(#list)], x, y, z)
    if not sound then return end
    setSoundMaxDistance(sound, maxDistance)
    setElementDimension(sound, getElementDimension(e))
    setElementInterior(sound, getElementInterior(e))
    attachElements(sound, e)
end

setTimer(function()
    local now = getTickCount()
    local mx, my, mz = getElementPosition(localPlayer)
    for _, t in ipairs({ "ped", "object" }) do
        for _, e in ipairs(getElementsByType(t, root, true)) do
            local species = animalOf(e)
            if species and not (t == "ped" and isPedDead(e)) then
                local x, y, z = getElementPosition(e)
                if not nextCall[e] then
                    nextCall[e] = now + math.random(2000, 20000)
                elseif now >= nextCall[e] then
                    nextCall[e] = now + math.random(12000, 40000)
                    if getDistanceBetweenPoints3D(x, y, z, mx, my, mz) < 70 then play(e, WildlifeSpecies[species].sounds.random, 60) end
                end
            end
        end
    end
    for e in pairs(nextCall) do if not isElement(e) or not isElementStreamedIn(e) then nextCall[e], nextCry[e] = nil, nil end end
end, 1000, 0)

-- Their health is the spawner's (the pack's: a hare 60, a bear 650) on MTA's 100-health peds: damage is
-- scaled where it's simulated, as Bigfoot's. Our own hits are reported so the brain reacts.
local reported = {}
addEventHandler("onClientPedDamage", root, function(attacker, _, _, loss)
    local species = animalOf(source)
    if not species then return end
    cancelEvent()
    local now = getTickCount()
    if attacker == localPlayer and now >= (reported[source] or 0) then
        reported[source] = now + 1000
        triggerServerEvent("vana-wildlife:hurt", resourceRoot, source)
    end
    if now >= (nextCry[source] or 0) then
        nextCry[source] = now + 1500
        play(source, WildlifeSpecies[species].sounds.damage, 50)
    end
    if isElementSyncer(source) and loss then
        local toughness = tonumber(getElementData(source, "vana:animalHealth")) or 100
        local health = getElementHealth(source) - loss * 100 / math.max(1, toughness)
        -- A server ped is killed by the server (killPed here only works on our own peds).
        if health <= 0 then triggerServerEvent("vana-wildlife:killed", resourceRoot, source, attacker) else setElementHealth(source, health) end
    end
end)
addEventHandler("onClientElementDestroy", root, function() orders[source], reported[source], placed[source] = nil, nil, nil end)
