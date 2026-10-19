-- Race tournament (vanilla CPRACE): press enter/exit on an entry marker and pick a race. Street, bike and air races
-- and the 8-Track and Dirt Track, against vanilla's line-ups (air races are against the clock), in your
-- private dimension. Opponents are driven by your client (races/client.lua); positions and checkpoints
-- are kept here. First wins pay vanilla's prizes; best results and times are saved ("race.<n>.*").
local C = Racing

local function raceName(index)
    return Activity.text(C.names[index] or ("RACE%02d"):format(index), "RACETOR")
end

local function heading(a, b)
    return (math.deg(math.atan2(-(b[1] - a[1]), b[2] - a[2]))) % 360
end

local function ordinal(n)
    return Activity.text(n == 1 and "RACES41" or n == 2 and "RACES42" or n == 3 and "RACES43" or "RACES44", "RACETOR", n)
end

local function clock(ms)
    local s = math.floor(ms / 1000)
    return ("%d:%02d"):format(math.floor(s / 60), s % 60)
end

-- Checkpoints in order for the whole race (laps repeat the circuit; the first is the start line).
local function course(r)
    local list = {}
    for _ = 1, r.laps do
        for i = 2, #r.checkpoints do list[#list + 1] = r.checkpoints[i] end
    end
    return list
end

local function standings(session)
    local d = session.data
    local list = {}
    for _, racer in ipairs(d.racers) do
        local cp = d.course[racer.next]
        local dist = 0
        if cp and isElement(racer.vehicle) then
            local x, y, z = getElementPosition(racer.vehicle)
            dist = getDistanceBetweenPoints3D(x, y, z, cp[1], cp[2], cp[3])
        end
        list[#list + 1] = { racer = racer, score = (racer.finished and 1e12 - racer.finished) or (racer.next - 1) * 1e5 - dist }
    end
    table.sort(list, function(a, b) return a.score > b.score end)
    for i, e in ipairs(list) do e.racer.position = i end
end

local function finishRace(session)
    local d = session.data
    local player = session.player
    local me = d.me
    local elapsed = getTickCount() - d.go
    local key = d.def and d.def.key or ("race." .. d.index)
    local bestPos = Activity.progress(player, key .. ".best")
    local bestTime = Activity.progress(player, key .. ".time")
    local lines = {}
    if not bestPos or me.position < bestPos then
        Activity.setProgress(player, key .. ".best", me.position)
        lines[#lines + 1] = Activity.text("TOP_POS", "RACETOR") .. " " .. ordinal(me.position)
    end
    if me.position == 1 and (not bestTime or elapsed < bestTime) then
        Activity.setProgress(player, key .. ".time", elapsed)
        lines[#lines + 1] = Activity.text("TOPTIME", "RACETOR") .. " " .. clock(elapsed)
    end
    local won = me.position == 1
    session:big((won and Activity.text("RACES18", "RACETOR") or Activity.text("RACES_8", "RACETOR")) .. "~n~~w~" .. ordinal(me.position) .. "  " .. clock(elapsed), 5000, won and "passed" or "failed")
    if #lines > 0 then session:say(table.concat(lines, "~n~"), 5000) end
    if won and d.def and d.def.onWin then d.def.onWin(session) end
    if won and not Activity.progress(player, key .. ".won") then
        Activity.setProgress(player, key .. ".won", true)
        local prize = d.def and d.def.prize or C.prizes[d.index] or C.prize
        givePlayerMoney(player, prize)
        session:after(2500, function(s) s:big(Activity.text("REWARD", nil, prize), 3000, "small") end)
        if d.index == 25 then
            for i in ipairs(C.stadiumCars) do OwnedCars.grant(player, "stadium" .. i) end
        end
        local all = not d.def
        for index in pairs(d.def and {} or RaceTable) do
            if not Activity.progress(player, "race." .. index .. ".won") then all = false break end
        end
        if all and not Activity.progress(player, "race.all") then
            Activity.setProgress(player, "race.all", true)
            givePlayerMoney(player, C.allRaces)
            session:after(5500, function(s) s:big(Activity.text("REWARD", nil, C.allRaces), 4000, "passed") end)
        end
    end
    session:after(5000, function(s) s:stop("finished") end)
end

Activity.register("race", {
    title = "Race",
    gxt = "RACETOR",
    start = function(session, index, entry, def)
        local r = def or RaceTable[index]
        local d = session.data
        local player = session.player
        d.index, d.course, d.entry, d.def = index, course(r), entry, def
        local air = not def and index >= 19 and index <= 24
        d.radius = air and C.airRadius or C.radius
        local dim = Activity.dimension(player)
        local interior = C.interiors[index] or 0
        local origin, h
        if r.start then
            origin, h = { r.start[1], r.start[2], r.start[3] }, r.start[4]
        else
            origin, h = r.checkpoints[1], heading(r.checkpoints[1], r.checkpoints[2])
        end
        local rad = math.rad(h)
        local fx, fy, rx, ry = -math.sin(rad), math.cos(rad), math.cos(rad), math.sin(rad)
        d.racers = {}
        setElementInterior(player, interior)
        setElementDimension(player, dim)
        for i = 0, r.racers - 1 do
            local back = math.floor(i / 2) * C.gridBack + 3
            local side = (i % 2 == 0) and -C.gridSide or C.gridSide
            local x, y = origin[1] - fx * back + rx * side, origin[2] - fy * back + ry * side
            local car = session:vehicle(r.cars[i + 1] or r.cars[1], x, y, origin[3] + (air and 0 or 1), h)
            setElementInterior(car, interior)
            setElementDimension(car, dim)
            setElementFrozen(car, true)
            local racer = { vehicle = car, next = 1 }
            if i == 0 then
                warpPedIntoVehicle(player, car)
                racer.player = true
                d.me = racer
            else
                local ped = session:ped(C.drivers[math.random(#C.drivers)], x, y, origin[3] + 2)
                setElementInterior(ped, interior)
                setElementDimension(ped, dim)
                warpPedIntoVehicle(ped, car)
                setElementSyncer(ped, player, true, true)
                setElementSyncer(car, player, true, true)
                racer.ped = ped
            end
            d.racers[#d.racers + 1] = racer
        end
        session:big(def and def.name or raceName(index), 3000, "title")
        for i, n in ipairs({ "RACES_4", "RACES_5", "RACES_6" }) do
            session:after(1000 + i * 1000, function(s) s:big(Activity.text(n, "RACETOR"), 900, "title") end)
        end
        session:after(4000, function(s)
            local dd = s.data
            dd.go = getTickCount()
            s:big(Activity.text("RACES_7", "RACETOR"), 1500, "title")
            for _, racer in ipairs(dd.racers) do if isElement(racer.vehicle) then setElementFrozen(racer.vehicle, false) end end
            s:counter("time", Activity.text("RACES31", "RACETOR"), 0, "timer", true)
            triggerClientEvent(s.player, "vana-race:go", resourceRoot, dd.course, dd.racers, dd.radius, C.aiSpeed, air, dim)
        end)
        session:every(250, function(s)
            local dd = s.data
            if not dd.go then return end
            -- Disqualified for leaving the vehicle too long or wrecking it (vanilla).
            local v = getPedOccupiedVehicle(s.player)
            if not isElement(dd.me.vehicle) or isVehicleBlown(dd.me.vehicle) then return s:fail("RACES24") end
            if v ~= dd.me.vehicle then
                dd.outSince = dd.outSince or getTickCount()
                if getTickCount() - dd.outSince > C.outMs then return s:fail("RACES20") end
                if not dd.warned then
                    dd.warned = true
                    s:say(s:text("RACES21", math.floor(C.outMs / 1000)), 3000)
                end
            else
                dd.outSince, dd.warned = nil, nil
            end
            -- Checkpoints (opponents' vehicles are synced by this player's client).
            for _, racer in ipairs(dd.racers) do
                local cp = dd.course[racer.next]
                if cp and not racer.finished and isElement(racer.vehicle) then
                    local x, y, z = getElementPosition(racer.vehicle)
                    if getDistanceBetweenPoints3D(x, y, z, cp[1], cp[2], cp[3]) < dd.radius then
                        racer.next = racer.next + 1
                        if racer.player then triggerClientEvent(s.player, "vana-race:checkpoint", resourceRoot, racer.next) end
                        if racer.next > #dd.course then racer.finished = getTickCount() end
                    end
                end
            end
            standings(s)
            local laps = (dd.def or RaceTable[dd.index]).laps
            s:counter("position", Activity.text("RACES30", "RACETOR"), ("%d/%d"):format(dd.me.position or 1, #dd.racers), "number")
            if laps > 1 then
                local per = #dd.course / laps
                s:counter("lap", "LAP", ("%d/%d"):format(math.min(laps, math.floor((dd.me.next - 1) / per) + 1), laps), "number")
            end
            if dd.me.finished and not dd.over then
                dd.over = true
                finishRace(s)
            end
        end)
    end,
    stop = function(session)
        local player = session.player
        local d = session.data
        if not isElement(player) then return end
        triggerClientEvent(player, "vana-race:go", resourceRoot, nil)
        local e = d.entry
        setTimer(function()
            if not isElement(player) then return end
            if getPedOccupiedVehicle(player) then removePedFromVehicle(player) end
            setElementDimension(player, 0)
            setElementInterior(player, 0, e.x, e.y, e.z + 1)
            setElementPosition(player, e.x + 1.5, e.y, e.z + 1)
        end, 300, 1)
    end,
})

local function openMenu(player, entry)
    local items = {}
    for i, index in ipairs(entry.races) do
        local best = Activity.progress(player, "race." .. index .. ".best")
        items[i] = { label = raceName(index), right = best and ordinal(best) or Activity.text("RACES45", "RACETOR") }
    end
    if entry.also == "kickstart" then items[#items + 1] = { label = Activity.text("STAD_02", "KICKSTT") } end
    Activity.menu(player, Activity.text("RACES_0", "RACETOR"), items, function(p, choice)
        if Activity.of(p) then return end
        local x, y, z = getElementPosition(p)
        if getDistanceBetweenPoints3D(x, y, z, entry.x, entry.y, entry.z + 1) > 6 then return end
        local index = entry.races[choice]
        if index then Activity.start(p, "race", index, entry) elseif entry.also then Activity.start(p, entry.also, entry) end
    end)
end

-- The Chiliad Challenge: the race engine with a route of vanilla's three, on mountain bikes.
local function chiliadRace(player, route)
    local M = C.chiliad
    local cars = {}
    for i = 1, M.racers do cars[i] = M.bike end
    return { racers = M.racers, laps = 1, cars = cars, checkpoints = ChiliadRoutes[route],
             name = Activity.text(M.names[route], "RACETOR"), key = "chiliad." .. route, prize = M.prizes[route],
             onWin = function(session) session:after(3000, function(s) s:help(Activity.text(M.wins[route], "RACETOR")) end) end }
end

local function openChiliad(player)
    local M = C.chiliad
    local items, open = {}, true
    for route = 1, #ChiliadRoutes do
        local best = Activity.progress(player, "chiliad." .. route .. ".best")
        items[route] = { label = Activity.text(M.names[route], "RACETOR"), right = best and ordinal(best) or (open and "" or "locked"), enabled = open }
        open = Activity.progress(player, "chiliad." .. route .. ".won") == true
    end
    Activity.menu(player, Activity.text("MTBIKER", "RACETOR"), items, function(p, route)
        if Activity.of(p) then return end
        Activity.start(p, "race", 100 + route, M.entry, chiliadRace(p, route))
    end)
end

addEventHandler("onResourceStart", resourceRoot, function()
    local e = C.chiliad.entry
    local cm = createMarker(e.x, e.y, e.z - 0.5, "cylinder", 4, 255, 200, 0, 110)
    MapPoints.set("chiliad", { category = "race", x = e.x, y = e.y, z = e.z })
    Prompts.add(cm, { text = "race down Mount Chiliad", vehicle = true, use = function(player)
        local v = getPedOccupiedVehicle(player)
        if v and getElementModel(v) == C.chiliad.bike and not Activity.of(player) then openChiliad(player) end
    end })
    for i, car in ipairs(C.stadiumCars) do OwnedCars.define("stadium" .. i, car) end
    for _, entry in ipairs(C.entries) do
        local m = createMarker(entry.x, entry.y, entry.z - 0.1, "cylinder", 1.5, 255, 200, 0, 120)
        MapPoints.set(("race:%d:%d"):format(entry.x, entry.y), { category = entry.races[1] >= 25 and "stadium" or "race", x = entry.x, y = entry.y, z = entry.z })
        Prompts.add(m, { text = "race", use = function(player)
            if not Activity.of(player) then openMenu(player, entry) end
        end })
    end
end)

Activity.test("races", function()
    local count, cps = 0, 0
    for _, r in pairs(RaceTable) do count = count + 1 cps = cps + #r.checkpoints end
    return count == 27 and Gxt.raw("RACE00") ~= nil, ("%d races, %d checkpoints"):format(count, cps)
end)
