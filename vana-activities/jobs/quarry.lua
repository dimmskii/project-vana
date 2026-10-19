-- Quarry (vanilla QUARRY): press enter/exit on the marker at the Hunter Quarry site office. Seven missions in
-- turn, each paying more (vanilla $500 .. $10000): the cop's body, clearing rocks, bombs, burning the
-- bombers, explosives to the airstrip, the spill on the tracks, and the thieves. All seven earn
-- vanilla's reward, a dumper and a bulldozer always at the quarry. Pushed objects only move on the
-- pushing player's client, so it reports what reached where (jobs/quarry_client.lua).
local Q = Jobs.quarry
local M = Q.models

local function watch(session, list)
    triggerClientEvent(session.player, "vana-quarry:watch", resourceRoot, list)
end

local function object(session, model, p, rz)
    local o = session:object(model, p[1], p[2], p[3], 0, 0, rz or math.random(0, 359))
    return o
end

local function marker(session, p, size)
    session.data.targets = session.data.targets or {}
    local m = session:marker("cylinder", p[1], p[2], p[3] - 1, size or 5, 255, 255, 0, 100)
    local b = session:blip(p, 0, 255, 255, 0)
    return { m, b }
end

local function clearMarker(session, pair)
    for _, e in ipairs(pair or {}) do if isElement(e) then destroyElement(session:disown(e)) end end
end

local function timer(session, label, ms)
    session.data.deadline = getTickCount() + ms
    session:counter("time", session:text(label), ms, "timer")
end

local function near(element, p, radius)
    if not isElement(element) then return false end
    local x, y, z = getElementPosition(element)
    return getDistanceBetweenPoints3D(x, y, z, p[1], p[2], p[3]) < radius
end

local function passed(session)
    local d = session.data
    local player = session.player
    local pay = Q.pay[d.mission]
    local count = (Activity.progress(player, "quarry.next") or 1)
    local elapsed = getTickCount() - d.started
    local best = Activity.progress(player, "quarry.best." .. d.mission)
    if not best or elapsed < best then Activity.setProgress(player, "quarry.best." .. d.mission, elapsed) end
    if d.mission == count then
        if count == #Q.pay then
            Activity.setProgress(player, "quarry.next", 1)
            Activity.grantPerk(player, "quarry")
            session:after(500, function(s) s:help(s:text("QUAR_H3")) end)
            return session:pass("QUAR_P2", pay)
        end
        Activity.setProgress(player, "quarry.next", count + 1)
        if count == 1 then session:help(session:text("QUAR_P1")) end
    end
    session:pass(nil, pay)
end

-- Each mission: setup(session), then tick(session) every 500 ms, and the client's reports.
local Missions = {}

Missions[1] = { -- the cop's body
    setup = function(s)
        local c, d = Q.cop, s.data
        d.dozer = s:vehicle(Q.dozer, c.dozer[1], c.dozer[2], c.dozer[3] + 1, c.dozer[4])
        d.dumper = s:vehicle(Q.dumper, c.dumper[1], c.dumper[2], c.dumper[3] + 1, c.dumper[4])
        d.body = object(s, M.body, c.body)
        d.bike = s:vehicle(Q.copBike, c.bike[1], c.bike[2], c.bike[3] + 1, 0)
        d.area = marker(s, c.pickup, 8)
        d.stage = "push"
        timer(s, "QUAR_D1", c.timeMs)
        s:say(s:text("QUAR_00"), 8000)
        watch(s, { { object = d.body, target = c.pickup, radius = 8 } })
    end,
    report = function(s, i) s.data.bodyIn = true end,
    tick = function(s)
        local c, d = Q.cop, s.data
        if d.stage == "push" and d.bodyIn and near(d.bike, c.pickup, 9) then
            -- Vanilla: the crane loads them into the dumper. Ours: they go aboard.
            destroyElement(s:disown(d.body))
            destroyElement(s:disown(d.bike))
            local load = s:object(M.ammo, 0, 0, 0)
            attachElements(load, d.dumper, 0, -1.5, 1.2)
            clearMarker(s, d.area)
            d.stage = "dumper"
            s:say(s:text("QUAR_07"))
            s:blip(d.dumper, 0, 80, 120, 255, 2)
        elseif d.stage == "dumper" and getPedOccupiedVehicle(s.player) == d.dumper then
            d.stage, d.area = "entrance", marker(s, Q.entrance, 6)
            s:say(s:text("QUAR_08"))
        elseif d.stage == "entrance" and near(d.dumper, Q.entrance, 8) then
            clearMarker(s, d.area)
            d.stage, d.area = "water", marker(s, c.water, 8)
            s:say(s:text("QUAR_09"))
            s:help(s:text("QUAR_H4"))
        elseif d.stage == "water" and near(d.dumper, c.water, 12) and getPedOccupiedVehicle(s.player) == d.dumper then
            passed(s)
        end
    end,
}

Missions[2] = { -- rocks
    setup = function(s)
        local d = s.data
        d.dozer = s:vehicle(Q.dozer, Q.depot[1], Q.depot[2], Q.depot[3] + 1, Q.depot[4])
        d.left = #Q.rocks.items
        local list = {}
        for i, r in ipairs(Q.rocks.items) do
            local rock = object(s, M.rock, r)
            list[i] = { object = rock, target = r.target, radius = 5 }
            s:blip(rock, 0, 80, 220, 80, 1)
            s:marker("checkpoint", r.target[1], r.target[2], r.target[3], 5, 255, 255, 0, 100)
        end
        timer(s, "QUAR_D2", Q.rocks.timeMs)
        s:say(s:text("QUAR_11"), 8000)
        s:after(8000, function(ss) ss:say(ss:text("QUAR_12")) end)
        watch(s, list)
    end,
    report = function(s, i)
        local d = s.data
        d.left = d.left - 1
        local done = #Q.rocks.items - d.left
        s:say(s:text(done == 1 and "QUAR_14" or "QUAR_13", done, d.left), 3000)
        if d.left <= 0 then passed(s) end
    end,
    tick = function() end,
}

local function nextBomb(s)
    local d = s.data
    d.bomb = (d.bomb or 0) + 1
    local b = Q.bombs.items[d.bomb]
    if not b then return passed(s) end
    d.barrel = object(s, M.barrel, b, 0)
    d.area = marker(s, b.target, 5)
    s:blip(d.barrel, 0, 80, 220, 80, 1)
    s:say(s:text(b.line))
    timer(s, "QUAR_D3", Q.bombs.perBombMs)
    watch(s, { { object = d.barrel, target = b.target, radius = 5 } })
end

Missions[3] = { -- bombs
    setup = function(s)
        local d = s.data
        d.dozer = s:vehicle(Q.dozer, Q.depot[1], Q.depot[2], Q.depot[3] + 1, Q.depot[4])
        s:say(s:text("QUAR_15"), 7000)
        s:after(7000, nextBomb)
    end,
    report = function(s)
        local d = s.data
        clearMarker(s, d.area)
        d.deadline = nil
        s:clearCounter("time")
        s:say(s:text("QUAR_20"))
        local barrel = d.barrel
        s:after(6000, function(ss)
            if isElement(barrel) then
                local x, y, z = getElementPosition(barrel)
                createExplosion(x, y, z, 10, ss.player)
                destroyElement(ss:disown(barrel))
            end
            nextBomb(ss)
        end)
    end,
    tick = function() end,
    fail = "QUAR_F6",
}

Missions[4] = { -- the bombers' bodies
    setup = function(s)
        local c, d = Q.bodies, s.data
        d.dumper = s:vehicle(Q.dumper, c.dumper[1], c.dumper[2], c.dumper[3] + 1, c.dumper[4])
        for i = 1, 3 do
            local body = s:object(M.body, 0, 0, 0)
            attachElements(body, d.dumper, (i - 2) * 0.8, -1.8, 1.4, 0, 0, math.random(0, 180))
        end
        s:blip(d.dumper, 0, 80, 120, 255, 2)
        d.stage = "dumper"
        timer(s, "QUAR_D1", c.timeMs)
        s:say(s:text("QUAR_22"), 8000)
        triggerClientEvent(s.player, "vana-quarry:fire", resourceRoot, c.fire)
    end,
    tick = function(s)
        local c, d = Q.bodies, s.data
        if d.stage == "dumper" and getPedOccupiedVehicle(s.player) == d.dumper then
            d.stage, d.area = "entrance", marker(s, Q.entrance, 6)
            s:say(s:text("QUAR_23"))
        elseif d.stage == "entrance" and near(d.dumper, Q.entrance, 8) then
            clearMarker(s, d.area)
            d.stage, d.area = "fire", marker(s, c.fire, 8)
            s:say(s:text("QUAR_24"))
        elseif d.stage == "fire" and near(d.dumper, c.fire, 10) then
            passed(s)
        end
    end,
}

Missions[5] = { -- explosives to the airstrip
    setup = function(s)
        local c, d = Q.explosives, s.data
        d.dumper = s:vehicle(Q.dumper, Q.depot[1], Q.depot[2], Q.depot[3] + 1, Q.depot[4])
        d.load = {}
        for i = 1, 4 do
            local barrel = s:object(M.barrel, 0, 0, 0)
            attachElements(barrel, d.dumper, (i % 2 - 0.5) * 1.0, -1.2 - math.floor((i - 1) / 2) * 0.9, 1.4)
            d.load[i] = barrel
        end
        s:blip(d.dumper, 0, 80, 120, 255, 2)
        d.stage, d.area = "airstrip", marker(s, c.airstrip, 8)
        timer(s, "QUAR_D2", c.timeMs)
        s:say(s:text("QUAR_38"), 8000)
        s:help(s:text("QUAR_H1"))
    end,
    tick = function(s)
        local c, d = Q.explosives, s.data
        local health = isElement(d.dumper) and getElementHealth(d.dumper) or 0
        if d.lastHealth and d.stage == "airstrip" and d.lastHealth - health >= c.jolt then
            local x, y, z = getElementPosition(d.dumper)
            createExplosion(x, y, z, 10, s.player)
            return s:fail("QUAR_F3")
        end
        d.lastHealth = health
        if d.stage == "airstrip" and near(d.dumper, c.airstrip, 10) and Job.stopped(d.dumper) then
            for _, b in ipairs(d.load) do if isElement(b) then destroyElement(s:disown(b)) end end
            clearMarker(s, d.area)
            s:say(s:text("QUAR_26"), 3000)
            d.stage, d.area = "back", marker(s, Q.entrance, 6)
            s:after(3000, function(ss) ss:say(ss:text("QUAR_27")) end)
        elseif d.stage == "back" and near(d.dumper, Q.entrance, 8) then
            passed(s)
        end
    end,
}

Missions[6] = { -- the spill on the tracks
    setup = function(s)
        local c, d = Q.tracks, s.data
        d.dozer = s:vehicle(Q.dozer, Q.depot[1], Q.depot[2], Q.depot[3] + 1, Q.depot[4])
        d.left = #c.items
        local list = {}
        for i, p in ipairs(c.items) do
            local barrel = object(s, M.barrel, p, 0)
            s:blip(barrel, 0, 80, 220, 80, 1)
            list[i] = { object = barrel, away = p, radius = c.clear }
        end
        timer(s, "QUAR_D2", c.timeMs)
        s:say(s:text("QUAR_28"), 8000)
        s:after(c.timeMs - 30000, function(ss) ss:say(ss:text("QUAR_29")) end)
        watch(s, list)
    end,
    report = function(s)
        local d = s.data
        d.left = d.left - 1
        if d.left <= 0 then passed(s) end
    end,
    tick = function() end,
    fail = "QUAR_F6",
}

Missions[7] = { -- the thieves
    setup = function(s)
        local c, d = Q.thieves, s.data
        d.mine = s:vehicle(Q.dumper, Q.depot[1], Q.depot[2], Q.depot[3] + 1, Q.depot[4])
        d.theirs = s:vehicle(Q.dumper, c.dumper[1], c.dumper[2], c.dumper[3] + 1, c.dumper[4])
        for i = 1, 4 do
            local crate = s:object(M.crate, 0, 0, 0)
            attachElements(crate, d.theirs, (i % 2 - 0.5) * 1.0, -1.2 - math.floor((i - 1) / 2) * 0.9, 1.4)
        end
        local driver = s:ped(Jobs.vigilante.criminals[1], c.dumper[1], c.dumper[2], c.dumper[3] + 2)
        warpPedIntoVehicle(driver, d.theirs)
        setElementSyncer(driver, s.player, true, true)
        setElementSyncer(d.theirs, s.player, true, true)
        setElementData(driver, "vana:fairGame", true)
        s:blip(d.theirs, 0, 255, 40, 40, 2)
        s:say(s:text("QUAR_30"), 7000)
        triggerClientEvent(s.player, "vana-quarry:flee", resourceRoot, driver, d.theirs)
    end,
    tick = function(s)
        local c, d = Q.thieves, s.data
        if not isElement(d.theirs) or isVehicleBlown(d.theirs) then return passed(s) end
        local x, y, z = getElementPosition(s.player)
        local tx, ty, tz = getElementPosition(d.theirs)
        local dist = getDistanceBetweenPoints3D(x, y, z, tx, ty, tz)
        if dist > c.lose then return s:fail("QUAR_31") end
        if dist > c.warn and not d.warned then
            d.warned = true
            s:say(s:text("QUAR_31"), 3000)
        elseif dist < c.warn then
            d.warned = false
        end
    end,
}

-- The reward: a dumper and a bulldozer always at the quarry for those who earned it.
local rewardCars = {}
Activity.perk("quarry", function() end)
setTimer(function()
    local wanted = false
    for _, player in ipairs(getElementsByType("player")) do
        local x, y = getElementPosition(player)
        if getDistanceBetweenPoints2D(x, y, Q.start[1], Q.start[2]) < 300 and Activity.hasPerk(player, "quarry") then wanted = true end
    end
    for i, r in ipairs(Q.reward) do
        local car = rewardCars[i]
        if wanted and (not car or not isElement(car) or isVehicleBlown(car)) then
            rewardCars[i] = createVehicle(r[1], r[2], r[3], r[4] + 1, 0, 0, r[5])
            if rewardCars[i] then setElementData(rewardCars[i], "vana:managed", true, false) end
        elseif not wanted and car and isElement(car) and not getVehicleOccupant(car) then
            destroyElement(car)
            rewardCars[i] = nil
        end
    end
end, 3000, 0)

addEvent("vana-quarry:reached", true)
addEventHandler("vana-quarry:reached", resourceRoot, function(index)
    local session = Activity.of(client)
    if not session or session.name ~= "quarry" or type(index) ~= "number" then return end
    local d = session.data
    d.reached = d.reached or {}
    if d.reached[index] then return end
    d.reached[index] = true
    local m = Missions[d.mission]
    if m.report then m.report(session, index) end
end)

Activity.register("quarry", {
    title = "QUARRY",
    gxt = "QUARRY",
    start = function(session)
        local d = session.data
        d.mission = Activity.progress(session.player, "quarry.next") or 1
        d.started = getTickCount()
        local m = Missions[d.mission]
        local best = Activity.progress(session.player, "quarry.best." .. d.mission)
        if best then session:help(session:text("QUAR_H2")) end
        m.setup(session)
        session:every(500, function(s)
            local dd = s.data
            for _, key in ipairs({ "dozer", "dumper", "mine" }) do
                local v = dd[key]
                if v and (not isElement(v) or isVehicleBlown(v)) then return s:fail(key == "dozer" and "QUAR_F1" or "QUAR_F2") end
            end
            if dd.deadline and getTickCount() > dd.deadline then
                return s:fail(m.fail or (dd.mission == 4 or dd.mission == 1) and "QUAR_F4" or "QUAR_F5")
            end
            m.tick(s)
        end)
    end,
    stop = function(session)
        if isElement(session.player) then
            triggerClientEvent(session.player, "vana-quarry:watch", resourceRoot, nil)
            triggerClientEvent(session.player, "vana-quarry:fire", resourceRoot, nil)
        end
    end,
})

addEventHandler("onResourceStart", resourceRoot, function()
    local p = Q.start
    local m = createMarker(p[1], p[2], p[3] - 1, "cylinder", 1.5, 255, 200, 0, 120)
    MapPoints.set("quarry", { category = "quarry", x = p[1], y = p[2], z = p[3] })
    Prompts.add(m, { text = "start quarry work", use = function(player)
        if not Activity.of(player) then Activity.start(player, "quarry") end
    end })
end)

Activity.test("quarry", function()
    return #Q.rocks.items == 7 and #Q.bombs.items == 4 and Gxt.raw("QUAR_00", "QUARRY") ~= nil, "7 missions"
end)
