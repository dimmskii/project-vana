-- Schools (vanilla DSKOOL / BSKOOL / BOAT / DESERT5): walk into the school's marker to pick a test.
-- Tests unlock in order (pass one at 70%+ for the next), run in the player's private dimension, and are
-- judged on the player's client (schools/client.lua), which knows the vehicle best; the server keeps
-- the best scores, medals, skill gains and vanilla's reward vehicles. Progress: "school.<school>.<test>".
local R = SchoolRules

local function medalOf(score)
    local medal = 0
    for i, threshold in ipairs(R.medals) do if score >= threshold then medal = i end end
    return medal
end

local function bestOf(player, school, test)
    return Activity.progress(player, ("school.%s.%s"):format(school, test.key)) or 0
end

-- The menu for a player: each test with its best score and whether it's open yet.
local function menuFor(player, schoolKey)
    local school = Schools[schoolKey]
    local items, open = {}, true
    for i, test in ipairs(school.tests) do
        local best = bestOf(player, schoolKey, test)
        items[i] = { index = i, title = Activity.text(test.title, school.gxt), best = best, medal = medalOf(best), open = open }
        open = best >= R.medals[1]
    end
    return items
end

local function frame(origin)
    local h = math.rad(origin[4] or 0)
    return { x = origin[1], y = origin[2], z = origin[3], heading = origin[4] or 0,
             fx = -math.sin(h), fy = math.cos(h), rx = math.cos(h), ry = math.sin(h) }
end

local function at(f, offset)
    return f.x + offset[1] * f.rx + offset[2] * f.fx, f.y + offset[1] * f.ry + offset[2] * f.fy
end

-- Builds the test's props in the private dimension: cones, parked cars, ramps, the PIT target.
local function build(session, test, f, dim)
    local props = { cones = {} }
    local function place(element)
        setElementDimension(element, dim)
        return element
    end
    local function cone(x, y)
        local o = place(session:object(1238, x, y, f.z - 0.3))
        props.cones[#props.cones + 1] = o
    end
    local c = test.circle
    if c then
        local cx, cy = at(f, c.at)
        for i = 0, c.count - 1 do
            local a = math.rad((c.from or 0) + i * (c.step or (360 / c.count)) + f.heading)
            cone(cx + math.sin(a) * c.radius, cy + math.cos(a) * c.radius)
        end
    end
    if test.kind == "laps" then
        for _, e in ipairs(test.ends) do
            local cx, cy = at(f, e)
            for i = 0, 9 do
                local a = math.rad(i * 36)
                cone(cx + math.sin(a) * 2, cy + math.cos(a) * 2)
            end
        end
    elseif test.kind == "coil" then
        for i = 1, test.gates do
            local x, y = at(f, { (i % 2 == 0) and 2 or -2, 10 + i * 10 })
            cone(x, y)
        end
        local cx, cy = at(f, test.turn)
        cone(cx, cy)
    end
    for _, p in ipairs(test.parked or {}) do
        local x, y = at(f, p)
        local car = place(session:vehicle(test.vehicle, x, y, f.z + 0.5, (f.heading + 90) % 360))
        props.parked = props.parked or {}
        table.insert(props.parked, car)
    end
    if test.ramp then
        local x, y = at(f, test.ramp)
        props.ramp = place(session:object(test.kind == "twowheels" and 1503 or 1634, x, y, f.z - 0.4, 0, 0, f.heading))
    end
    local function buoy(x, y)
        local o = place(session:object(1243, x, y, 0.2))
        return o
    end
    if test.gates or test.world then -- a pair of buoys per gate
        local list = test.world or {}
        if not test.world then
            for i, g in ipairs(test.gates) do list[i] = { at(f, g) } end
        end
        for _, g in ipairs(list) do
            local gx, gy = g[1], g[2]
            buoy(gx + f.rx * test.width / 2, gy + f.ry * test.width / 2)
            buoy(gx - f.rx * test.width / 2, gy - f.ry * test.width / 2)
        end
    end
    if test.region then
        local cx, cy = at(f, test.region)
        for _, d in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
            buoy(cx + f.rx * d[1] * test.width / 2 + f.fx * d[2] * test.depth / 2, cy + f.ry * d[1] * test.width / 2 + f.fy * d[2] * test.depth / 2)
        end
    end
    if test.kind == "fishjump" then
        local x, y = at(f, test.ramp)
        props.ramp = place(session:object(1655, x, y, 0, 0, 0, f.heading))
    end
    if test.section then -- cones along both sides of the section
        for fwd = test.section[1], test.section[2], 7 do
            for _, side in ipairs({ -test.width, test.width }) do
                local x, y = at(f, { side, fwd })
                cone(x, y)
            end
        end
    end
    for _, p in ipairs(test.trucks or {}) do
        local truck = place(session:vehicle(514, p[1], p[2], p[3] + 1, 90))
        props.trucks = props.trucks or {}
        table.insert(props.trucks, truck)
    end
    if test.target and test.target.model then
        local x, y = at(f, test.target.at)
        local car = place(session:vehicle(test.target.model, x, y, f.z + 0.5, f.heading))
        local driver = place(session:ped(280, x, y, f.z + 2))
        warpPedIntoVehicle(driver, car)
        setElementSyncer(car, session.player, true, true)
        props.target = car
    end
    return props
end

Activity.register("school", {
    title = "School",
    start = function(session, schoolKey, index)
        local school = Schools[schoolKey]
        local test = school.tests[index]
        local player = session.player
        local d = session.data
        d.school, d.index, d.test = schoolKey, index, test
        local origin = test.from or school.start
        local f = frame(origin)
        local dim = Activity.dimension(player)
        setElementInterior(player, 0)
        setElementDimension(player, dim)
        local vehicle
        if test.vehicle then
            vehicle = session:vehicle(test.vehicle, f.x, f.y, f.z + 0.6, f.heading)
            setElementDimension(vehicle, dim)
            warpPedIntoVehicle(player, vehicle)
            -- Starts in the air (vanilla): planes already flying level, helicopters hovering.
            if f.z > 40 and getVehicleType(vehicle) == "Plane" then
                setElementVelocity(vehicle, f.fx * 0.7, f.fy * 0.7, 0)
            end
        else
            -- Parachuting: out of the plane, chute on your back.
            setElementPosition(player, f.x, f.y, f.z)
            giveWeapon(player, 46, 1, true)
        end
        d.vehicle = vehicle
        local props = build(session, test, f, dim)
        session:big(Activity.text(test.title, school.gxt), 3000, "title")
        session:help(Activity.text(test.help, school.gxt))
        d.started = getTickCount()
        triggerClientEvent(player, "vana-school:run", resourceRoot, schoolKey, index, vehicle, props, origin)
        session:counter("time", "TIME", test.timeMs, "timer")
        session:after(test.timeMs + 5000, function(s)
            -- The client should have reported by now; if not, the test is failed.
            s:stop("timeout")
        end)
    end,
    stop = function(session, reason)
        local player = session.player
        local d = session.data
        if not isElement(player) then return end
        triggerClientEvent(player, "vana-school:run", resourceRoot, nil)
        if reason == "quit" then return end
        local m = Schools[d.school].menu
        setTimer(function()
            if not isElement(player) then return end
            if getPedOccupiedVehicle(player) then removePedFromVehicle(player) end
            setElementDimension(player, 0)
            setElementInterior(player, m.interior or 0, m[1], m[2], m[3] + 1)
            setElementPosition(player, m[1], m[2] + 1.5, m[3] + 1)
        end, reason == "result" and 4500 or 500, 1)
    end,
})

addEvent("vana-school:result", true)
addEventHandler("vana-school:result", resourceRoot, function(score)
    local player = client
    local session = Activity.of(player)
    if not session or session.name ~= "school" or type(score) ~= "number" then return end
    local d = session.data
    if getTickCount() - d.started < 2000 then return end
    score = math.max(0, math.min(100, math.floor(score + 0.5)))
    local school = Schools[d.school]
    local key = ("school.%s.%s"):format(d.school, d.test.key)
    local best = Activity.progress(player, key) or 0
    local medal = medalOf(score)
    local lines = { ("%d%%"):format(score) }
    if score > best then
        Activity.setProgress(player, key, score)
        lines[#lines + 1] = Activity.text("DS1_46", "DS")
        if best < R.medals[1] and score >= R.medals[1] and school.skill then
            setPedStat(player, school.skill.stat, math.min(1000, getPedStat(player, school.skill.stat) + school.skill.gain))
        end
    end
    local medalName = ({ "DS1_57", "DS1_56", "DS1_55" })[medal]
    lines[#lines + 1] = medalName and Activity.text(medalName, "DS") or Activity.text("DS1_68", "DS")
    session:big(table.concat(lines, "~n~"), 4500, score >= R.medals[1] and "passed" or "failed")
    -- Vanilla's rewards: every test at bronze, silver, gold.
    for _, reward in ipairs(school.rewards or {}) do
        local all = true
        for _, test in ipairs(school.tests) do
            local s = (test == d.test) and math.max(score, best) or bestOf(player, d.school, test)
            if s < R.medals[reward.medal] then all = false break end
        end
        if all and OwnedCars.grant(player, d.school .. reward.medal) then
            triggerClientEvent(player, "vana-activities:help", resourceRoot, Activity.text("DS1_47", "DS"), false)
        end
    end
    session:stop("result")
end)

addEvent("vana-school:choose", true)
addEventHandler("vana-school:choose", resourceRoot, function(schoolKey, index)
    local player = client
    local school = Schools[schoolKey]
    if not school or Activity.of(player) or type(index) ~= "number" then return end
    local m = school.menu
    local x, y, z = getElementPosition(player)
    if getDistanceBetweenPoints3D(x, y, z, m[1], m[2], m[3] + 1) > 6 then return end
    local item = menuFor(player, schoolKey)[index]
    if item and item.open then Activity.start(player, "school", schoolKey, index) end
end)

addEventHandler("onResourceStart", resourceRoot, function()
    for key, school in pairs(Schools) do
        for _, reward in ipairs(school.rewards or {}) do
            OwnedCars.define(key .. reward.medal, reward)
        end
        local m = school.menu
        if (m.interior or 0) == 0 then MapPoints.set("school:" .. key, { category = "school", x = m[1], y = m[2], z = m[3], label = school.title }) end
        local marker = createMarker(m[1], m[2], m[3] - 0.1, "cylinder", 1.2, 255, 200, 0, 120)
        setElementInterior(marker, m.interior or 0)
        addEventHandler("onMarkerHit", marker, function(player, matching)
            if matching and getElementType(player) == "player" and not getPedOccupiedVehicle(player) and not Activity.of(player) then
                triggerClientEvent(player, "vana-school:menu", resourceRoot, key, school.title, menuFor(player, key))
            end
        end)
    end
end)

Activity.test("schools", function()
    local tests, missing = 0, {}
    for key, school in pairs(Schools) do
        for _, test in ipairs(school.tests) do
            tests = tests + 1
            if not Gxt.raw(test.title, school.gxt) then missing[#missing + 1] = test.title end
        end
    end
    return #missing == 0, ("%d tests%s"):format(tests, #missing > 0 and (", missing " .. table.concat(missing, " ")) or "")
end)
