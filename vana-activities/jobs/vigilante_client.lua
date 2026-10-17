-- Vigilante, the criminals' side (this client simulates them): they drive off, and when the player
-- closes in while they're slow or wrecked they bail out and fight.
local crews

addEvent("vana-vigilante:crews", true)
addEventHandler("vana-vigilante:crews", resourceRoot, function(list) crews = list end)

local function speedOf(vehicle)
    local vx, vy, vz = getElementVelocity(vehicle)
    return math.sqrt(vx * vx + vy * vy + vz * vz) * 50
end

setTimer(function()
    if not crews then return end
    local x, y, z = getElementPosition(localPlayer)
    for _, crew in ipairs(crews) do
        local car = crew.car
        if isElement(car) and isElementStreamedIn(car) then
            local driver = getVehicleOccupant(car, 0)
            local cx, cy, cz = getElementPosition(car)
            local near = getDistanceBetweenPoints3D(x, y, z, cx, cy, cz) < Jobs.vigilante.bailRadius
            local cornered = near and (speedOf(car) < 3 or getElementHealth(car) < 400 or isVehicleOnGround(car) == false and speedOf(car) < 1)
            if cornered or isVehicleBlown(car) then
                for _, ped in ipairs(crew.peds) do
                    if isElement(ped) and not isPedDead(ped) and not crew.bailed then
                        if getPedOccupiedVehicle(ped) then setPedExitVehicle(ped) end
                    end
                end
                crew.bailed = crew.bailed or getTickCount()
            elseif driver and not crew.driving and not crew.bailed then
                crew.driving = setPedDriveWander(driver, car, 40, "avoid_cars")
            end
        end
        if crew.bailed and getTickCount() - crew.bailed > 1500 then
            for _, ped in ipairs(crew.peds) do
                if isElement(ped) and not isPedDead(ped) and not getPedOccupiedVehicle(ped) and isElementStreamedIn(ped) and not crew[ped] then
                    crew[ped] = setPedKillOnFoot(ped, localPlayer)
                end
            end
        end
    end
end, 500, 0)
