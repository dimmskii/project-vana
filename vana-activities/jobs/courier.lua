-- Courier (vanilla BCOUR): ride the city's courier bike into the pick-up point. Throw items (hold look
-- left or right, press fire) through the drop-off coronas before time runs out, then ride back for your
-- cut: time left / 100 x level, plus $100 per item to spare. Four levels per city. The throwing is
-- client-side physics (jobs/courier_client.lua), which reports deliveries.
local C = Jobs.courier

local function cityFor(session) return C.cities[session.data.city] end

local function startLevel(session)
    local d = session.data
    local city = cityFor(session)
    local lv = C.levels[d.level]
    d.items, d.left = lv.items, lv.quota
    local pool = {}
    for i = 1, #city.drops do pool[i] = i end
    for i = #pool, 2, -1 do local j = math.random(i) pool[i], pool[j] = pool[j], pool[i] end
    d.drops = {}
    for i = 1, lv.quota do
        local p = city.drops[pool[i]]
        d.drops[i] = { p = p, marker = session:marker("corona", p[1], p[2], p[3] + 1.5, 3, 255, 255, 0, 160),
                       blip = session:blip(p, 0, 255, 255, 0, 1) }
    end
    d.deadline = getTickCount() + lv.timeMs
    session:counter("items", session:text("BCOU_8"), d.items, "number")
    session:counter("time", session:text("BCOU_22"), lv.timeMs, "timer")
    session:big(("~y~%s~n~~w~Level %d"):format(session:text(city.name), d.level), 3000, "title")
    session:say(session:text("BCOU_4"), 6000)
    session:after(6000, function(s) s:help(s:text("BCOU_9")) end)
    local list = {}
    for i, drop in ipairs(d.drops) do list[i] = drop.p end
    triggerClientEvent(session.player, "vana-courier:drops", resourceRoot, list, C.packet, city.bike)
end

local function finishLevel(session)
    local d = session.data
    local city = cityFor(session)
    local left = math.max(0, d.deadline - getTickCount())
    local pay = math.floor(left / 100) * d.level + d.items * C.sparePay
    givePlayerMoney(session.player, pay)
    session:big(session:text("BCOU_7", pay), 4000, "small")
    local best = Activity.progress(session.player, "courier." .. d.city) or 0
    if d.level > best then Activity.setProgress(session.player, "courier." .. d.city, d.level) end
    if d.level >= #C.levels then return session:pass(nil, 0) end
    d.level = d.level + 1
    session:after(4500, startLevel)
end

addEvent("vana-courier:thrown", true)
addEventHandler("vana-courier:thrown", resourceRoot, function(dropIndex)
    local session = Activity.of(client)
    local d = session and session.name == "courier" and session.data
    if not d or not d.drops or d.returning or d.items <= 0 then return end
    local now = getTickCount()
    if d.lastThrow and now - d.lastThrow < 400 then return end
    d.lastThrow = now
    if dropIndex == nil then
        d.items = d.items - 1
    else
        local drop = d.drops[dropIndex]
        if not drop or drop.done then return end
        local x, y, z = getElementPosition(client)
        if getDistanceBetweenPoints3D(x, y, z, drop.p[1], drop.p[2], drop.p[3]) > 40 then return end
        d.items = d.items - 1
        drop.done = true
        destroyElement(session:disown(drop.marker))
        destroyElement(session:disown(drop.blip))
        d.left = d.left - 1
        session:say(session:text("BCOU_5"), 3000)
    end
    session:counter("items", session:text("BCOU_8"), d.items, "number")
    if d.left <= 0 then
        d.returning = true
        local back = cityFor(session).back
        d.back = { back, session:marker("cylinder", back[1], back[2], back[3], 3, 255, 255, 0, 120), session:blip(back, 0, 255, 255, 0) }
        session:say(session:text("BCOU_6"))
        triggerClientEvent(session.player, "vana-courier:drops", resourceRoot, nil)
    elseif d.items < d.left then
        session:fail("BCOU_11")
    end
end)

Activity.register("courier", {
    title = "Courier",
    gxt = "BCOU",
    start = function(session, city)
        local d = session.data
        d.city, d.level = city, 1
        session:after(500, startLevel)
        session:every(500, function(s)
            local dd = s.data
            local bike = Job.watchVehicle(s, { [cityFor(s).bike] = true }, C.outMs, "BCOU_35")
            if not bike then return end
            if dd.deadline and getTickCount() > dd.deadline and not dd.returning then return s:fail("BCOU_35") end
            if dd.returning then
                local b = dd.back[1]
                local x, y, z = getElementPosition(bike)
                if getDistanceBetweenPoints3D(x, y, z, b[1], b[2], b[3]) < 5 then
                    destroyElement(s:disown(dd.back[2]))
                    destroyElement(s:disown(dd.back[3]))
                    dd.returning, dd.drops = false, nil
                    finishLevel(s)
                end
            end
        end)
    end,
    stop = function(session)
        if isElement(session.player) then triggerClientEvent(session.player, "vana-courier:drops", resourceRoot, nil) end
    end,
})

-- Start points: the courier bike ridden into the pick-up point (vanilla's bikes are parked there).
local parked = {}
addEventHandler("onResourceStart", resourceRoot, function()
    for i, city in ipairs(C.cities) do
        local b = city.base
        local m = createMarker(b[1], b[2], b[3] - 0.5, "cylinder", 2.5, 255, 200, 0, 110)
        createBlip(b[1], b[2], b[3], 0, 2, 255, 200, 0, 255, 0, 400)
        addEventHandler("onMarkerHit", m, function(player, matching)
            local bike = isElement(player) and getElementType(player) == "player" and getPedOccupiedVehicle(player)
            if matching and bike and getElementModel(bike) == city.bike and not Activity.of(player) then
                Activity.start(player, "courier", i)
            end
        end)
    end
    setTimer(function()
        for i, city in ipairs(C.cities) do
            local car = parked[i]
            if not car or not isElement(car) or isVehicleBlown(car) or getDistanceBetweenPoints2D(city.base[1], city.base[2], getElementPosition(car)) > 50 and not getVehicleOccupant(car) then
                if car and isElement(car) and not getVehicleOccupant(car) then destroyElement(car) end
                parked[i] = createVehicle(city.bike, city.base[1] + 3, city.base[2] + 3, city.base[3] + 1)
            end
        end
    end, 10000, 0)
end)

Activity.test("courier", function()
    local drops = 0
    for _, c in ipairs(C.cities) do drops = drops + #c.drops end
    return drops > 40 and Gxt.raw("BCOU_4", "BCOU") ~= nil, ("%d drop-offs in 3 cities"):format(drops)
end)
