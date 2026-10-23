-- Platforms: people waiting for the Brown Streak at the stations (map data: platformspot), getting on
-- when it stops, and passengers getting off there. Vanilla's trains do the same (CTrain's passenger
-- states, which Neon switches off); ours are made by this resource, near players only. Whoever gets
-- off, wanders off or is hurt becomes one of vana-peds' pedestrians (releasePed, server.lua).
Platforms = {}

local CONFIG = TrainConfig.platforms
local population = exports["vana-population"]

local stations = {} -- stop id -> { id, s, x, y, z, spots = { platformspot, ... }, lastSpawn }
local waiting = {}  -- ped -> { station, spot, spec, owner, boarding = { car, seat, since, l } }

do
    local t = Tracks[0]
    local stops = {}
    for _, stop in ipairs(t and TracksData.stops(t) or {}) do stops[TracksData.nodeId(0, stop.index - 1)] = stop end
    for _, spot in ipairs(PlatformSpots or {}) do
        local stop = stops[spot.stop]
        if stop then
            stations[spot.stop] = stations[spot.stop] or { id = spot.stop, s = stop.s, x = stop.x, y = stop.y, z = stop.z, spots = {}, lastSpawn = 0 }
            table.insert(stations[spot.stop].spots, spot)
        end
    end
end

local function pickCivilian(x, y, z)
    for _ = 1, 6 do
        local spec = population:pickPed(x, y, z, {}, 1)
        if spec and spec.kind == "civilian" then return spec end
    end
    return nil
end

-- How many wait at a station now: a share of its spots, more by day (ours).
local function wanted(st)
    local hour = getTime()
    local fill = (hour >= 7 and hour < 22) and CONFIG.fill.day or CONFIG.fill.night
    return math.min(CONFIG.max, math.floor(#st.spots * fill + 0.5))
end

local function waitingAt(st)
    local n = 0
    for _, w in pairs(waiting) do if w.station == st then n = n + 1 end end
    return n
end

local function spawnWaiting(st, players, owner)
    local free = {}
    for _, spot in ipairs(st.spots) do
        local taken = false
        for _, w in pairs(waiting) do if w.spot == spot then taken = true break end end
        -- Not right in front of anyone.
        if not taken and not nearestPlayer(spot.x, spot.y, spot.z, players, CONFIG.notCloser) then free[#free + 1] = spot end
    end
    if #free == 0 then return end
    local spot = free[math.random(#free)]
    local spec = pickCivilian(spot.x, spot.y, spot.z)
    if not spec then return end
    local ped = createPed(spec.model, spot.x + (math.random() - 0.5), spot.y + (math.random() - 0.5), spot.z + 1, spot.heading)
    if not ped then return end
    setElementData(ped, "vana:train", "waiting")
    setElementSyncer(ped, owner, true, true)
    waiting[ped] = { station = st, spot = spot, spec = spec, owner = owner }
end

local function forget(ped)
    waiting[ped] = nil
end

local function emptyStation(st)
    for ped, w in pairs(waiting) do
        if w.station == st then
            forget(ped)
            if isElement(ped) then destroyElement(ped) end
        end
    end
end

-- The station a stopped train stands at (its middle on the stop), or nil.
local function stationOf(train)
    if train.track ~= 0 then return nil end
    local t = Tracks[0]
    local middle = TracksData.wrap(t, train.s - (train.forward and 1 or -1) * train.length / 2)
    for _, st in pairs(stations) do
        if TracksData.ahead(t, st.s, middle, true) < 3 or TracksData.ahead(t, middle, st.s, true) < 3 then return st end
    end
    return nil
end

-- Seats a passenger can take: every seat of the passenger cars, nobody in it or on the way to it.
local function freeSeats(train, l)
    local service = TrainConfig.services[train.service]
    local reserved = {}
    for _, w in pairs(waiting) do
        if w.boarding then reserved[w.boarding.car] = reserved[w.boarding.car] or {} reserved[w.boarding.car][w.boarding.seat] = true end
    end
    local seats = {}
    for _, car in ipairs(l.cars) do
        if isElement(car) and service.stops then
            for seat = 0, getVehicleMaxPassengers(car) or 0 do
                if not getVehicleOccupant(car, seat) and not (reserved[car] and reserved[car][seat]) then seats[#seats + 1] = { car = car, seat = seat } end
            end
        end
    end
    return seats
end

-- A train just made: passengers already aboard its passenger cars.
function Platforms.addRiders(train, l)
    l.riders = {}
    if not TrainConfig.services[train.service].stops then return end
    for _, place in ipairs(freeSeats(train, l)) do
        if math.random() < CONFIG.riderChance then
            local x, y, z = getElementPosition(place.car)
            local spec = pickCivilian(x, y, z)
            local ped = spec and createPed(spec.model, x, y, z + 2)
            if ped and warpPedIntoVehicle(ped, place.car, place.seat) then
                setElementData(ped, "vana:train", "rider")
                l.riders[ped] = { car = place.car, seat = place.seat, spec = spec }
            elseif ped then
                destroyElement(ped)
            end
        end
    end
end

function Platforms.setOwner(l, owner)
    for ped in pairs(l.riders or {}) do if isElement(ped) then setElementSyncer(ped, owner, true, true) end end
end

-- A train going out of the world: its passengers with it (not those already let go).
function Platforms.removeRiders(l, released)
    for ped in pairs(l.riders or {}) do
        if isElement(ped) and not released[ped] then destroyElement(ped) end
    end
    l.riders = {}
    for ped, w in pairs(waiting) do
        if w.boarding and w.boarding.l == l then w.boarding = nil end
    end
end

-- Where to put someone taken out of a car: the nearest platform spot beside it, else beside the car.
function Platforms.outside(vehicle)
    local x, y, z = getElementPosition(vehicle)
    local best, bestDist
    for _, st in pairs(stations) do
        for _, spot in ipairs(st.spots) do
            local d = getDistanceBetweenPoints3D(x, y, z, spot.x, spot.y, spot.z)
            if d < 25 and (not bestDist or d < bestDist) then best, bestDist = spot, d end
        end
    end
    if best then return best.x, best.y, best.z + 1 end
    return x + 3, y, z + 1
end

-- A train arrived at a station: some passengers get off, some of those waiting get on.
local function arrive(train, l, st, now)
    local leaving = {}
    for ped, r in pairs(l.riders) do
        if isElement(ped) and math.random() < CONFIG.alightChance then
            leaving[#leaving + 1] = ped
            r.leaving = now
        end
    end
    if #leaving > 0 and isElement(l.owner) then triggerClientEvent(l.owner, "vana-trains:alight", resourceRoot, leaving) end
    local seats = freeSeats(train, l)
    for ped, w in pairs(waiting) do
        if #seats == 0 then break end
        if w.station == st and not w.boarding and math.random() < CONFIG.boardChance then
            -- The nearest free seat's car.
            local px, py, pz = getElementPosition(ped)
            local bestI, bestD
            for i, place in ipairs(seats) do
                local cx, cy, cz = getElementPosition(place.car)
                local d = getDistanceBetweenPoints3D(px, py, pz, cx, cy, cz)
                if not bestD or d < bestD then bestI, bestD = i, d end
            end
            local place = table.remove(seats, bestI)
            w.boarding = { car = place.car, seat = place.seat, since = now, l = l }
            if isElement(w.owner) then triggerClientEvent(w.owner, "vana-trains:board", resourceRoot, ped, place.car, place.seat) end
        end
    end
end

local function stopBoarding(ped, w)
    w.boarding = nil
    if isElement(w.owner) then triggerClientEvent(w.owner, "vana-trains:stop", resourceRoot, ped) end
end

function Platforms.tick(players, live, now)
    -- Stations near players fill up to what they hold now; far from everyone, they empty.
    for _, st in pairs(stations) do
        local owner, d = nearestPlayer(st.x, st.y, st.z, players, CONFIG.keep)
        if not owner then
            emptyStation(st)
        elseif d <= CONFIG.range and now - st.lastSpawn > CONFIG.spawnEvery and waitingAt(st) < wanted(st) then
            st.lastSpawn = now
            spawnWaiting(st, players, owner)
        end
    end

    -- Those waiting: gone, got on, wandered off (a native reaction: fled from gunfire), handed over.
    for ped, w in pairs(waiting) do
        if not isElement(ped) or isPedDead(ped) then
            forget(ped)
        elseif getPedOccupiedVehicle(ped) then
            local b = w.boarding
            forget(ped)
            if b and getPedOccupiedVehicle(ped) == b.car and b.l.riders then
                setElementData(ped, "vana:train", "rider")
                b.l.riders[ped] = { car = b.car, seat = getPedOccupiedVehicleSeat(ped), spec = w.spec }
                if isElement(b.l.owner) then setElementSyncer(ped, b.l.owner, true, true) end
            else
                releasePed(ped, w.spec)
            end
        else
            local x, y, z = getElementPosition(ped)
            if not w.boarding and getDistanceBetweenPoints3D(x, y, z, w.spot.x, w.spot.y, w.spot.z) > CONFIG.wander then
                forget(ped)
                releasePed(ped, w.spec)
            elseif w.boarding and now - w.boarding.since > CONFIG.boardMs then
                -- Didn't make it in: next to the door, put in; otherwise back to waiting.
                local b = w.boarding
                local near = false
                if isElement(b.car) then
                    local cx, cy, cz = getElementPosition(b.car)
                    near = getDistanceBetweenPoints3D(x, y, z, cx, cy, cz) < 6
                end
                if near and not getVehicleOccupant(b.car, b.seat) then
                    warpPedIntoVehicle(ped, b.car, b.seat)
                else
                    stopBoarding(ped, w)
                end
            else
                local owner = nearestPlayer(x, y, z, players, CONFIG.keep)
                if owner and owner ~= w.owner and (not isElement(w.owner) or not nearestPlayer(x, y, z, { w.owner }, CONFIG.range)) then
                    w.owner = owner
                    setElementSyncer(ped, owner, true, true)
                end
            end
        end
    end

    -- Trains at stations: arrivals, holding the doors for those getting on, passengers who got off.
    for train, l in pairs(live) do
        l.riders = l.riders or {}
        if train.state == "dwell" and train.arrivedAt and l.arrived ~= train.arrivedAt then
            l.arrived = train.arrivedAt
            local st = stationOf(train)
            if st then arrive(train, l, st, now) end
        end
        if train.state == "dwell" then
            local boarding = false
            for _, w in pairs(waiting) do if w.boarding and w.boarding.l == l then boarding = true break end end
            if boarding and now - (train.arrivedAt or now) < TrainConfig.dwell + CONFIG.maxExtraDwell then
                train.dwellUntil = math.max(train.dwellUntil, now + 1500)
            end
        else
            for ped, w in pairs(waiting) do
                if w.boarding and w.boarding.l == l then stopBoarding(ped, w) end
            end
        end
        for ped, r in pairs(l.riders) do
            if not isElement(ped) or isPedDead(ped) then
                l.riders[ped] = nil
            elseif getPedOccupiedVehicle(ped) ~= r.car then
                l.riders[ped] = nil
                releasePed(ped, r.spec)
            elseif r.leaving and now - r.leaving > CONFIG.alightMs then
                -- Never got out: taken out onto the platform.
                l.riders[ped] = nil
                removePedFromVehicle(ped)
                setElementPosition(ped, Platforms.outside(r.car))
                releasePed(ped, r.spec)
            end
        end
    end
end

-- Someone waiting or riding hurt by a player: they answer as their personality has it (vana-peds
-- runs the fight or the flight).
function Platforms.hurt(ped, attacker, live)
    local w = waiting[ped]
    if w then
        forget(ped)
        return releasePed(ped, w.spec, reactionTo(w.spec, attacker))
    end
    for _, l in pairs(live) do
        local r = l.riders and l.riders[ped]
        if r then
            l.riders[ped] = nil
            return releasePed(ped, r.spec, reactionTo(r.spec, attacker))
        end
    end
end

-- For /trains: how many wait at each station, and ride.
function Platforms.describe(live)
    local lines = {}
    for _, st in pairs(stations) do
        local n = waitingAt(st)
        if n > 0 then lines[#lines + 1] = ("%s: %d waiting"):format(getZoneName(st.x, st.y, st.z), n) end
    end
    local riders = 0
    for _, l in pairs(live) do for _ in pairs(l.riders or {}) do riders = riders + 1 end end
    if riders > 0 then lines[#lines + 1] = ("%d riding"):format(riders) end
    return lines
end
