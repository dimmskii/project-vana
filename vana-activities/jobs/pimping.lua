-- Pimping (vanilla PIMP): in a Broadway, press the sub-mission key. Pick up a girl, drive her to a
-- customer before time runs out, collect her when she's done. Every delivery adds a minute; the session
-- pays $300 per job when it ends. Ten jobs in one session earns vanilla's reward.
local M = Jobs.pimping
local cars = Job.set(M.vehicles)

local function stoppedNear(session, x, y, z)
    local v = Job.vehicle(session, cars)
    if not v then return false end
    local vx, vy, vz = getElementPosition(v)
    return getDistanceBetweenPoints3D(vx, vy, vz, x, y, z) < M.radius and Job.stopped(v), v
end

local function setTarget(session, target, colour)
    local d = session.data
    if d.blip and isElement(d.blip) then destroyElement(session:disown(d.blip)) end
    if d.marker and isElement(d.marker) then destroyElement(session:disown(d.marker)) end
    d.blip, d.marker = nil, nil
    if not target then return end
    if isElement(target) then
        d.blip = session:blip(target, 0, 80, 120, 255, 2)
    else
        d.blip = session:blip(target, 0, 255, 255, 0)
        d.marker = session:marker("checkpoint", target[1], target[2], target[3], 4, 255, 255, 0, 120)
    end
end

local function findGirl(session)
    local d = session.data
    local x, y, z = getElementPosition(session.player)
    local gx, gy, gz = Activity.streetSpot(x, y, z, M.girlRange[1], M.girlRange[2], "ped")
    if not gx then return session:after(3000, findGirl) end
    d.girl = session:ped(M.girls[math.random(#M.girls)], gx, gy, gz + 1, math.random(0, 359))
    d.phase = "girl"
    setTarget(session, d.girl)
    session:say(session:text("PIMP_2"))
end

local function findTrick(session)
    local d = session.data
    local x, y, z = getElementPosition(session.player)
    local tx, ty, tz = Activity.streetSpot(x, y, z, M.trickRange[1], M.trickRange[2], "vehicle", { x, y, z })
    if not tx then return session:after(3000, findTrick) end
    d.trick, d.phase = { tx, ty, tz }, "trick"
    setTarget(session, d.trick)
    -- Vanilla names the place in each line (PIMP_10..); ours names the zone.
    session:say(("~s~Drive to ~y~%s~s~ to find a customer for your girl."):format(getZoneName(tx, ty, tz)))
end

Activity.perk("pimp", function() end)

Activity.register("pimping", {
    title = "PIMP",
    gxt = "PIMP",
    launch = { vehicles = cars, help = "PTUTORA" },
    start = function(session)
        local d = session.data
        d.jobs = 0
        d.deadline = getTickCount() + M.startMs
        session:big(session:text("PIMP"), 4000, "title")
        session:counter("time", "TIME", M.startMs, "timer")
        session:after(1500, findGirl)
        session:every(500, function(s)
            local dd = s.data
            local v = Job.vehicle(s, cars)
            if not v then
                dd.outSince = dd.outSince or getTickCount()
                if not dd.outWarned then
                    dd.outWarned = true
                    s:say(s:text("PIMP_1", math.floor(M.outMs / 1000)))
                end
                if getTickCount() - dd.outSince > M.outMs then return s:fail("PIMP_59") end
                return
            end
            dd.outSince, dd.outWarned = nil, nil
            if isVehicleBlown(v) then return s:fail("PIMP_59") end
            if getTickCount() > dd.deadline then return s:fail("PIMP_91") end
            if dd.girl and (not isElement(dd.girl) or isPedDead(dd.girl)) then return s:fail("PIMP_51") end
            if dd.phase == "girl" or dd.phase == "collect" then
                local gx, gy, gz = getElementPosition(dd.girl)
                if stoppedNear(s, gx, gy, gz) then
                    setPedAnimation(dd.girl)
                    warpPedIntoVehicle(dd.girl, v, 1)
                    if dd.phase == "collect" then
                        dd.jobs = dd.jobs + 1
                        dd.deadline = dd.deadline + M.perJobMs
                        s:counter("time", "TIME", dd.deadline - getTickCount(), "timer")
                        s:counter("jobs", "JOBS", dd.jobs, "number")
                        if dd.jobs == M.rewardJobs and Activity.grantPerk(s.player, "pimp") then
                            s:big(s:text("SEXGOD"), 6000, "passed")
                        end
                    end
                    findTrick(s)
                end
            elseif dd.phase == "trick" then
                local t = dd.trick
                if stoppedNear(s, t[1], t[2], t[3]) then
                    removePedFromVehicle(dd.girl)
                    dd.phase = "busy"
                    setTarget(s, nil)
                    s:after(math.random(M.serviceMs[1], M.serviceMs[2]), function(ss)
                        ss.data.phase = "collect"
                        setTarget(ss, ss.data.girl)
                        ss:say(ss:text("PIMP_57"))
                    end)
                end
            end
        end)
    end,
    stop = function(session, reason)
        local d = session.data
        if isElement(session.player) and (d.jobs or 0) > 0 then
            local pay = d.jobs * M.payPerJob
            givePlayerMoney(session.player, pay)
            Activity.setProgress(session.player, "pimping.jobs", (Activity.progress(session.player, "pimping.jobs") or 0) + d.jobs)
            session:big(Activity.text("REWARD", nil, pay), 5000, "small")
        end
    end,
})

Activity.test("pimping", function() return Gxt.raw("PIMP_2", "PIMP") ~= nil, "" end)
