-- Trucking (vanilla TRUCK): press enter/exit on the marker at RS Haul. Hook up the trailer and deliver the load to
-- one of vanilla's drop-offs; the load type decides the catch (fragile, timed, hot). Eight deliveries buy
-- you the depot, which then earns revenue.
local T = Jobs.trucking
local trucks = Job.set(T.trucks)

Assets.define("rshaul", T.income)

local function startMarker()
    local s = T.start
    local m = createMarker(s[1], s[2], s[3] - 0.1, "cylinder", 1.5, 255, 200, 0, 120)
    MapPoints.set("trucking", { category = "trucking", x = s[1], y = s[2], z = s[3] })
    Prompts.add(m, { text = "start trucking", use = function(player)
        if not Activity.of(player) then Activity.start(player, "trucking") end
    end })
    return m
end

Activity.register("trucking", {
    title = "TRUCK",
    gxt = "TRUCK",
    start = function(session)
        local d = session.data
        local player = session.player
        local done = Activity.progress(player, "trucking.done") or 0
        d.load = done < #T.loads and T.loads[done + 1] or T.loads[math.random(#T.loads)]
        local ts, rs = T.truckSpot, T.trailerSpot
        d.truck = session:vehicle(T.trucks[math.random(#T.trucks)], ts[1], ts[2], ts[3] + 1.5, ts[4])
        d.trailer = session:vehicle(T.trailers[math.random(#T.trailers)], rs[1], rs[2], rs[3] + 1.5, rs[4])
        local dest = T.destinations[math.random(#T.destinations)]
        d.dest = dest
        local distance = getDistanceBetweenPoints3D(ts[1], ts[2], ts[3], dest[1], dest[2], dest[3])
        d.cash = math.floor(distance * T.cashPerMetre)
        d.full = d.cash
        session:big(session:text("TRUCK"), 3000, "title")
        session:help(session:text(d.load.help))
        session:counter("cash", session:text("TRK_CSH"), d.cash, "money")
        d.distance = distance
        if d.load.fragile then session:counter("damage", session:text("TRK_DMG"), 0, "bar") end
        -- First the rig: the truck and its trailer (blue); the drop-off shows once they're hitched.
        d.truckBlip = session:blip(d.truck, 0, 80, 120, 255, 2)
        d.trailerBlip = session:blip(d.trailer, 0, 80, 120, 255, 2)
        d.truckHealth, d.trailerHealth = getElementHealth(d.truck), getElementHealth(d.trailer)
        session:say("~s~Get in the ~b~truck~s~ and hook up the ~b~trailer~s~.", 8000) -- ours: vanilla starts you in the cab
        session:every(500, function(s)
            local dd = s.data
            if not isElement(dd.truck) or isVehicleBlown(dd.truck) or not isElement(dd.trailer) or isVehicleBlown(dd.trailer) then
                return s:fail("TRK_F3")
            end
            local now = getTickCount()
            local inCab = getPedOccupiedVehicle(s.player) == dd.truck
            local hooked = dd.hitched or getVehicleTowedByVehicle(dd.truck) == dd.trailer
            -- Damage to the load (fragile loads): whichever of truck and trailer took more since the start.
            if dd.load.fragile then
                local lost = math.max(dd.truckHealth - getElementHealth(dd.truck), dd.trailerHealth - getElementHealth(dd.trailer), 0)
                local damage = math.min(100, lost / (dd.load.veryFragile and 3 or 5))
                dd.cash = math.floor(dd.full * (1 - damage / 100))
                s:counter("damage", s:text("TRK_DMG"), damage, "bar")
                s:counter("cash", s:text("TRK_CSH"), dd.cash, "money")
                if dd.cash <= 0 then return s:fail("TRK_F1") end
            end
            if not dd.started then
                if inCab and hooked then
                    dd.started = true
                    destroyElement(s:disown(dd.truckBlip))
                    destroyElement(s:disown(dd.trailerBlip))
                    local dx = dd.dest
                    dd.blip = s:blip(dx, 0, 255, 255, 0, 3)
                    dd.marker = s:marker("checkpoint", dx[1], dx[2], dx[3], 6, 255, 255, 0, 160)
                    s:say(("~s~Deliver the load to the ~y~drop-off~s~ in %s."):format(getZoneName(dx[1], dx[2], dx[3])), 8000) -- ours
                    if dd.load.stars then Activity.call("vana-services", "setMinimumWanted", s.player, dd.load.stars) end
                    if dd.load.timed then -- the clock starts with the rig hitched
                        dd.deadline = now + dd.distance * T.msPerMetre
                        s:counter("time", s:text("TRK_DLN"), dd.deadline - now, "timer")
                    end
                end
                return
            end
            -- Out of the cab or the trailer off: a grace period, then the job is lost.
            if not inCab then
                dd.outSince = dd.outSince or now
                local left = math.ceil((T.cabGraceMs - (now - dd.outSince)) / 1000)
                if left <= 0 then return s:fail("TRK_F4") end
                s:say(s:text(left == 1 and "TRK_H5B" or "TRK_H5", left), 1000)
            else
                dd.outSince = nil
            end
            if not hooked then
                dd.offSince = dd.offSince or now
                local left = math.ceil((T.attachGraceMs - (now - dd.offSince)) / 1000)
                if left <= 0 then return s:fail("TRK_F5") end
                if inCab then s:say(s:text(left == 1 and "TRK_H4B" or "TRK_H4", left), 1000) end
            else
                dd.offSince = nil
            end
            -- Timed: late halves the pay, very late halves it again, then it's over.
            if dd.load.timed then
                local late = now - dd.deadline
                if late > 0 and not dd.halved then
                    dd.halved, dd.full = 1, math.floor(dd.full / 2)
                    dd.cash = math.floor(dd.cash / 2)
                    s:say(s:text("TRK_H14"))
                elseif late > 60000 and dd.halved == 1 then
                    dd.halved, dd.full = 2, math.floor(dd.full / 2)
                    dd.cash = math.floor(dd.cash / 2)
                    s:say(s:text("TRK_H15"))
                    s:help(s:text("TRK_H16"))
                elseif late > 120000 then
                    return s:fail("TRK_F2")
                end
                s:counter("cash", s:text("TRK_CSH"), dd.cash, "money")
            end
            local x, y, z = getElementPosition(dd.trailer)
            local dx = dd.dest
            if hooked and getDistanceBetweenPoints3D(x, y, z, dx[1], dx[2], dx[3]) < T.dropRadius and Job.stopped(dd.truck) then
                local total = (Activity.progress(s.player, "trucking.done") or 0) + 1
                Activity.setProgress(s.player, "trucking.done", total)
                if total == T.missions and Assets.grant(s.player, "rshaul") then
                    s:help(s:text("ASS_LUV", T.income.cap))
                    s:pass("TRK_P4", dd.cash)
                elseif total == 1 then
                    s:help(s:text("TRK_P1"))
                    s:pass(nil, dd.cash)
                else
                    s:help(s:text("TRK_P3", total))
                    s:pass(nil, dd.cash)
                end
            end
        end)
    end,
})

addEventHandler("onResourceStart", resourceRoot, function() startMarker() end)

Activity.test("trucking", function()
    return #T.destinations >= 39 and Gxt.raw("TRK_H6", "TRUCK") ~= nil, ("%d drop-offs"):format(#T.destinations)
end)

-- Hitching reported by the game (more reliable than polling the tow link alone).
addEventHandler("onTrailerAttach", root, function(truck)
    for _, player in ipairs(getElementsByType("player")) do
        local session = Activity.of(player)
        if session and session.name == "trucking" and session.data.trailer == source and session.data.truck == truck then
            session.data.hitched = true
        end
    end
end)
addEventHandler("onTrailerDetach", root, function()
    for _, player in ipairs(getElementsByType("player")) do
        local session = Activity.of(player)
        if session and session.name == "trucking" and session.data.trailer == source then session.data.hitched = false end
    end
end)
