-- Beat the Cock! (vanilla TRIA): walk into the start on Santa Maria Beach or at Fleischberg. Run into the
-- water, swim the course, take the bicycle waiting at the shore, ride, then leave the bike and run to the
-- finish. Ours: you race the clock (each leg's length at a set pace) instead of vanilla's 12 athletes.
-- Winning pays vanilla's $10000 / $20000; best times are saved ("triathlon.<course>.*").
local T = Racing.triathlon

local function legOf(st, i)
    -- st: start, swimFrom, swimTo, bikesAt, _, bikeTo, _, runFrom, finish
    if i <= st[2] then return "run" end
    if i <= st[3] then return "swim" end
    if i <= st[6] then return "bike" end
    return "run"
end

local function targetMs(course)
    local cps, total = course.checkpoints, 0
    for i = 2, #cps do
        local a, b = cps[i - 1], cps[i]
        total = total + getDistanceBetweenPoints3D(a[1], a[2], a[3], b[1], b[2], b[3]) / T.pace[legOf(course.stages, i - 1)]
    end
    return math.floor(total * 1000)
end

local function showNext(session)
    local d = session.data
    for _, e in ipairs(d.shown or {}) do if isElement(e) then destroyElement(session:disown(e)) end end
    local c = d.course.checkpoints[d.next]
    if not c then return end
    local kind = (d.next == #d.course.checkpoints) and "cylinder" or "checkpoint"
    d.shown = { session:marker(kind, c[1], c[2], c[3], 4, 255, 210, 0, 150), session:blip(c, 0, 255, 210, 0) }
end

Activity.register("triathlon", {
    title = "Beat the Cock!",
    gxt = "RACETOR",
    start = function(session, key)
        local d = session.data
        local course = T[key]
        d.key, d.course, d.next = key, course, 2
        d.target = targetMs(course)
        local bikes = course.checkpoints[course.stages[4] + 1]
        d.bike = session:vehicle(T.bike, bikes[1] + 2, bikes[2], bikes[3] + 0.5, 0)
        session:big(Activity.text("TRIA"), 3000, "title")
        session:say(session:text("TRAI2"), 5000)
        session:counter("target", "TARGET", d.target, "timer")
        d.started = getTickCount()
        showNext(session)
        session:every(250, function(s)
            local dd = s.data
            local now = getTickCount()
            local c = dd.course.checkpoints[dd.next]
            local leg = legOf(dd.course.stages, dd.next - 1)
            local onBike = getPedOccupiedVehicle(s.player) == dd.bike
            -- Vanilla: on the bicycle for the cycling leg, off it for the runs.
            if (leg == "bike") ~= onBike and (leg ~= "swim") then
                dd.wrong = dd.wrong or now
                local left = math.ceil((T.outMs - (now - dd.wrong)) / 1000)
                if left <= 0 then return s:fail("RACES25") end
                if leg == "bike" then
                    s:say(s:text(left == 1 and "RACE_51" or "RACES50", left), 1000)
                else
                    s:say(s:text(left == 1 and "RACE_49" or "RACES48", left), 1000)
                end
            else
                dd.wrong = nil
            end
            if not c then return end
            local x, y, z = getElementPosition(s.player)
            if getDistanceBetweenPoints3D(x, y, z, c[1], c[2], c[3]) < 5 then
                dd.next = dd.next + 1
                if dd.next - 1 == dd.course.stages[4] then s:say(s:text("TRAI3"), 4000) end
                if dd.next - 1 == dd.course.stages[6] then s:say(s:text("TRAI4"), 4000) end
                if dd.next > #dd.course.checkpoints then
                    local elapsed = now - dd.started
                    local key = "triathlon." .. dd.key
                    local best = Activity.progress(s.player, key .. ".time")
                    if not best or elapsed < best then Activity.setProgress(s.player, key .. ".time", elapsed) end
                    if elapsed <= dd.target then
                        local first = not Activity.progress(s.player, key .. ".won")
                        Activity.setProgress(s.player, key .. ".won", true)
                        s:big(s:text("RACES18"), 4000, "passed")
                        if first then s:say(s:text("TRAI1", T.prizes[dd.key]), 5000) end
                        s:pass(nil, first and T.prizes[dd.key] or 0)
                    else
                        s:fail("RACEFA")
                    end
                    return
                end
                showNext(s)
            end
        end)
    end,
})

addEventHandler("onResourceStart", resourceRoot, function()
    for key, p in pairs(T.entries) do
        local m = createMarker(p[1], p[2], p[3] - 1, "cylinder", 3, 255, 200, 0, 110)
        createBlip(p[1], p[2], p[3], 33, 2, 255, 255, 255, 255, 0, 600)
        addEventHandler("onMarkerHit", m, function(player, matching)
            if matching and getElementType(player) == "player" and not getPedOccupiedVehicle(player) and not Activity.of(player) then
                Activity.start(player, "triathlon", key)
            end
        end)
    end
end)

Activity.test("triathlon", function()
    return #T.beach.checkpoints == 63 and #T.fleischberg.checkpoints == 104 and Gxt.raw("TRAI2", "RACETOR") ~= nil,
        ("targets %ds, %ds"):format(targetMs(T.beach) / 1000, targetMs(T.fleischberg) / 1000)
end)
