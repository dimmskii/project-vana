-- Stadium events (vanilla KICKSTA and BLOOD). Kickstart: collect coronas on a Sanchez in the LV
-- stadium for points (green 1, amber 2, red 3) in four minutes; beat your best score; paid score x $100.
-- Blood Ring: in a Bloodring Banger, drive through checkpoints to keep your clock up while the others
-- try to wreck you; get the clock above the target time to win $10000 (the target grows a minute with
-- each win). Both run in the player's private dimension.
local K, B = Racing.kickstart, Racing.bloodring

local function sendBack(player, p, interior)
    setTimer(function()
        if not isElement(player) then return end
        if getPedOccupiedVehicle(player) then removePedFromVehicle(player) end
        setElementDimension(player, 0)
        setElementInterior(player, interior or 0, p[1] or p.x, p[2] or p.y, (p[3] or p.z) + 1)
        setElementPosition(player, p[1] or p.x, p[2] or p.y, (p[3] or p.z) + 1)
    end, 500, 1)
end

-- Kickstart ---------------------------------------------------------------------------------------------
Activity.register("kickstart", {
    title = "Kickstart",
    gxt = "KICKSTT",
    start = function(session)
        local d = session.data
        local player = session.player
        local dim = Activity.dimension(player)
        setElementInterior(player, K.interior)
        setElementDimension(player, dim)
        local bike = session:vehicle(K.bike, K.start[1], K.start[2], K.start[3] + 0.5, K.start[4])
        setElementInterior(bike, K.interior)
        setElementDimension(bike, dim)
        warpPedIntoVehicle(player, bike)
        d.bike, d.score, d.left, d.coronas = bike, 0, #K.coronas, K.coronas
        d.best = Activity.progress(player, "kickstart.best") or 0
        session:say(session:text("KICK_10"), 7000)
        session:big(session:text("KICK_21", d.best), 3000, "small")
        session:counter("score", "SCORE", 0, "number")
        session:counter("time", "TIME", K.timeMs, "timer")
        d.deadline = getTickCount() + K.timeMs
        triggerClientEvent(player, "vana-stadium:coronas", resourceRoot, K.coronas, dim, K.interior)
        session:every(250, function(s)
            local dd = s.data
            if not isElement(dd.bike) or isVehicleBlown(dd.bike) then return s:fail("KICK_12") end
            if getPedOccupiedVehicle(s.player) ~= dd.bike then
                dd.out = dd.out or getTickCount()
                if getTickCount() - dd.out > 10000 then return s:fail("KICK_12") end
            else
                dd.out = nil
            end
            if getTickCount() > dd.deadline or dd.left <= 0 then
                local pay = dd.score * K.payPerPoint
                givePlayerMoney(s.player, pay)
                if dd.score > dd.best then
                    Activity.setProgress(s.player, "kickstart.best", dd.score)
                    s:big(s:text("KICK_22", dd.score) .. "~n~$" .. pay, 5000, "passed")
                else
                    s:big(s:text("KICK_24") .. "~n~" .. s:text("KICK_25", dd.score), 5000, "failed")
                end
                s:after(3000, function(ss) ss:stop("done") end)
                dd.deadline = math.huge
            end
        end)
    end,
    onCorona = function(session, c)
        local d = session.data
        d.score, d.left = d.score + c[4], d.left - 1
        session:say(session:text(({ "KICK_14", "KICK_15", "KICK_16" })[c[4]]), 2000)
        session:counter("score", "SCORE", d.score, "number")
    end,
    stop = function(session)
        if isElement(session.player) then
            triggerClientEvent(session.player, "vana-stadium:coronas", resourceRoot, nil)
            sendBack(session.player, K.exit)
        end
    end,
})

-- Coronas collected on the client (Kickstart, the stunt courses): the activity's onCorona decides.
addEvent("vana-stadium:corona", true)
addEventHandler("vana-stadium:corona", resourceRoot, function(i)
    local session = Activity.of(client)
    local d = session and session.data
    local list = d and d.coronas
    local c = list and type(i) == "number" and list[i]
    if not c or (d.got and d.got[i]) or not session.def.onCorona then return end
    local x, y, z = getElementPosition(client)
    if getDistanceBetweenPoints3D(x, y, z, c[1], c[2], c[3]) > 8 then return end
    d.got = d.got or {}
    d.got[i] = true
    session.def.onCorona(session, c)
end)

-- Blood Ring --------------------------------------------------------------------------------------------
local function newCheckpoint(session)
    local d = session.data
    local a = B.area
    if d.cp and isElement(d.cp) then destroyElement(session:disown(d.cp)) end
    local x, y = a[1] + math.random() * (a[2] - a[1]), a[3] + math.random() * (a[4] - a[3])
    d.cpPos = { x, y, a[5] }
    d.cp = session:marker("checkpoint", x, y, a[5], 6, 255, 210, 0, 160)
    setElementInterior(d.cp, B.interior)
    setElementDimension(d.cp, d.dim)
end

Activity.register("bloodring", {
    title = "Blood Ring",
    gxt = "BLOOD",
    start = function(session)
        local d = session.data
        local player = session.player
        d.dim = Activity.dimension(player)
        d.target = Activity.progress(player, "bloodring.target") or B.targetMs
        setElementInterior(player, B.interior)
        setElementDimension(player, d.dim)
        local p = B.player
        d.car = session:vehicle(B.car, p[1], p[2], p[3] + 1, p[4])
        setElementInterior(d.car, B.interior)
        setElementDimension(d.car, d.dim)
        warpPedIntoVehicle(player, d.car)
        d.rivals, d.wrecked = {}, 0
        for i = 1, B.opponents do
            local g = B.grid[i]
            local car = session:vehicle(B.car, g[1], g[2], g[3] + 1, math.random(0, 359))
            local ped = session:ped(Racing.drivers[math.random(#Racing.drivers)], g[1], g[2], g[3] + 2)
            for _, e in ipairs({ car, ped }) do setElementInterior(e, B.interior) setElementDimension(e, d.dim) end
            warpPedIntoVehicle(ped, car)
            setElementSyncer(car, player, true, true)
            setElementSyncer(ped, player, true, true)
            d.rivals[#d.rivals + 1] = { car = car, ped = ped }
        end
        d.clock = B.startMs
        d.last = getTickCount()
        session:say(session:text("BLOD_01"), 5000)
        session:after(5000, function(s) s:say(s:text("BLOD_10"), 5000) end)
        session:after(10000, function(s) s:say(s:text(d.target <= 60000 and "BLOD_11" or "BLOD_12", math.floor(d.target / 60000)), 5000) end)
        newCheckpoint(session)
        triggerClientEvent(player, "vana-stadium:rivals", resourceRoot, d.rivals, d.car)
        session:every(250, function(s)
            local dd = s.data
            local now = getTickCount()
            dd.clock = dd.clock - (now - dd.last)
            dd.last = now
            s:counter("clock", "TIME", math.max(0, dd.clock), "timer")
            if not isElement(dd.car) or isVehicleBlown(dd.car) then return s:fail("RACES24") end
            if dd.clock <= 0 then return s:fail("BLOD_05") end
            local x, y, z = getElementPosition(dd.car)
            local c = dd.cpPos
            if getDistanceBetweenPoints3D(x, y, z, c[1], c[2], c[3]) < 7 then
                dd.clock = dd.clock + B.perCheckpointMs
                newCheckpoint(s)
            end
            local wrecked = 0
            for _, r in ipairs(dd.rivals) do
                if not isElement(r.car) or isVehicleBlown(r.car) then wrecked = wrecked + 1 end
            end
            dd.wrecked = wrecked
            if dd.clock > dd.target then
                Activity.setProgress(s.player, "bloodring.target", dd.target + B.targetStepMs)
                s:say(s:text("BLOD_08") .. " " .. wrecked, 5000)
                s:pass(nil, B.prize)
            end
        end)
    end,
    stop = function(session)
        if isElement(session.player) then
            triggerClientEvent(session.player, "vana-stadium:rivals", resourceRoot, nil)
            sendBack(session.player, B.entry)
        end
    end,
})

addEventHandler("onResourceStart", resourceRoot, function()
    local e = B.entry
    local m = createMarker(e.x, e.y, e.z - 0.1, "cylinder", 1.5, 255, 200, 0, 120)
    MapPoints.set("bloodring", { category = "stadium", x = e.x, y = e.y, z = e.z })
    Prompts.add(m, { text = "enter the Blood Ring", use = function(player)
        if not Activity.of(player) then Activity.start(player, "bloodring") end
    end })
end)

Activity.test("stadium", function()
    return #K.coronas == 33 and Gxt.raw("KICK_10", "KICKSTT") ~= nil and Gxt.raw("BLOD_01", "BLOOD") ~= nil, "Kickstart and Blood Ring"
end)
