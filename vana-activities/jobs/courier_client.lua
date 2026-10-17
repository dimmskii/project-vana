-- Courier, the rider's side: hold look left / right and press fire to throw an item off the bike; if
-- it passes through an active drop-off corona the server hears of it.
local drops, packet, bikeModel

addEvent("vana-courier:drops", true)
addEventHandler("vana-courier:drops", resourceRoot, function(list, model, bike)
    drops, packet, bikeModel = list, model, bike
end)

local function throw(side)
    local bike = getPedOccupiedVehicle(localPlayer)
    if not drops or not bike or getElementModel(bike) ~= bikeModel then return end
    local x, y, z = getElementPosition(bike)
    local _, _, rz = getElementRotation(bike)
    local h = math.rad(rz)
    local rx, ry = math.cos(h) * side, math.sin(h) * side -- the bike's right (side = 1) or left (-1)
    local item = createObject(packet, x + rx * 0.8, y + ry * 0.8, z + 0.8)
    if not item then return end
    setElementCollisionsEnabled(item, true)
    local vx, vy, vz = getElementVelocity(bike)
    setElementVelocity(item, vx + rx * 0.25, vy + ry * 0.25, vz + 0.12)
    local started, hit = getTickCount(), nil
    local t
    t = setTimer(function()
        if not isElement(item) then killTimer(t) return end
        local ix, iy, iz = getElementPosition(item)
        for i, p in ipairs(drops or {}) do
            if getDistanceBetweenPoints3D(ix, iy, iz, p[1], p[2], p[3] + 1.5) < Jobs.courier.dropRadius then hit = i end
        end
        if hit or getTickCount() - started > 2500 then
            killTimer(t)
            triggerServerEvent("vana-courier:thrown", resourceRoot, hit)
            setTimer(function() if isElement(item) then destroyElement(item) end end, 3000, 1)
        end
    end, 50, 0)
end

bindKey("vehicle_fire", "down", function()
    if not drops then return end
    if getPedControlState(localPlayer, "vehicle_look_left") then throw(-1)
    elseif getPedControlState(localPlayer, "vehicle_look_right") then throw(1) end
end)
