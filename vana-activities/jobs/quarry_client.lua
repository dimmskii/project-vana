-- Quarry, the player's side: pushed rocks and barrels only move here, so this client tells the server
-- which reached their marker (or got clear of where they were). Also the fire on the quarry floor and
-- the thieves' getaway.
local watching, fire

addEvent("vana-quarry:watch", true)
addEventHandler("vana-quarry:watch", resourceRoot, function(list)
    watching = list
    if list then
        for _, w in ipairs(list) do
            if isElement(w.object) then setElementFrozen(w.object, false) end
        end
    end
end)

setTimer(function()
    if not watching then return end
    for i, w in ipairs(watching) do
        if not w.done and isElement(w.object) then
            local x, y, z = getElementPosition(w.object)
            local hit
            if w.target then
                hit = getDistanceBetweenPoints3D(x, y, z, w.target[1], w.target[2], w.target[3]) < w.radius
            elseif w.away then
                hit = getDistanceBetweenPoints2D(x, y, w.away[1], w.away[2]) > w.radius
            end
            if hit then
                w.done = true
                triggerServerEvent("vana-quarry:reached", resourceRoot, i)
            end
        end
    end
end, 500, 0)

addEvent("vana-quarry:fire", true)
addEventHandler("vana-quarry:fire", resourceRoot, function(p)
    if fire then extinguishFire(fire[1], fire[2], fire[3], 6) end
    fire = p
    if p then createFire(p[1], p[2], p[3], 3) end
end)

addEvent("vana-quarry:flee", true)
addEventHandler("vana-quarry:flee", resourceRoot, function(driver, vehicle)
    local tries = 0
    local t
    t = setTimer(function()
        tries = tries + 1
        if isElement(driver) and isElement(vehicle) and isElementStreamedIn(vehicle) then
            setPedDriveWander(driver, vehicle, 30, "avoid_cars")
            killTimer(t)
        elseif tries > 60 then
            killTimer(t)
        end
    end, 500, 0)
end)
