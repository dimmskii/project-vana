-- Parked car generators (CCarGenerator): cars appear at fixed spots out of players' sight, and
-- disappear again when nobody is near, unless a player has driven them.
local population = exports["vana-population"]

local CONFIG = {
    tick = 1000,
    genRadius = 160,        -- a generator works for players within this distance (vanilla 160)...
    minRadius = 120,        -- ...but only spawns when no player is closer than this (out of sight)
    maxHeight = 50,         -- and within this height difference (vanilla 50)
    despawn = 220,          -- untouched parked cars go once no player is this close
    abandoned = 300,        -- cars a player drove, once left empty with nobody this close...
    abandonedMs = 300000,   -- ...for this long
    limitDay = 5, limitNight = 10, -- parked cars around one player (vanilla CCarCtrl::NumParkedCars)
    defaultDelay = { 10000, 60000 },
    grid = 250,
}

local generators = {}
local grid = {}
local parked = {}       -- vehicle -> generator
local abandoned = {}    -- vehicle -> tick it was last occupied

local function cellOf(x, y) return math.floor(x / CONFIG.grid) .. ":" .. math.floor(y / CONFIG.grid) end

addEventHandler("onResourceStart", resourceRoot, function()
    for _, g in ipairs(CarGenerators) do
        if g.enabled then
            g.nextGen = 0
            generators[#generators + 1] = g
            local key = cellOf(g.x, g.y)
            grid[key] = grid[key] or {}
            table.insert(grid[key], g)
        end
    end
end)

local function nearbyGenerators(x, y)
    local list = {}
    local cx, cy = math.floor(x / CONFIG.grid), math.floor(y / CONFIG.grid)
    for gx = cx - 1, cx + 1 do
        for gy = cy - 1, cy + 1 do
            for _, g in ipairs(grid[gx .. ":" .. gy] or {}) do list[#list + 1] = g end
        end
    end
    return list
end

local function nextGenTime(g)
    local lo, hi = g.delay[1], g.delay[2]
    if lo < 0 or hi < lo then lo, hi = CONFIG.defaultDelay[1], CONFIG.defaultDelay[2] end
    return getTickCount() + math.random(lo, math.max(lo, hi))
end

local function parkedNear(x, y, z)
    local n = 0
    for vehicle in pairs(parked) do
        local vx, vy, vz = getElementPosition(vehicle)
        if getDistanceBetweenPoints3D(x, y, z, vx, vy, vz) < CONFIG.genRadius then n = n + 1 end
    end
    return n
end

-- Vanilla only generates out of sight: no player close, and the player not heading toward it.
local function canGenerate(g, players)
    local near = false
    for _, player in ipairs(players) do
        local px, py, pz = getElementPosition(player)
        local d = getDistanceBetweenPoints2D(px, py, g.x, g.y)
        if math.abs(pz - g.z) <= CONFIG.maxHeight and d < CONFIG.genRadius then
            if d < CONFIG.minRadius and not g.force then return false end
            local vx, vy = getElementVelocity(getPedOccupiedVehicle(player) or player)
            if vx * (g.x - px) + vy * (g.y - py) > 0 and not g.force then return false end
            near = true
        end
    end
    return near
end

local function generate(g)
    local model = g.model
    if model < 0 then
        -- Chosen once per generator, as vanilla remembers the model it picked.
        g.chosen = g.chosen or population:pickParkedCar(g.x, g.y, g.z)
        model = g.chosen
        if not model then return end
    end
    local vehicle = createVehicle(model, g.x, g.y, g.z + 0.5, 0, 0, g.heading)
    if not vehicle then return end
    local c1, c2 = g.colors[1], g.colors[2]
    if c1 >= 0 or c2 >= 0 then
        local r1, r2, r3, r4 = getVehicleColor(vehicle)
        setVehicleColor(vehicle, c1 >= 0 and c1 or r1, c2 >= 0 and c2 or r2, r3, r4)
    end
    if g.lock > 0 and math.random(100) <= g.lock then setVehicleLocked(vehicle, true) end
    setElementData(vehicle, "vana:parked", true)
    parked[vehicle] = g
    g.vehicle = vehicle
end

local function release(vehicle, g)
    parked[vehicle] = nil
    if g then g.vehicle, g.nextGen = nil, nextGenTime(g) end
end

local function eligiblePlayers()
    local list = {}
    for _, player in ipairs(getElementsByType("player")) do
        if getElementDimension(player) == 0 and getElementInterior(player) == 0 then list[#list + 1] = player end
    end
    return list
end

local function anyPlayerWithin(x, y, z, players, radius)
    for _, player in ipairs(players) do
        local px, py, pz = getElementPosition(player)
        if getDistanceBetweenPoints3D(x, y, z, px, py, pz) < radius then return true end
    end
    return false
end

setTimer(function()
    local players = eligiblePlayers()
    local now = getTickCount()
    local night = getTime() >= 21 or getTime() < 7

    -- Untouched parked cars go once nobody is near; a car someone drove stays like any other car.
    for vehicle, g in pairs(parked) do
        if not isElement(vehicle) then
            release(vehicle, g)
        else
            local x, y, z = getElementPosition(vehicle)
            if not anyPlayerWithin(x, y, z, players, CONFIG.despawn) then
                release(vehicle, g)
                destroyElement(vehicle)
            end
        end
    end
    for vehicle, since in pairs(abandoned) do
        if not isElement(vehicle) or getElementData(vehicle, "vana:kept") then
            -- Gone, or remembered by vana-vehicles (which keeps it from now on).
            abandoned[vehicle] = nil
        elseif next(getVehicleOccupants(vehicle) or {}) then
            abandoned[vehicle] = now
        else
            local x, y, z = getElementPosition(vehicle)
            if anyPlayerWithin(x, y, z, players, CONFIG.abandoned) then
                abandoned[vehicle] = now
            elseif now - since > CONFIG.abandonedMs then
                abandoned[vehicle] = nil
                destroyElement(vehicle)
            end
        end
    end

    for _, player in ipairs(players) do
        local px, py, pz = getElementPosition(player)
        local room = (night and CONFIG.limitNight or CONFIG.limitDay) - parkedNear(px, py, pz)
        for _, g in ipairs(nearbyGenerators(px, py)) do
            if not g.vehicle and now >= g.nextGen and (room > 0 or g.force or g.ignoreLimit) and canGenerate(g, players) then
                generate(g)
                if g.vehicle and not (g.force or g.ignoreLimit) then room = room - 1 end
            end
        end
    end
end, CONFIG.tick, 0)

-- A player taking a parked car makes it theirs: it is no longer the generator's to clean up.
addEventHandler("onVehicleEnter", root, function(player)
    local g = parked[source]
    if not g or getElementType(player) ~= "player" then return end
    release(source, g)
    removeElementData(source, "vana:parked")
    abandoned[source] = getTickCount()
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for vehicle in pairs(parked) do
        if isElement(vehicle) then destroyElement(vehicle) end
    end
end)

-- Console-only: checks the generator data and spawns/despawns a few generators directly.
addCommandHandler("parkedtest", function(source)
    if getElementType(source) ~= "console" then return end
    local ok = true
    local random, fixed, forced = 0, 0, 0
    for _, g in ipairs(generators) do
        if g.model < 0 then random = random + 1 else fixed = fixed + 1 end
        if g.force then forced = forced + 1 end
        if math.abs(g.x) > 3100 or math.abs(g.y) > 3100 then ok = false end
    end
    outputServerLog(("[parkedtest] %d generators enabled: %d fixed models, %d zone-picked, %d forced"):format(#generators, fixed, random, forced))

    -- Spawn the Grove Street generators and a zone-picked one, then clean them up.
    local spawned, picked = 0, 0
    for _, g in ipairs(nearbyGenerators(2495, -1687)) do
        if not g.vehicle and getDistanceBetweenPoints2D(g.x, g.y, 2495, -1687) < 250 then
            generate(g)
            local vehicle = g.vehicle
            if vehicle then
                spawned = spawned + 1
                if g.model < 0 then picked = picked + 1 end
                outputServerLog(("[parkedtest]   %s at %.0f, %.0f (%s)"):format(getVehicleNameFromModel(getElementModel(vehicle)), g.x, g.y, g.source))
                release(vehicle, g)
                destroyElement(vehicle)
            end
        end
    end
    ok = ok and spawned > 0
    outputServerLog(("[parkedtest] spawned %d around Grove Street (%d zone-picked models)"):format(spawned, picked))
    outputServerLog("[parkedtest] " .. (ok and "PASS" or "FAIL"))
end)
