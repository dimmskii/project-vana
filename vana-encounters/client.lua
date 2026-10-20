-- Encounters on this client: each kind's model (its DFF and TXD on a ped model of our own, shown on
-- the server's peds of that kind), the walk and attack orders for the ones we simulate, and their
-- toughness, with the damage we do reported for the reward.
local models = {} -- kind -> model id, or false

local function modelOf(kindName)
    if models[kindName] ~= nil then return models[kindName] end
    local kind = EncounterKinds[kindName]
    local id = kind and kind.dff and engineRequestModel("ped", kind.model or 7)
    if id then
        local txd = engineLoadTXD(kind.txd)
        if txd then engineImportTXD(txd, id) end
        local dff = engineLoadDFF(kind.dff)
        if dff then engineReplaceModel(dff, id) end
    elseif kind and kind.dff then
        outputDebugString("[vana-encounters] no free ped model for " .. kindName, 1)
    end
    models[kindName] = id or false
    return models[kindName]
end

local function dress(ped)
    local kind = getElementData(ped, "vana:creature")
    local id = type(kind) == "string" and modelOf(kind)
    if id and getElementModel(ped) ~= id then setElementModel(ped, id) end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    for _, ped in ipairs(getElementsByType("ped", root, true)) do dress(ped) end
end)

addEventHandler("onClientElementStreamIn", root, function()
    if getElementType(source) == "ped" then dress(source) end
end)

addEventHandler("onClientElementDataChange", root, function(key)
    if key == "vana:creature" and getElementType(source) == "ped" then dress(source) end
end)

-- Orders for a ped we simulate; retried until ownership and streaming arrive.
local function order(ped, fn)
    local tries = 0
    local function go()
        tries = tries + 1
        if not isElement(ped) or isPedDead(ped) then return end
        if not (isElementStreamedIn(ped) and isElementSyncer(ped)) then
            if tries < 50 then setTimer(go, 200, 1) end
            return
        end
        fn()
    end
    go()
end

addEvent("vana-encounters:walk", true)
addEventHandler("vana-encounters:walk", resourceRoot, function(ped, x, y, z)
    order(ped, function()
        setPedTaskSequence(ped, { { task = "go_to", x = x, y = y, z = z, movement = "walk", radius = 2, slowdownRadius = 2 } })
    end)
end)

addEvent("vana-encounters:attack", true)
addEventHandler("vana-encounters:attack", resourceRoot, function(ped, target)
    order(ped, function() setPedKillOnFoot(ped, target) end)
end)

-- Their health is in GTA's units (Bigfoot 1000) on MTA's 100-health peds: damage is scaled down where
-- they're simulated. Our own hits are reported (in their units) for the reward, and so they turn on us.
addEventHandler("onClientPedDamage", root, function(attacker, _, _, loss)
    if not getElementData(source, "vana:encounter") then return end
    cancelEvent()
    if attacker == localPlayer and loss then triggerServerEvent("vana-encounters:hurt", resourceRoot, source, loss) end
    if isElementSyncer(source) and loss then
        local toughness = tonumber(getElementData(source, "vana:creatureHealth")) or 100
        local health = getElementHealth(source) - loss * 100 / math.max(1, toughness)
        -- A server ped is killed by the server (killPed here only works on our own peds).
        if health <= 0 then triggerServerEvent("vana-encounters:killed", resourceRoot, source, attacker) else setElementHealth(source, health) end
    end
end)
