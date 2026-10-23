-- Console-only: runs hours of the airliners' timetable (schedule.lua) and the circuits, and checks
-- them: every plane keeps flying, never jumps (from one leg to the next), no two planes are ever
-- within 25 m of each other on the ground or in a hold, none waits for ever, and the circuit planes
-- keep their spacing. No elements are made.
-- Plain Lua apart from the command, so it also runs offline.
AirTest = {}

local DT, HOURS, CLOSE = 1000, 4, 25

function AirTest.run(seed)
    local rnd = 0
    local function random(a, b)
        rnd = (rnd * 1103515245 + 12345 + (seed or 1234)) % 2147483648
        return a + rnd % (b - a + 1)
    end
    AirSchedule.prepare()
    local counts = {}
    for _, f in ipairs(AirConfig.fleet) do counts[f.setting] = f.count end
    local planes = AirSchedule.build(counts, 0, random)
    local flights, longestWait, close, waitedSince = {}, 0, 0, {}
    local closest = math.huge
    local last, jumps, worst = {}, 0, 0
    local holdLaps, topLevel, lapStarts = 0, 0, {}
    for now = 0, HOURS * 3600 * 1000, DT do
        for _, plane in pairs(planes) do
            local _, x, y, z = AirSchedule.at(plane, now)
            local l = last[plane.id]
            if l then
                local d = math.sqrt((x - l[1]) ^ 2 + (y - l[2]) ^ 2 + (z - l[3]) ^ 2)
                worst = math.max(worst, d)
                if d > 120 * DT / 1000 then jumps = jumps + 1 end
            end
            last[plane.id] = { x, y, z }
            local leg = plane.legs[1]
            if leg.desc.kind == "hold" and lapStarts[plane.id] ~= leg.start then
                lapStarts[plane.id] = leg.start
                holdLaps = holdLaps + 1
                topLevel = math.max(topLevel, plane.stack or 0)
            end
            local before = plane.state
            AirSchedule.step(plane, now, random, nil, planes)
            if before == "wait" and plane.state == "flight" then flights[plane.id] = (flights[plane.id] or 0) + 1 end
            if plane.state == "wait" then
                waitedSince[plane.id] = waitedSince[plane.id] or now
                longestWait = math.max(longestWait, now - waitedSince[plane.id])
            else
                waitedSince[plane.id] = nil
            end
        end
        if now % 2000 == 0 then
            -- On the ground (or nearly): no two planes close together.
            local pos = {}
            for _, plane in pairs(planes) do
                local leg, x, y, z = AirSchedule.at(plane, now)
                local low = leg.desc.kind ~= "flight" or z < 40
                if low then pos[#pos + 1] = { plane = plane, x = x, y = y, z = z } end
            end
            for i = 1, #pos do
                for j = i + 1, #pos do
                    local a, b = pos[i], pos[j]
                    local d = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
                    if d < closest then closest = d end
                    if d < CLOSE then close = close + 1 end
                end
            end
        end
        if now % 600000 == 0 and AirTest.pause then AirTest.pause() end
        AirSchedule.prune(now)
    end

    local lines, ok = {}, true
    local function check(cond, text) if not cond then ok = false end lines[#lines + 1] = (cond and "ok   " or "FAIL ") .. text end
    local n = 0
    for id, plane in pairs(planes) do
        n = n + 1
        lines[#lines + 1] = ("     plane %d (model %d): %d flights"):format(id, plane.model, flights[id] or 0)
        check((flights[id] or 0) >= HOURS * 2, ("plane %d kept flying"):format(id))
    end
    local total = 0
    for _, f in pairs(flights) do total = total + f end
    lines[#lines + 1] = ("     %d flights, %d holding laps, the highest hold level %d"):format(total, holdLaps, topLevel)
    check(jumps == 0, ("no plane jumps (fastest %.0f m/s)"):format(worst * 1000 / DT))
    check(close == 0, ("no two planes within %d m on the ground (closest %.0f m)"):format(CLOSE, closest))
    check(longestWait < 15 * 60000, ("nobody waited 15 minutes at a spot (longest %.1f min)"):format(longestWait / 60000))

    -- Circuits: the planes spaced evenly round the loop never meet.
    for _, c in ipairs(Circuits) do
        local frames = Legs.build({ kind = "spline", points = c.points, closed = true })
        local lap = Legs.duration(frames)
        local count = #(c.models or {})
        local nearest = math.huge
        for t = 0, lap, 500 do
            for i = 1, count do
                for j = i + 1, count do
                    local ax, ay, az = Legs.sample(frames, (t + (i - 1) * lap / count) % lap)
                    local bx, by, bz = Legs.sample(frames, (t + (j - 1) * lap / count) % lap)
                    nearest = math.min(nearest, math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2 + (az - bz) ^ 2))
                end
            end
        end
        lines[#lines + 1] = ("     circuit %s: %d planes, %.0f s a lap"):format(c.id, count, lap / 1000)
        check(nearest > 100, ("circuit %s planes never within 100 m (closest %.0f m)"):format(c.id, nearest))
    end
    lines[#lines + 1] = ok and ("PASS: %d planes, %d h"):format(n, HOURS) or "FAIL"
    return ok, lines
end

-- In the server: a coroutine resumed every frame.
if addCommandHandler then
    addCommandHandler("airtest", function(source, _, seed)
        if getElementType(source) ~= "console" then return end
        local t0 = getTickCount()
        local co = coroutine.create(function()
            local _, lines = AirTest.run(tonumber(seed))
            for _, line in ipairs(lines) do outputServerLog("[airtest] " .. line) end
            outputServerLog(("[airtest] took %d ms"):format(getTickCount() - t0))
        end)
        AirTest.pause = coroutine.yield
        local timer
        timer = setTimer(function()
            local ok, err = coroutine.resume(co)
            if not ok then outputServerLog("[airtest] ERROR: " .. tostring(err)) end
            if coroutine.status(co) == "dead" then killTimer(timer) end
        end, 50, 0)
    end)
end
