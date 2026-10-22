-- The trains as the server keeps them, whether or not anyone is near: where each is on its track (its
-- engine's rail distance, s), how fast it goes, and what it does next. Plain Lua (no MTA calls), so the
-- self-test (test.lua) can run hours of it at once. server.lua turns the trains near players into
-- elements and, while they exist, takes each one's s from where the owning client's game has it.
-- A train: { id, service, track, forward, s, v, length, cars = { model, ... }, engine,
--            state = "run" | "dwell" | "taken", dwellUntil, stopS }
-- "taken": a player drives it (or it lost its driver): nothing here moves it, others keep clear of it.
Schedule = {}

local sqrt, max, min = math.sqrt, math.max, math.min

local function dirOf(train) return train.forward and 1 or -1 end

-- Rail distance of the train's tail (the end of its last car).
function Schedule.tail(train)
    return TracksData.wrap(Tracks[train.track], train.s - dirOf(train) * train.length)
end

-- Where the engine stands when the train's middle is at a stop.
local function engineAtStop(train, stop)
    return TracksData.wrap(Tracks[train.track], stop.s + dirOf(train) * train.length / 2)
end

-- How far the train can run before reaching another one (any part of it), or math.huge. Another
-- train is the obstacle whichever way it faces (a taken one may come back towards it).
function Schedule.clearAhead(train, trains, lookahead)
    local t = Tracks[train.track]
    local best = math.huge
    for _, other in pairs(trains) do
        if other ~= train and other.track == train.track then
            local a = TracksData.ahead(t, train.s, other.s, train.forward)
            local b = TracksData.ahead(t, train.s, Schedule.tail(other), train.forward)
            local near, far = min(a, b), max(a, b)
            -- Our engine inside its span (they overlap): nowhere to go.
            if far - near > other.length + 1 then near = 0 end
            if near < best and near < (lookahead or math.huge) then best = near end
        end
    end
    return best
end

-- The next stop ahead for a train that stops: its engine's s there, or nil.
function Schedule.nextStop(train)
    local t = Tracks[train.track]
    local stops = Schedule.stopsOf(train.track)
    local best, bestS = math.huge, nil
    for _, stop in ipairs(stops) do
        local at = engineAtStop(train, stop)
        local d = TracksData.ahead(t, train.s, at, train.forward)
        -- Just left it: the one after.
        if train.leftStop and TracksData.ahead(t, train.leftStop, at, true) < 1 or train.leftStop and TracksData.ahead(t, at, train.leftStop, true) < 1 then
            d = math.huge
        end
        if d < best then best, bestS = d, at end
    end
    return bestS, best
end

local stopsCache = {}
function Schedule.stopsOf(track)
    if not stopsCache[track] then stopsCache[track] = Tracks[track] and TracksData.stops(Tracks[track]) or {} end
    return stopsCache[track]
end

-- The speed a train may have now: its cruise, and what lets it stop in time for the stop and the
-- train ahead.
function Schedule.allowed(train, trains)
    local service = TrainConfig.services[train.service]
    local limit = service.cruise
    local decel = TrainConfig.decel
    local clear = Schedule.clearAhead(train, trains, 2000)
    if clear < math.huge then limit = min(limit, sqrt(2 * decel * max(0, clear - TrainConfig.gap))) end
    local stopDist
    if service.stops then
        local at, d = Schedule.nextStop(train)
        if at then
            stopDist = d
            limit = min(limit, sqrt(2 * decel * d))
        end
    end
    return limit, stopDist, clear
end

-- One step of dt seconds at time now (ms).
function Schedule.step(train, trains, dt, now)
    if train.state == "taken" then return end
    local service = TrainConfig.services[train.service]
    if train.state == "dwell" then
        train.v = 0
        if now < train.dwellUntil then return end
        train.state, train.leftStop = "run", train.s
    end
    local limit, stopDist = Schedule.allowed(train, trains)
    local v0 = train.v
    if train.v < limit then
        train.v = min(limit, train.v + TrainConfig.accel * dt)
    else
        -- Down to the limit: its curve brakes at decel, harder (up to emergencyDecel) when something
        -- came up suddenly (a train taken just ahead).
        train.v = max(limit, train.v - TrainConfig.emergencyDecel * dt)
    end
    -- Never past the stop; arrived (slow enough to halt within a step): wait there.
    local move = train.v * dt
    if service.stops and stopDist then
        move = min(move, stopDist)
        if stopDist - move < 0.5 and v0 <= TrainConfig.emergencyDecel * dt then
            train.s, train.v = Schedule.nextStop(train), 0
            train.state, train.dwellUntil = "dwell", now + TrainConfig.dwell
            return
        end
    end
    train.s = TracksData.wrap(Tracks[train.track], train.s + dirOf(train) * move)
    Schedule.moved(train)
end

-- After the train's s changed (here, or read from its elements): a stop it left is forgotten once it's
-- clear of it, so the next lap stops there again.
function Schedule.moved(train)
    if train.leftStop and TracksData.ahead(Tracks[train.track], train.leftStop, train.s, train.forward) > 10 then
        local back = TracksData.ahead(Tracks[train.track], train.s, train.leftStop, train.forward)
        if back > 10 then train.leftStop = nil end
    end
end

-- A new train of a service at rail distance s, its cars picked (random) and length from them.
function Schedule.newTrain(id, serviceName, s, random)
    random = random or math.random
    local service = TrainConfig.services[serviceName]
    local cars = {}
    local n = service.maxCars > 0 and random(service.minCars, service.maxCars) or 0
    for i = 1, n do cars[i] = service.cars[random(1, #service.cars)] end
    return {
        id = id, service = serviceName, track = service.track, forward = service.forward,
        s = TracksData.wrap(Tracks[service.track], s), v = 0, state = "run",
        engine = service.engine, cars = cars, length = (n + 1) * TrainConfig.carSpacing,
    }
end

-- The configured trains, spread evenly along each track (services in TrainConfig.order).
function Schedule.build(counts, random)
    local trains, perTrack = {}, {}
    for _, name in ipairs(TrainConfig.order) do
        local service = TrainConfig.services[name]
        if Tracks[service.track] then
            for _ = 1, counts[name] or service.count do
                perTrack[service.track] = perTrack[service.track] or {}
                table.insert(perTrack[service.track], name)
            end
        end
    end
    local id = 0
    for track, names in pairs(perTrack) do
        local length = Tracks[track].length
        for i, name in ipairs(names) do
            id = id + 1
            trains[id] = Schedule.newTrain(id, name, (i - 1) * length / #names, random)
        end
    end
    return trains, id
end

-- Where to put a train back on its track: the middle of the longest free stretch, as far from every
-- other train as it can be, or nil when the track has no room. avoid(s) -> true rules a spot out
-- (players near it).
function Schedule.freeSpot(track, trains, need, avoid)
    local t = Tracks[track]
    local spans = {}
    for _, other in pairs(trains) do
        if other.track == track then
            local a, b = other.s, Schedule.tail(other)
            if not other.forward then a, b = b, a end
            spans[#spans + 1] = { from = b, to = a } -- forward along the rail: tail to engine
        end
    end
    if #spans == 0 then
        for k = 0, 7 do
            local s = k * t.length / 8
            if not avoid or not avoid(s) then return s end
        end
        return nil
    end
    table.sort(spans, function(p, q) return p.from < q.from end)
    local best, bestLen
    for i, span in ipairs(spans) do
        local nextSpan = spans[i % #spans + 1]
        local free = TracksData.ahead(t, span.to, nextSpan.from, true)
        if free > need and (not bestLen or free > bestLen) then
            local s = TracksData.wrap(t, span.to + free / 2)
            if not avoid or not avoid(s) then best, bestLen = s, free end
        end
    end
    return best
end
