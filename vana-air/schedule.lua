-- The airliners' timetable, as the server keeps it whether or not anyone is near: each plane waits at a
-- departure spot, takes off on a vanilla flight recording, lands, taxis to a departure spot at that
-- airport, waits, and so on. Plain Lua (no MTA calls), so the self-test (test.lua) can run hours of it.
-- Runways and spots are booked as time windows. A plane takes off once its takeoff roll is clear;
-- AirConfig.join ms before touchdown it asks for its landing roll, the taxi after it and the spot it
-- will wait at, and holds in a circle until it has them (the recording is rejoined where it was left).
-- Every spot a roll or taxi passes (within AirConfig.spotRadius) is booked too, so nothing rolls through
-- a waiting plane. A grounded plane can always leave, so the airports never lock each other up.
-- A plane: { id, model, state = "wait" | "flight" | "taxi" | "out", spot, flight, legs = { { desc,
--            frames, start, duration }, ... }, readyAt, approachAt, holding, holdRunway, stack, levelFreeAt }
AirSchedule = {}

local C = AirConfig
local INF = math.huge

local flightInfo = {}  -- flight id -> { frames, duration, liftoff, touchdown, origin, arrival, groundFrom, groundTo }
local routesFrom = {}  -- arrival spot id -> { route, ... } with route.frames, .duration, .crossed
local depSpots = {}    -- departure spot ids

local function near(x, y, spot) return (x - spot.x) ^ 2 + (y - spot.y) ^ 2 < C.spotRadius ^ 2 end

-- Spots a run of frames passes (from t0 to t1 ms into them).
local function crossed(frames, t0, t1)
    local out = {}
    for _, fr in ipairs(frames) do
        if fr.t >= t0 and fr.t <= t1 then
            for id, spot in pairs(AirSpots) do if not out[id] and near(fr.x, fr.y, spot) then out[id] = true end end
        end
    end
    return out
end

function AirSchedule.prepare()
    flightInfo, routesFrom, depSpots = {}, {}, {}
    for id, spot in pairs(AirSpots) do if #spot.departs > 0 then depSpots[#depSpots + 1] = id end end
    table.sort(depSpots)
    for id, flight in pairs(Flights) do
        local frames = flight.frames
        if #frames > 1 then
            local liftoff, touchdown = Legs.groundTimes(frames)
            local info = { frames = frames, duration = Legs.duration(frames), liftoff = liftoff, touchdown = touchdown }
            for sid, spot in pairs(AirSpots) do
                for _, f in ipairs(spot.departs) do if f == id then info.origin = sid end end
                for _, f in ipairs(spot.arrives) do if f == id then info.arrival = sid end end
            end
            info.groundFrom = crossed(frames, 0, liftoff)
            info.groundTo = crossed(frames, touchdown, info.duration)
            if info.origin and info.arrival then flightInfo[id] = info end
        end
    end
    for _, route in ipairs(TaxiRoutes) do
        local from, to = AirSpots[route.from], AirSpots[route.to]
        if from and to and #route.points > 1 then
            route.desc = { kind = "taxi", points = route.points, from = from.heading, to = to.heading }
            route.frames = Legs.build(route.desc)
            route.duration = Legs.duration(route.frames)
            route.crossed = crossed(route.frames, 0, route.duration)
            routesFrom[route.from] = routesFrom[route.from] or {}
            table.insert(routesFrom[route.from], route)
        end
    end
end

function AirSchedule.flightInfo(id) return flightInfo[id] end
function AirSchedule.departureSpots() return depSpots end

-- Bookings: resource ("spot:<id>", "runway:<id>") -> { { from, to, owner }, ... }.
local bookings = {}

local function free(key, a, b, owner)
    for _, w in ipairs(bookings[key] or {}) do
        if w.owner ~= owner and w.from < b and a < w.to then return false end
    end
    return true
end

local function book(key, a, b, owner)
    bookings[key] = bookings[key] or {}
    table.insert(bookings[key], { from = a, to = b, owner = owner })
end

-- Ends a plane's open booking of a spot (it leaves it), or all its bookings (taken, removed).
function AirSchedule.release(owner, key, at)
    for k, list in pairs(bookings) do
        for i = #list, 1, -1 do
            local w = list[i]
            if w.owner == owner and (not key or k == key) then
                if at and w.to == INF then w.to = at elseif not at then table.remove(list, i) end
            end
        end
    end
end

-- Old bookings dropped.
function AirSchedule.prune(now)
    for _, list in pairs(bookings) do
        for i = #list, 1, -1 do if list[i].to < now - 60000 then table.remove(list, i) end end
    end
end

-- A spot nobody holds or will hold from now on (for placing a plane), or nil.
function AirSchedule.isSpotFree(id, now) return free("spot:" .. id, now, INF, nil) end

-- obstacles(spotId) -> true: something not ours stands there (a taken plane): never booked through.
local function allFree(wins, plane, obstacles)
    for _, w in ipairs(wins) do
        local id = w[1]:match("^spot:(.+)$")
        if not free(w[1], w[2], w[3], plane) or id and obstacles and obstacles(id) then return false end
    end
    return true
end

local function shuffled(list, random)
    local out = {}
    for i, v in ipairs(list) do out[i] = v end
    for i = #out, 2, -1 do
        local j = random(1, i)
        out[i], out[j] = out[j], out[i]
    end
    return out
end

-- Taking off: the runway and every spot the roll passes, from now until airborne.
local function takeoffPlan(plane, now, random, obstacles)
    local spot = AirSpots[plane.spot]
    local M = C.margin
    for _, f in ipairs(shuffled(spot.departs, random)) do
        local info = flightInfo[f]
        if info and routesFrom[info.arrival] then
            local wins = { { "runway:" .. spot.runway, now, now + info.liftoff + M } }
            for id in pairs(info.groundFrom) do if id ~= plane.spot then wins[#wins + 1] = { "spot:" .. id, now, now + info.liftoff + M } end end
            if allFree(wins, plane, obstacles) then return f, info, wins end
        end
    end
    return nil
end

-- Landing: from t ms into the flight, at time now: the landing roll, a taxi route to a departure spot,
-- and that spot from then on.
local function landingPlan(plane, info, t, now, random, obstacles)
    local M = C.margin
    local arrival = AirSpots[info.arrival]
    local touchdown = now + info.touchdown - t
    local landed = now + info.duration - t
    for _, route in ipairs(shuffled(routesFrom[info.arrival] or {}, random)) do
        local taxied = landed + route.duration
        local wins = {
            { "runway:" .. arrival.runway, touchdown - M, taxied + M },
            { "spot:" .. route.to, landed, INF },
        }
        for id in pairs(info.groundTo) do wins[#wins + 1] = { "spot:" .. id, touchdown - M, landed + M } end
        for id in pairs(route.crossed) do if id ~= route.to then wins[#wins + 1] = { "spot:" .. id, landed, taxied + M } end end
        for _, rw in ipairs(route.runways) do wins[#wins + 1] = { "runway:" .. rw, landed, taxied + M } end
        if allFree(wins, plane, obstacles) then return route, wins end
    end
    return nil
end

local function legOf(desc, frames, start)
    return { desc = desc, frames = frames, start = start, duration = Legs.duration(frames) }
end

local function parkLeg(spotId, start)
    local s = AirSpots[spotId]
    local desc = { kind = "park", x = s.x, y = s.y, z = s.z, heading = s.heading }
    return legOf(desc, Legs.build(desc), start)
end

-- A plane put waiting at a departure spot.
function AirSchedule.place(plane, spotId, now, readyAt)
    plane.state, plane.spot, plane.readyAt = "wait", spotId, readyAt or now
    plane.legs = { parkLeg(spotId, now) }
    book("spot:" .. spotId, now, INF, plane)
end

-- The lowest hold level free over a runway (levels are kept until their plane is down from them).
local function freeLevel(runway, planes, now)
    local used = {}
    for _, p in pairs(planes or {}) do
        if p.holdRunway == runway and (p.holding or (p.levelFreeAt or 0) > now) then used[p.stack] = true end
    end
    local k = 0
    while used[k] do k = k + 1 end
    return k
end

-- A flying plane asks for its landing (a lap later when it has to come down from its hold level
-- first); refused, it flies a lap of the hold at its level and asks again at the end of it.
local function approach(plane, now, random, obstacles, planes)
    local info = flightInfo[plane.flight]
    local t = info.touchdown - C.join
    local x, y, z, fx, fy = Legs.sample(info.frames, t)
    local heading = math.deg(math.atan2(-fx, fy)) % 360
    -- Each level its own circle too (wider by holdWiden), all through the join point: there, a plane
    -- coming down has nearly reached the join height while the others pass at their levels.
    local function holdLap(fromRise, toRise)
        local desc = { kind = "hold", x = x, y = y, z = z, heading = heading, speed = C.holdSpeed,
                       radius = C.holdRadius + C.holdWiden * (plane.stack or 0), fromRise = fromRise, toRise = toRise }
        local frames = Legs.build(desc)
        return legOf(desc, frames, now), Legs.duration(frames)
    end
    local rise = plane.holding and C.holdStack * (plane.stack + 1) or 0
    local down, downMs
    if rise > 0 then down, downMs = holdLap(rise, 0) end
    local at = now + (downMs or 0)
    local route, wins = landingPlan(plane, info, t, at, random, obstacles)
    if route then
        for _, w in ipairs(wins) do book(w[1], w[2], w[3], plane) end
        local rest = { kind = "flight", id = plane.flight, from = t }
        local restFrames = Legs.build(rest, Flights)
        local landed = at + Legs.duration(restFrames)
        plane.legs = { legOf(rest, restFrames, at), legOf(route.desc, route.frames, landed), parkLeg(route.to, landed + route.duration) }
        if down then table.insert(plane.legs, 1, down) end
        plane.spot, plane.approachAt, plane.holding, plane.levelFreeAt = route.to, nil, nil, at
        return
    end
    if not plane.holding then
        plane.holdRunway = AirSpots[info.arrival].runway
        plane.stack = freeLevel(plane.holdRunway, planes, now)
        plane.holding = plane.flight
    end
    local leg, ms = holdLap(rise, C.holdStack * (plane.stack + 1))
    plane.legs = { leg }
    plane.approachAt = now + ms
end

-- One step at time now.
function AirSchedule.step(plane, now, random, obstacles, planes)
    random = random or math.random
    if plane.state == "out" then return end
    while #plane.legs > 1 and now >= plane.legs[2].start do table.remove(plane.legs, 1) end
    local kind = plane.legs[1].desc.kind
    if kind == "flight" or kind == "hold" then plane.state = "flight"
    elseif kind == "taxi" then plane.state = "taxi"
    elseif plane.state ~= "wait" then
        plane.state = "wait"
        plane.readyAt = now + random(C.wait[1], C.wait[2])
    end
    if plane.approachAt and now >= plane.approachAt then return approach(plane, now, random, obstacles, planes) end
    if plane.state ~= "wait" or now < plane.readyAt then return end
    local f, info, wins = takeoffPlan(plane, now, random, obstacles)
    if not f then return end
    AirSchedule.release(plane, "spot:" .. plane.spot, now)
    for _, w in ipairs(wins) do book(w[1], w[2], w[3], plane) end
    local out = { kind = "flight", id = f, to = info.touchdown - C.join }
    local frames = Legs.build(out, Flights)
    plane.legs = { legOf(out, frames, now) }
    plane.state, plane.flight, plane.approachAt, plane.spot = "flight", f, now + Legs.duration(frames), nil
end

-- Where a plane is at time now: its leg, then x, y, z, fx, fy, fz, rx, ry, rz, vx, vy, vz, gear.
function AirSchedule.at(plane, now)
    local leg = plane.legs[1]
    for i = #plane.legs, 1, -1 do
        if now >= plane.legs[i].start then leg = plane.legs[i] break end
    end
    return leg, Legs.sample(leg.frames, now - leg.start)
end

-- A plane put in the air somewhere along a flight, on its way in (it asks to land when it gets there).
function AirSchedule.launch(plane, now, random)
    random = random or math.random
    local ids = {}
    for f in pairs(flightInfo) do ids[#ids + 1] = f end
    if #ids == 0 then return false end
    table.sort(ids)
    local fid = ids[random(1, #ids)]
    local info = flightInfo[fid]
    local last = info.touchdown - C.join - 10000
    local t0 = random(math.min(last, info.liftoff + 20000), last)
    local out = { kind = "flight", id = fid, from = t0, to = info.touchdown - C.join }
    local frames = Legs.build(out, Flights)
    plane.legs = { legOf(out, frames, now) }
    plane.state, plane.flight, plane.approachAt, plane.spot, plane.holding = "flight", fid, now + Legs.duration(frames), nil, nil
    return true
end

-- The fleet: planes of each configured model, placed at free departure spots, ready at staggered
-- times; those the spots can't take start in the air, on their way in. counts: setting -> count.
function AirSchedule.build(counts, now, random)
    random = random or math.random
    bookings = {}
    local planes, id = {}, 0
    local spots = shuffled(depSpots, random)
    for _, f in ipairs(C.fleet) do
        for _ = 1, counts[f.setting] or f.count do
            id = id + 1
            local plane = { id = id, model = f.model }
            if spots[id] then
                AirSchedule.place(plane, spots[id], now, now + random(0, C.wait[2]))
                planes[id] = plane
            elseif AirSchedule.launch(plane, now, random) then
                planes[id] = plane
            end
        end
    end
    return planes
end
