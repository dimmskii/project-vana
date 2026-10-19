-- Fuel, after the gasoline.cs CLEO mod: player-driven cars burn fuel by speed and stall when empty;
-- pumps at the gas stations refill them for money. The tank level lives in "vana:fuel" (units).
local F = VehicleConfig.fuel
local refuelling = {} -- player -> { vehicle, timer, steps }

local function usesFuel(vehicle)
    return F.enabled and F.types[getVehicleType(vehicle)] == true
end

-- A car's tank, first filled when a player first drives it.
local function fuelOf(vehicle)
    local fuel = getElementData(vehicle, "vana:fuel")
    if not fuel then
        fuel = math.floor(F.tank * (F.start[1] + math.random() * (F.start[2] - F.start[1])))
        setElementData(vehicle, "vana:fuel", fuel)
    end
    return fuel
end

local function setFuel(vehicle, fuel)
    fuel = math.max(0, math.min(F.tank, math.floor(fuel)))
    if getElementData(vehicle, "vana:fuel") ~= fuel then setElementData(vehicle, "vana:fuel", fuel) end
    if fuel <= 0 and getVehicleEngineState(vehicle) then setVehicleEngineState(vehicle, false) end
    return fuel
end

function getVehicleFuel(vehicle)
    return isElement(vehicle) and usesFuel(vehicle) and fuelOf(vehicle) or false
end

function setVehicleFuel(vehicle, fuel)
    if not isElement(vehicle) or not usesFuel(vehicle) or type(fuel) ~= "number" then return false end
    setFuel(vehicle, fuel)
    return true
end

-- Units per second at a speed (m/s): the mod's per-frame bands at its frame rate.
function fuelRate(speed, inAir)
    if speed <= 0 then return 0 end
    if inAir then return F.inAir * F.fps end
    for _, band in ipairs(F.bands) do
        if speed > band[1] and speed < band[2] then return band[3] * F.fps end
    end
    return 0
end

local function burnPerSecond(vehicle)
    local vx, vy, vz = getElementVelocity(vehicle)
    return fuelRate(math.sqrt(vx * vx + vy * vy + vz * vz) * 50, not isVehicleOnGround(vehicle))
end

local function nearPump(vehicle)
    local x, y, z = getElementPosition(vehicle)
    for _, p in ipairs(F.pumps) do
        if getDistanceBetweenPoints2D(x, y, p[1], p[2]) < F.pumpRadius and math.abs(z - p[3]) < F.pumpHeight then return p end
    end
end

local function stopRefuel(player, text)
    local r = refuelling[player]
    if not r then return end
    refuelling[player] = nil
    if isTimer(r.timer) then killTimer(r.timer) end
    if isElement(r.vehicle) then
        setElementFrozen(r.vehicle, false)
        setVehicleLocked(r.vehicle, r.wasLocked)
    end
    if isElement(player) then
        toggleAllControls(player, true, true, false)
        if isElement(r.vehicle) and (getElementData(r.vehicle, "vana:fuel") or 0) > 0 then setVehicleEngineState(r.vehicle, true) end
        triggerClientEvent(player, "vana-vehicles:refuel", resourceRoot, false, r.steps * F.stepPrice, text)
    end
end

-- As the mod: the car is held at the pump, filled step by step, and paid for at the end.
local function startRefuel(player, vehicle)
    if getPlayerMoney(player) <= 0 then
        triggerClientEvent(player, "vana-vehicles:refuel", resourceRoot, false, 0, "You don't have any money.")
        refuelling[player] = { vehicle = vehicle, done = true }
        return
    end
    local r = { vehicle = vehicle, steps = 0, wasLocked = isVehicleLocked(vehicle) }
    refuelling[player] = r
    setElementVelocity(vehicle, 0, 0, 0)
    setElementFrozen(vehicle, true)
    setVehicleLocked(vehicle, true)
    toggleAllControls(player, false, true, false)
    triggerClientEvent(player, "vana-vehicles:refuel", resourceRoot, true)
    r.timer = setTimer(function()
        if not isElement(player) or not isElement(vehicle) or getPedOccupiedVehicle(player) ~= vehicle then
            return stopRefuel(player)
        end
        if getPlayerMoney(player) - (r.steps + 1) * F.stepPrice < 0 then
            takePlayerMoney(player, r.steps * F.stepPrice)
            return stopRefuel(player, "You can't afford any more fuel.")
        end
        r.steps = r.steps + 1
        local fuel = setFuel(vehicle, fuelOf(vehicle) + F.step)
        if fuel >= F.refillTo then
            takePlayerMoney(player, r.steps * F.stepPrice)
            stopRefuel(player)
        end
    end, F.stepMs, 0)
end

setTimer(function()
    if not F.enabled then return end
    for _, player in ipairs(getElementsByType("player")) do
        local vehicle = getPedOccupiedVehicle(player)
        local r = refuelling[player]
        if r and r.done and (vehicle ~= r.vehicle or not nearPump(vehicle)) then refuelling[player], r = nil, nil end
        if vehicle and getVehicleOccupant(vehicle, 0) == player and usesFuel(vehicle) and not r then
            local fuel = fuelOf(vehicle)
            if getVehicleEngineState(vehicle) then fuel = setFuel(vehicle, fuel - burnPerSecond(vehicle)) end
            if fuel <= 0 and getVehicleEngineState(vehicle) then setVehicleEngineState(vehicle, false) end
            local vx, vy, vz = getElementVelocity(vehicle)
            local slow = (vx * vx + vy * vy + vz * vz) * 2500 < F.pumpSpeed * F.pumpSpeed
            if fuel < F.refillBelow and slow and nearPump(vehicle) then startRefuel(player, vehicle) end
        end
    end
end, 1000, 0)

-- An empty car won't start: MTA starts the engine for a driver getting in.
addEventHandler("onVehicleEnter", root, function(player, seat)
    if seat ~= 0 or not usesFuel(source) then return end
    local vehicle = source
    if fuelOf(vehicle) <= 0 then
        setTimer(function()
            if isElement(vehicle) and (getElementData(vehicle, "vana:fuel") or 0) <= 0 then setVehicleEngineState(vehicle, false) end
        end, 200, 1)
    end
end)

-- The pumps' markers: where to roll up to (the icon in them is pumps_client.lua's); and each on the map
-- (vana-map's gas station category: our icon, short range on the radar).
addEventHandler("onResourceStart", resourceRoot, function()
    if not F.enabled then return end
    local m = F.pumpMarker
    for i, p in ipairs(F.pumps) do
        createMarker(p[1], p[2], p[3] - 0.6, "cylinder", m.size, m.colour[1], m.colour[2], m.colour[3], m.colour[4])
        MapPoints.set("gasstation:" .. i, { category = "gasstation", x = p[1], y = p[2], z = p[3] })
    end
end)

addEventHandler("onPlayerQuit", root, function() stopRefuel(source) end)
addEventHandler("onPlayerWasted", root, function() stopRefuel(source) end)
