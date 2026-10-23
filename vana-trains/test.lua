-- Console-only: runs the configured trains for hours of schedule (schedule.lua) and checks it: no
-- train ever runs into another, the stopping ones halt with their middle at every station stop on
-- each lap, nobody goes over its cruise or brakes harder than the emergency rate, and a train taken
-- and left standing on the line holds the ones behind it only while it's there; level crossings are
-- closed whenever a train is on them and open most of the time. No elements are made.
-- Plain Lua apart from the command, so it also runs offline.
TrainTest = {}

local DT, HOURS = 0.5, 3
local BLOCK_FROM, BLOCK_FOR = 3600, 900 -- s: a train taken and left standing, then gone

function TrainTest.run(seed)
    local rnd = 0
    local function random(a, b) -- seeded, the same on every run
        rnd = (rnd * 1103515245 + 12345 + (seed or 1234)) % 2147483648
        return a + rnd % (b - a + 1)
    end
    local trains, lastId = Schedule.build({}, random)
    local stats = { steps = 0, minGap = math.huge, overSpeed = 0, hardBrake = 0, collisions = 0, badStops = 0, stops = {} }
    local laps, travelled, prevS, prevV = {}, {}, {}, {}
    for id, train in pairs(trains) do laps[id], travelled[id], prevS[id], prevV[id] = 0, 0, train.s, 0 end
    local crossings = Schedule.prepareCrossings(TrackCrossings or {})
    local closedSteps, openOnTrain, checks = {}, 0, 0
    local blocker
    local now
    for step = 1, HOURS * 3600 / DT do
        now = step * DT * 1000
        local t = step * DT
        if t == BLOCK_FROM then
            -- Taken on the line ahead of a stopping train, and left there.
            local victim
            for _, train in pairs(trains) do if TrainConfig.services[train.service].stops then victim = train break end end
            if victim then
                lastId = lastId + 1
                blocker = Schedule.newTrain(lastId, "freight", victim.s + (victim.forward and 1 or -1) * 1500, random)
                blocker.state = "taken"
                trains[lastId] = blocker
            end
        elseif blocker and t == BLOCK_FROM + BLOCK_FOR then
            trains[blocker.id], blocker = nil, nil
        end
        for _, train in pairs(trains) do Schedule.step(train, trains, DT, now) end
        for id, train in pairs(trains) do
            if train.state ~= "taken" and laps[id] then
                local service = TrainConfig.services[train.service]
                local track = Tracks[train.track]
                if train.v > service.cruise + 0.01 then stats.overSpeed = stats.overSpeed + 1 end
                if prevV[id] - train.v > TrainConfig.emergencyDecel * DT + 0.01 then stats.hardBrake = stats.hardBrake + 1 end
                local d = TracksData.ahead(track, prevS[id], train.s, train.forward)
                if d > track.length / 2 then d = 0 end -- (never backwards)
                travelled[id] = travelled[id] + d
                prevS[id], prevV[id] = train.s, train.v
                local clear = Schedule.clearAhead(train, trains)
                if clear < stats.minGap then stats.minGap = clear end
                if clear < 1 then stats.collisions = stats.collisions + 1 end
                if train.state == "dwell" and train.dwellUntil == now + TrainConfig.dwell then
                    -- Just arrived: its middle on a stop?
                    local middle = TracksData.wrap(track, train.s - (train.forward and 1 or -1) * train.length / 2)
                    local onStop = false
                    for _, stop in ipairs(Schedule.stopsOf(train.track)) do
                        if math.abs(TracksData.ahead(track, stop.s, middle, true)) < 1 or TracksData.ahead(track, middle, stop.s, true) < 1 then onStop = true end
                    end
                    if not onStop then stats.badStops = stats.badStops + 1 end
                    stats.stops[id] = (stats.stops[id] or 0) + 1
                end
            end
        end
        if step % 2 == 0 then
            checks = checks + 1
            local closed = Schedule.closedCrossings(crossings, trains)
            for _, c in ipairs(crossings) do
                if closed[c.id] then closedSteps[c.id] = (closedSteps[c.id] or 0) + 1 end
                for _, train in pairs(trains) do
                    if train.track == c.track and not closed[c.id] then
                        local track = Tracks[c.track]
                        local r = TracksData.ahead(track, train.s, c.s, train.forward)
                        if r > track.length / 2 then r = r - track.length end
                        if r <= 0 and r >= -train.length then openOnTrain = openOnTrain + 1 end
                    end
                end
            end
        end
        stats.steps = step
        if step % 500 == 0 and TrainTest.pause then TrainTest.pause() end
    end

    local lines, ok = {}, true
    local function check(cond, text) if not cond then ok = false end lines[#lines + 1] = (cond and "ok   " or "FAIL ") .. text end
    for id, train in pairs(trains) do
        if laps[id] then
            local service = TrainConfig.services[train.service]
            local lap = Tracks[train.track].length
            local n = travelled[id] / lap
            lines[#lines + 1] = ("     train %d %s: %.1f km (%.2f laps), %d stops"):format(id, train.service, travelled[id] / 1000, n, stats.stops[id] or 0)
            -- Moving on: at least a third of cruise on average, stops and holds included.
            check(travelled[id] > service.cruise / 3 * HOURS * 3600, ("train %d kept going"):format(id))
            if service.stops then
                local stops = #Schedule.stopsOf(train.track)
                check((stats.stops[id] or 0) >= math.floor(n) * stops, ("train %d stopped at every stop on each lap (%d stops, %d each lap)"):format(id, stats.stops[id] or 0, stops))
            end
        end
    end
    check(stats.collisions == 0, ("no train ran into another (closest %.1f m)"):format(stats.minGap))
    check(stats.overSpeed == 0, "nobody over its cruise speed")
    check(stats.hardBrake == 0, "nobody braked harder than the emergency rate")
    check(stats.badStops == 0, "every halt at a stop had the train's middle on it")
    local mostClosed, everClosed = 0, 0
    for _, n in pairs(closedSteps) do
        everClosed = everClosed + 1
        mostClosed = math.max(mostClosed, n / checks)
    end
    check(openOnTrain == 0, ("no crossing open with a train on it (%d crossings, %d closed at some time)"):format(#crossings, everClosed))
    check(#crossings == 0 or everClosed > 0 and mostClosed < 0.5, ("crossings open most of the time (the busiest closed %.0f%%)"):format(mostClosed * 100))
    lines[#lines + 1] = ok and ("PASS: %d trains, %d h of schedule"):format(#lines > 0 and lastId or 0, HOURS) or "FAIL"
    return ok, lines
end

-- In the server: a coroutine resumed every frame (the whole run at once would hold the server up for seconds).
if addCommandHandler then
    addCommandHandler("traintest", function(source, _, seed)
        if getElementType(source) ~= "console" then return end
        local t0 = getTickCount()
        local co = coroutine.create(function()
            local _, lines = TrainTest.run(tonumber(seed))
            for _, line in ipairs(lines) do outputServerLog("[traintest] " .. line) end
            outputServerLog(("[traintest] took %d ms"):format(getTickCount() - t0))
        end)
        TrainTest.pause = coroutine.yield
        local timer
        timer = setTimer(function()
            local ok, err = coroutine.resume(co)
            if not ok then outputServerLog("[traintest] ERROR: " .. tostring(err)) end
            if coroutine.status(co) == "dead" then killTimer(timer) end
        end, 50, 0)
    end)
end
