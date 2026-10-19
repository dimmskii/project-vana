-- Pay 'n' Spray (config/sprays.lua): stop a damaged vehicle inside one and it's fixed for $100, as in
-- vanilla's garage (door down, the respray sound, door up), only without the new colour and the
-- wanted level. The doors stay up otherwise; the repair is the server's (fixVehicle), so every client
-- gets the same car.
local S = SprayConfig
local busy = {}    -- garage index -> player inside
local cleared = {} -- player -> garage they've just been served in (not again until they leave it)

-- Damage the repair fixes: lost health, or any panel, door, light or tyre not as new. (Door states
-- 0-1 are shut or open, intact; 2+ damaged or gone.)
function isVehicleDamaged(vehicle)
    if getElementHealth(vehicle) < 999 or isVehicleBlown(vehicle) then return true end
    for i = 0, 6 do if getVehiclePanelState(vehicle, i) ~= 0 then return true end end
    for i = 0, 5 do if getVehicleDoorState(vehicle, i) >= 2 then return true end end
    for i = 0, 3 do if getVehicleLightState(vehicle, i) ~= 0 then return true end end
    for _, w in ipairs({ getVehicleWheelStates(vehicle) }) do if w ~= 0 then return true end end
    return false
end

-- Inside a garage's box (the grge corner and sides, up to its roof).
local function inside(g, x, y, z)
    local dx, dy = x - g.corner[1], y - g.corner[2]
    local function along(v) return (dx * v[1] + dy * v[2]) / (v[1] * v[1] + v[2] * v[2]) end
    local u, w = along(g.a), along(g.b)
    return u >= 0 and u <= 1 and w >= 0 and w <= 1 and z >= g.corner[3] - 1 and z <= g.top
end

local function tell(player, text, sound)
    triggerClientEvent(player, "vana-spray:tell", resourceRoot, text, sound)
end

local function serve(player, vehicle, index)
    local g = S.garages[index]
    cleared[player] = index
    if not isVehicleDamaged(vehicle) then return tell(player, S.nothingText) end
    if getPlayerMoney(player) < S.price then
        -- Vanilla's "No more freebies / $100 to respray!" and its no-cash sound.
        return tell(player, Gxt.get("GA_3") or ("$" .. S.price .. " to repair!"), 14)
    end
    busy[index] = player
    setElementFrozen(vehicle, true)
    setGarageOpen(g.door, false)
    setTimer(function()
        if isElement(player) then tell(player, nil, 16) end -- the respray sound
        setTimer(function()
            busy[index] = nil
            if isElement(vehicle) then
                if isElement(player) and getPedOccupiedVehicle(player) == vehicle and getPlayerMoney(player) >= S.price then
                    fixVehicle(vehicle)
                    takePlayerMoney(player, S.price)
                    tell(player, S.repairedText:format(S.price))
                end
                setElementFrozen(vehicle, false)
            end
            setGarageOpen(g.door, true)
        end, S.sprayMs, 1)
    end, S.closeMs, 1)
end

setTimer(function()
    for _, player in ipairs(getElementsByType("player")) do
        local v = getPedOccupiedVehicle(player)
        local at
        if v and getVehicleOccupant(v, 0) == player and getElementDimension(v) == 0 and getElementInterior(v) == 0 then
            local x, y, z = getElementPosition(v)
            for i, g in ipairs(S.garages) do if inside(g, x, y, z) then at = i end end
            if cleared[player] and cleared[player] ~= at then cleared[player] = nil end
            local vt = getVehicleType(v)
            if at and not cleared[player] and not busy[at] and vt ~= "Boat" and vt ~= "Plane" and vt ~= "Helicopter" and vt ~= "Train" then
                local vx, vy, vz = getElementVelocity(v)
                if (vx * vx + vy * vy + vz * vz) ^ 0.5 < S.stoppedSpeed then serve(player, v, at) end
            end
        elseif cleared[player] and not v then
            cleared[player] = nil
        end
    end
end, 250, 0)

addEventHandler("onPlayerQuit", root, function() cleared[source] = nil end)

-- Stopping mid-spray: doors up, cars free.
addEventHandler("onResourceStop", resourceRoot, function()
    for index, player in pairs(busy) do
        local v = isElement(player) and getPedOccupiedVehicle(player)
        if v then setElementFrozen(v, false) end
        setGarageOpen(S.garages[index].door, true)
    end
end)

addEventHandler("onResourceStart", resourceRoot, function()
    for i, g in ipairs(S.garages) do
        setGarageOpen(g.door, true)
        local cx = g.corner[1] + (g.a[1] + g.b[1]) / 2
        local cy = g.corner[2] + (g.a[2] + g.b[2]) / 2
        MapPoints.set("spray:" .. i, { category = "spray", x = cx, y = cy, z = g.corner[3] })
    end
end)

-- Console-only: every spray's box holds its own centre, and a dented car counts as damaged until fixed.
addCommandHandler("spraytest", function(source)
    if getElementType(source) ~= "console" then return end
    local ok = true
    for _, g in ipairs(S.garages) do
        local cx = g.corner[1] + (g.a[1] + g.b[1]) / 2
        local cy = g.corner[2] + (g.a[2] + g.b[2]) / 2
        ok = ok and inside(g, cx, cy, g.corner[3] + 1) and not inside(g, cx + 30, cy, g.corner[3] + 1)
    end
    local v = createVehicle(411, 0, 0, -60)
    local clean = not isVehicleDamaged(v)
    setVehiclePanelState(v, 0, 2)
    local dented = isVehicleDamaged(v)
    fixVehicle(v)
    local fixed = not isVehicleDamaged(v)
    destroyElement(v)
    ok = ok and clean and dented and fixed
    outputServerLog(("[spraytest] %d garages; %s"):format(#S.garages, ok and "PASS" or "FAIL"))
end)
