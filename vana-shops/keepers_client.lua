-- What shopkeepers hold (their "vana:holding" model: a weapon, a meal on its tray), kept in the right
-- hand each frame as vanilla's task_pick_up_object does. Local objects only.
local held = {} -- ped -> object
local HAND = 25 -- right hand bone

local function update(ped)
    local model = isElement(ped) and getElementData(ped, "vana:holding")
    local object = held[ped]
    if object and (not model or getElementModel(object) ~= model) then
        destroyElement(object)
        held[ped], object = nil, nil
    end
    if model and not object then
        object = createObject(model, getElementPosition(ped))
        if object then
            setElementInterior(object, getElementInterior(ped))
            setElementCollisionsEnabled(object, false)
            held[ped] = object
        end
    end
end

addEventHandler("onClientElementDataChange", root, function(key)
    if key == "vana:holding" and getElementType(source) == "ped" then update(source) end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    for _, ped in ipairs(getElementsByType("ped")) do
        if getElementData(ped, "vana:holding") then update(ped) end
    end
end)

addEventHandler("onClientElementDestroy", root, function()
    if held[source] then destroyElement(held[source]); held[source] = nil end
end)

addEventHandler("onClientPedsProcessed", root, function()
    for ped, object in pairs(held) do
        local b = isElement(ped) and isElementStreamedIn(ped) and getElementBoneMatrix(ped, HAND)
        if b then setElementMatrix(object, b) end
    end
end)

-- A customer being sick at a fast food counter (keepers.lua): vanilla's PUKE effect at their mouth.
addEvent("vana-shops:puke", true)
addEventHandler("vana-shops:puke", resourceRoot, function(player, x, y, z)
    if not isElement(player) or not isElementStreamedIn(player) then return end
    local _, _, rz = getElementRotation(player)
    local h = math.rad(rz)
    local fx = createEffect("puke", x - math.sin(h) * 0.35, y + math.cos(h) * 0.35, z + 0.6, -90, 0, rz)
    if fx then setTimer(function() if isElement(fx) then destroyElement(fx) end end, 4000, 1) end
end)

-- Robbing a shop: aiming a gun at the keeper, shooting in the shop, or hurting the keeper tells the
-- server (keepers.lua decides). Aiming is reported twice a second while it lasts.
local function keeperNear()
    local x, y, z = getElementPosition(localPlayer)
    for _, ped in ipairs(getElementsByType("ped", root, true)) do
        if getElementData(ped, "vana:keeper") and getElementInterior(ped) == getElementInterior(localPlayer) then
            local px, py, pz = getElementPosition(ped)
            if getDistanceBetweenPoints3D(x, y, z, px, py, pz) < 25 then return ped end
        end
    end
end

setTimer(function()
    local slot = getPedWeaponSlot(localPlayer)
    if slot < 2 or slot > 7 or not getPedControlState(localPlayer, "aim_weapon") then return end
    local target = getPedTarget(localPlayer)
    if isElement(target) and getElementType(target) == "ped" and getElementData(target, "vana:keeper") and not isPedDead(target) then
        triggerServerEvent("vana-shops:threat", resourceRoot, target, "aim")
    end
end, 500, 0)

local lastShot = 0
addEventHandler("onClientPlayerWeaponFire", localPlayer, function(weapon)
    if weapon < 22 or getElementInterior(localPlayer) == 0 or getTickCount() - lastShot < 1000 then return end
    local keeper = keeperNear()
    if keeper then
        lastShot = getTickCount()
        triggerServerEvent("vana-shops:threat", resourceRoot, keeper, "shot")
    end
end)

addEventHandler("onClientPedDamage", root, function(attacker)
    if attacker == localPlayer and getElementData(source, "vana:keeper") then
        triggerServerEvent("vana-shops:threat", resourceRoot, source, "hurt")
    end
end)

-- The Ammu-Nation clerk fights back (vanilla AMUNAT): from behind the counter, run by our client.
addEvent("vana-shops:keeperAttack", true)
addEventHandler("vana-shops:keeperAttack", resourceRoot, function(ped, target)
    local tries = 0
    local function go()
        tries = tries + 1
        if not isElement(ped) or isPedDead(ped) or not isElement(target) then return end
        if not (isElementStreamedIn(ped) and isElementSyncer(ped)) then
            if tries < 30 then setTimer(go, 200, 1) end
            return
        end
        setPedStayInSamePlace(ped, true)
        setPedKillOnFoot(ped, target)
    end
    go()
end)
