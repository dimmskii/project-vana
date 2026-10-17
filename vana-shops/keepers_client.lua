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
