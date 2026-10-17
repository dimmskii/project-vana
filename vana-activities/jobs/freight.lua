-- Freight train (vanilla FREIGHT): driving the freight train, press the sub-mission key. Stop at each of
-- the five stations in turn before the time runs out; each pays its leg's time / 100 x level. All five
-- pass the level ($10000, then $50000 at level 2).
local F = Jobs.freight
local trains = Job.set(F.vehicles)

local function nextStation(session, from)
    local d = session.data
    local n = #F.stations
    local index = d.forward and from % n + 1 or (from - 2) % n + 1
    local st = F.stations[index]
    local leg = (d.forward and st.forward or st.back) + (F.extraMs[d.level] or 0)
    d.target, d.leg = index, leg
    d.deadline = (d.deadline and math.max(d.deadline, getTickCount()) or getTickCount()) + leg
    if d.blip and isElement(d.blip) then destroyElement(session:disown(d.blip)) end
    if d.marker and isElement(d.marker) then destroyElement(session:disown(d.marker)) end
    d.blip = session:blip(st, 0, 255, 255, 0)
    d.marker = session:marker("cylinder", st[1], st[2], st[3], 6, 255, 255, 0, 90)
    session:counter("time", session:text("FREI_14"), d.deadline - getTickCount(), "timer")
    session:big(session:text("FREI_05", math.floor(leg / 1000)), 2500, "small")
end

Activity.register("freight", {
    title = "FREI_X",
    gxt = "FTRAIN",
    cancelText = "FREI_02",
    launch = { vehicles = trains, help = "FTUTORA" },
    start = function(session, train)
        local d = session.data
        d.level, d.done = math.min(2, Activity.progress(session.player, "freight.level") or 1), 0
        d.forward = getTrainDirection(train) ~= false
        session:big(session:text("FREI_04", d.level), 4000, "title")
        session:help(session:text("FREI_03"))
        local x, y, z = getElementPosition(train)
        local nearest, best = 1, nil
        for i, st in ipairs(F.stations) do
            local dist = getDistanceBetweenPoints3D(x, y, z, st[1], st[2], st[3])
            if not best or dist < best then nearest, best = i, dist end
        end
        nextStation(session, nearest)
        session:after(6000, function(s) s:help(s:text("FREI_12")) end)
        session:after(12000, function(s) s:help(s:text("FREI_13")) end)
        session:every(500, function(s)
            local dd = s.data
            local v = Job.watchVehicle(s, trains, F.outMs, "FREI_02")
            if not v then return end
            if getTickCount() > dd.deadline then return s:fail("FREI_06") end
            local st = F.stations[dd.target]
            local vx, vy, vz = getElementPosition(v)
            if getDistanceBetweenPoints3D(vx, vy, vz, st[1], st[2], st[3]) < F.radius and Job.stopped(v, 0.0004) then
                local pay = math.floor(dd.leg / 100) * dd.level
                givePlayerMoney(s.player, pay)
                s:big(s:text("FREI_07", pay), 3000, "title")
                dd.done = dd.done + 1
                if dd.done >= #F.stations then
                    local bonus = F.levelBonus[dd.level]
                    givePlayerMoney(s.player, bonus)
                    Activity.setProgress(s.player, "freight.level", math.min(2, dd.level + 1))
                    if dd.level == 2 then Activity.setProgress(s.player, "freight.done", true) end
                    s:big(s:text("FREI_15", dd.level), 5000, "passed", bonus)
                    return s:stop("passed")
                end
                nextStation(s, dd.target)
            end
        end)
    end,
})

Activity.test("freight", function() return Gxt.raw("FREI_04", "FTRAIN") ~= nil and #F.stations == 5, "5 stations" end)
