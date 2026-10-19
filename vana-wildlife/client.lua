-- Bigfoot on this client: his model (the mod's DFF and TXD on a model of our own, shown on the
-- server's ped), the walk and attack orders while we simulate him, and his toughness.
local B = Wildlife.bigfoot
local model

local function dress(ped)
    if model and getElementData(ped, "vana:creature") == "bigfoot" and getElementModel(ped) ~= model then setElementModel(ped, model) end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    model = engineRequestModel("ped", B.baseModel)
    if not model then return outputDebugString("[vana-wildlife] no free ped model for Bigfoot", 1) end
    local txd = engineLoadTXD("mods/bigfoot/bigfoot.txd")
    if txd then engineImportTXD(txd, model) end
    local dff = engineLoadDFF("mods/bigfoot/bigfoot.dff")
    if dff then engineReplaceModel(dff, model) end
    for _, ped in ipairs(getElementsByType("ped")) do dress(ped) end
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

addEvent("vana-wildlife:walk", true)
addEventHandler("vana-wildlife:walk", resourceRoot, function(ped, x, y, z)
    order(ped, function()
        setPedTaskSequence(ped, { { task = "go_to", x = x, y = y, z = z, movement = "walk", radius = 2, slowdownRadius = 2 } })
    end)
end)

addEvent("vana-wildlife:attack", true)
addEventHandler("vana-wildlife:attack", resourceRoot, function(ped, target)
    order(ped, function() setPedKillOnFoot(ped, target) end)
end)

-- He takes 1000 health of punishment (the mod's), on MTA's 100-health peds: damage is scaled down
-- where he's simulated. Our own hits are reported so he turns on us.
addEventHandler("onClientPedDamage", root, function(attacker, _, _, loss)
    if getElementData(source, "vana:creature") ~= "bigfoot" then return end
    if attacker == localPlayer then triggerServerEvent("vana-wildlife:hurt", resourceRoot, source) end
    cancelEvent()
    if isElementSyncer(source) and loss then
        local health = getElementHealth(source) - loss * 100 / B.health
        if health <= 0 then killPed(source, attacker) else setElementHealth(source, health) end
    end
end)
