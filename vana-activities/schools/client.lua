-- Schools, the player's side: the test menu, and the test runner, which watches the vehicle (heading,
-- wheels, roll, damage, knocked cones) and reports a score for the server to record.
local R = SchoolRules
local menu  -- { school, title, items, selected }
local run   -- the running test

-- The menu ------------------------------------------------------------------------------------------
addEvent("vana-school:menu", true)
addEventHandler("vana-school:menu", resourceRoot, function(school, title, items)
    menu = { school = school, title = title, items = items, selected = 1 }
    toggleAllControls(false, true, false)
end)

local function closeMenu()
    menu = nil
    toggleAllControls(true, true, false)
end

addEventHandler("onClientKey", root, function(key, pressed)
    if not menu or not pressed then return end
    if key == "arrow_u" then menu.selected = (menu.selected - 2) % #menu.items + 1
    elseif key == "arrow_d" then menu.selected = menu.selected % #menu.items + 1
    elseif key == "enter" or key == "num_enter" then
        local item = menu.items[menu.selected]
        if item and item.open then
            triggerServerEvent("vana-school:choose", resourceRoot, menu.school, item.index)
            closeMenu()
        end
    elseif key == "backspace" or key == "escape" then closeMenu()
    else return end
    cancelEvent()
end)

local MEDALS = { "Bronze", "Silver", "Gold" }
local MEDAL_COLOURS = { tocolor(205, 127, 50), tocolor(200, 200, 210), tocolor(240, 200, 60) }

addEventHandler("onClientRender", root, function()
    if not menu then return end
    local _, sh = guiGetScreenSize()
    local s = sh / 720
    local x, y, w, row = 40 * s, 120 * s, 420 * s, 26 * s
    dxDrawRectangle(x, y, w, row * (#menu.items + 2.6), tocolor(0, 0, 0, 190))
    dxDrawText(menu.title, x + 12 * s, y + 6 * s, x + w, y + row, tocolor(172, 203, 241), 1.4 * s, "bankgothic")
    for i, item in ipairs(menu.items) do
        local ry = y + row * (i + 0.4)
        if i == menu.selected then dxDrawRectangle(x + 4 * s, ry, w - 8 * s, row, tocolor(172, 203, 241, 60)) end
        local colour = item.open and (i == menu.selected and tocolor(255, 255, 255) or tocolor(180, 180, 180)) or tocolor(90, 90, 90)
        dxDrawText(item.title, x + 12 * s, ry, x + w, ry + row, colour, 1.1 * s, "default-bold", "left", "center")
        local right = item.open and (item.best > 0 and ("%d%%"):format(item.best) or "-") or "locked"
        dxDrawText(right, x, ry, x + w - 90 * s, ry + row, colour, 1.1 * s, "default-bold", "right", "center")
        if item.medal > 0 then
            dxDrawText(MEDALS[item.medal], x, ry, x + w - 12 * s, ry + row, MEDAL_COLOURS[item.medal], 1.1 * s, "default-bold", "right", "center")
        end
    end
    local by = y + row * (#menu.items + 1.5)
    dxDrawText("Enter: start   Backspace: leave   (70% to pass)", x + 12 * s, by, x + w, by + row, tocolor(200, 200, 200), 1 * s, "default", "left", "center")
end)

-- Helpers ---------------------------------------------------------------------------------------------
local function angleDiff(a, b)
    local d = (a - b) % 360
    return d > 180 and 360 - d or d
end

local function headingOf(vehicle)
    local _, _, rz = getElementRotation(vehicle)
    return rz
end

local function speedOf(vehicle)
    local vx, vy, vz = getElementVelocity(vehicle)
    return math.sqrt(vx * vx + vy * vy + vz * vz) * 50
end

local function frame(origin)
    local h = math.rad(origin[4] or 0)
    return { x = origin[1], y = origin[2], z = origin[3], heading = origin[4] or 0,
             fx = -math.sin(h), fy = math.cos(h), rx = math.cos(h), ry = math.sin(h) }
end

local function at(f, offset)
    return f.x + offset[1] * f.rx + offset[2] * f.fx, f.y + offset[1] * f.ry + offset[2] * f.fy
end

local function distTo(vehicle, x, y)
    local vx, vy = getElementPosition(vehicle)
    return getDistanceBetweenPoints2D(vx, vy, x, y)
end

local function timeScore(used, target)
    if used <= target then return 100 end
    local over = (used - target) / target
    if over <= 1 then return 100 - over * (100 - R.lateFloor) end
    return math.max(0, R.lateFloor - (over - 1) * R.lateFloor)
end

local function penalties()
    local damage = math.max(0, 1000 - getElementHealth(run.vehicle)) / R.damagePerPoint
    local cones = 0
    for i, cone in ipairs(run.props.cones or {}) do
        if isElement(cone) then
            local x, y, z = getElementPosition(cone)
            local o = run.coneStart[i]
            if o and (getDistanceBetweenPoints3D(x, y, z, o[1], o[2], o[3]) > 0.4) then cones = cones + 1 end
        end
    end
    return damage + cones * R.conePenalty
end

local function finish(score)
    if not run or run.done then return end
    run.done = true
    triggerServerEvent("vana-school:result", resourceRoot, math.max(0, math.min(100, score)))
end

local function placeScore(x, y, heading)
    local posErr = distTo(run.vehicle, x, y)
    local headErr = heading and angleDiff(headingOf(run.vehicle), heading) or 0
    return 100 - posErr / R.metrePerPoint - headErr / R.headingPerPoint - penalties()
end

-- Test kinds: each tick(dt) watches the vehicle and calls finish(score).
local Kinds = {}

Kinds.donut = function(t, dt)
    local h = headingOf(run.vehicle)
    run.turned = (run.turned or 0) + angleDiff(h, run.lastHeading or h)
    run.lastHeading = h
    if run.turned >= 330 and speedOf(run.vehicle) < 0.5 then
        finish(placeScore(run.f.x, run.f.y, run.f.heading))
    end
end

Kinds.turn = function(t)
    local tx, ty = at(run.f, t.turn)
    if not run.reached and distTo(run.vehicle, tx, ty) < 12 then run.reached = true end
    if run.reached and speedOf(run.vehicle) < 0.5 then
        local fx, fy = run.f.x, run.f.y
        if t.reverse then fx, fy = tx, ty end
        if distTo(run.vehicle, fx, fy) < 15 then
            finish(placeScore(fx, fy, (run.f.heading + 180) % 360))
        end
    end
end

Kinds.stopzone = function(t)
    if t.stinger and not run.popped then
        local sx, sy = at(run.f, t.stinger)
        if distTo(run.vehicle, sx, sy) < 4 then
            run.popped = true
            setVehicleWheelStates(run.vehicle, 1, -1, -1, -1)
        end
    end
    if not run.moved and distTo(run.vehicle, run.f.x, run.f.y) > 6 then run.moved = true end
    if run.moved and speedOf(run.vehicle) < 0.3 then
        local zx, zy = at(run.f, t.zone)
        finish(placeScore(zx, zy, (run.f.heading + (t.heading or 0)) % 360))
    end
end

Kinds.laps = function(t)
    local fx, fy = at(run.f, t.ends[1])
    local bx, by = at(run.f, t.ends[2])
    if not run.far and distTo(run.vehicle, fx, fy) < t.radius + 4 then run.far = true end
    if run.far and distTo(run.vehicle, bx, by) < t.radius + 4 then
        run.far = false
        run.laps = (run.laps or 0) + 1
        Hud.counter("laps", "LAP", ("%d / %d"):format(run.laps, t.laps), "number")
        if run.laps >= t.laps then
            Hud.counter("laps", nil)
            finish(timeScore(getTickCount() - run.started, t.targetMs) - penalties())
        end
    end
end

Kinds.coil = function(t)
    local tx, ty = at(run.f, t.turn)
    if not run.reached and distTo(run.vehicle, tx, ty) < t.radius + 3 then run.reached = true end
    if run.reached and distTo(run.vehicle, run.f.x, run.f.y) < 6 and speedOf(run.vehicle) < 1 then
        finish(timeScore(getTickCount() - run.started, t.targetMs) - penalties())
    end
end

Kinds.twowheels = function(t)
    local v = run.vehicle
    local fl, rl = isVehicleWheelOnGround(v, "front_left"), isVehicleWheelOnGround(v, "rear_left")
    local fr, rr = isVehicleWheelOnGround(v, "front_right"), isVehicleWheelOnGround(v, "rear_right")
    local x, y = getElementPosition(v)
    if run.lastX and ((fl and rl and not fr and not rr) or (fr and rr and not fl and not rl)) then
        run.onTwo = (run.onTwo or 0) + getDistanceBetweenPoints2D(x, y, run.lastX, run.lastY)
        Hud.counter("two", "TWO WHEELS", ("%d m"):format(run.onTwo), "number")
    elseif run.onTwo and run.onTwo > 3 and fl and rl and fr and rr then
        Hud.counter("two", nil)
        finish(run.onTwo / t.length * 100 - penalties())
    end
    run.lastX, run.lastY = x, y
    if run.onTwo and run.onTwo >= t.length then Hud.counter("two", nil) finish(100 - penalties()) end
end

Kinds.pit = function(t)
    local target = run.props.target
    if not isElement(target) then return finish(0) end
    if not run.spun then
        -- The target drives straight on until it's knocked off its line.
        local h = math.rad(run.f.heading)
        local th = headingOf(target)
        if angleDiff(th, run.f.heading) >= 90 then
            run.spun = true
        else
            local _, _, vz = getElementVelocity(target)
            setElementVelocity(target, -math.sin(h) * t.target.speed / 50, math.cos(h) * t.target.speed / 50, vz)
        end
    elseif speedOf(run.vehicle) < 0.5 and speedOf(target) < 0.5 then
        local tx, ty = getElementPosition(target)
        finish(100 - distTo(run.vehicle, tx, ty) / R.metrePerPoint / 2 - penalties())
    end
end

Kinds.roll = function(t)
    local v = run.vehicle
    local airborne = not isVehicleOnGround(v)
    local rx, ry = getElementRotation(v)
    if airborne then
        run.flew = true
        local roll = ry
        run.rolled = (run.rolled or 0) + angleDiff(roll, run.lastRoll or roll)
        run.lastRoll = roll
    else
        run.lastRoll = nil
    end
    if run.flew and not airborne and speedOf(v) < 1 then
        local upright = angleDiff(rx, 0) < 40 and angleDiff(ry, 0) < 40
        if not upright or (run.rolled or 0) < 300 then return finish(0) end
        finish(100 - angleDiff(headingOf(v), run.f.heading) / R.headingPerPoint - penalties())
    end
end

Kinds.route = function(t)
    if not run.reached then
        if not run.viaMarker then
            run.viaMarker = createMarker(t.via[1], t.via[2], t.via[3], "checkpoint", 6, 255, 255, 0, 150)
            run.viaBlip = createBlipAttachedTo(run.viaMarker, 0, 2, 255, 255, 0)
            setElementDimension(run.viaMarker, getElementDimension(localPlayer))
        end
        if distTo(run.vehicle, t.via[1], t.via[2]) < 8 then
            run.reached = true
            destroyElement(run.viaMarker) destroyElement(run.viaBlip)
            run.homeMarker = createMarker(run.f.x, run.f.y, run.f.z, "checkpoint", 6, 255, 255, 0, 150)
            run.homeBlip = createBlipAttachedTo(run.homeMarker, 0, 2, 255, 255, 0)
            setElementDimension(run.homeMarker, getElementDimension(localPlayer))
        end
    elseif distTo(run.vehicle, run.f.x, run.f.y) < 8 then
        if isElement(run.homeMarker) then destroyElement(run.homeMarker) destroyElement(run.homeBlip) end
        finish(timeScore(getTickCount() - run.started, t.targetMs) - penalties())
    end
end

-- Wheelie (front wheel up) or stoppie (rear wheel up) along the coned section, then stop in the zone.
Kinds.section = function(t)
    local v = run.vehicle
    local vx, vy = getElementPosition(v)
    -- Distance along the course and across it, in the test frame.
    local dx, dy = vx - run.f.x, vy - run.f.y
    local along, across = dx * run.f.fx + dy * run.f.fy, dx * run.f.rx + dy * run.f.ry
    local front, rear = isVehicleWheelOnGround(v, "front_left"), isVehicleWheelOnGround(v, "rear_left")
    local up = (t.wheel == "front") and (rear and not front) or (front and not rear)
    if along >= t.section[1] and along <= t.section[2] and math.abs(across) <= t.width then
        if run.lastAlong and up then run.held = (run.held or 0) + math.max(0, along - run.lastAlong) end
    end
    run.lastAlong = along
    if along > t.section[2] + 5 then run.past = true end
    if run.past and speedOf(v) < 0.3 then
        local share = (run.held or 0) / (t.section[2] - t.section[1])
        local zx, zy = at(run.f, t.zone)
        finish(share * 70 + (30 - distTo(v, zx, zy) / R.metrePerPoint * 0.3) - penalties())
    end
end

-- Over the ramp, land (in a stoppie if asked) and stop in the zone.
Kinds.jumpstop = function(t)
    local v = run.vehicle
    local airborne = not isVehicleOnGround(v)
    if airborne then run.flew = true end
    if run.flew and not airborne and not run.landed then run.landed = getTickCount() end
    if t.stoppie and run.landed and not run.stoppied then
        local front, rear = isVehicleWheelOnGround(v, "front_left"), isVehicleWheelOnGround(v, "rear_left")
        if front and not rear then run.stoppied = true end
    end
    if run.landed and speedOf(v) < 0.3 then
        if not run.flew then return finish(0) end
        local zx, zy = at(run.f, t.zone)
        local score = placeScore(zx, zy, run.f.heading)
        if t.stoppie and not run.stoppied then score = score - 30 end
        finish(score)
    end
end

-- Medal bands (vanilla times or distances) into a score: bronze 70, silver 85, gold 100.
local function medalScore(value, medals, higherBetter)
    local b, sv, g = medals[1], medals[2], medals[3]
    local function better(a, c) if higherBetter then return a >= c else return a <= c end end
    if better(value, g) then return 100 end
    if better(value, sv) then return 85 + 15 * (sv - value) / (sv - g) end
    if better(value, b) then return 70 + 15 * (b - value) / (b - sv) end
    return higherBetter and 70 * value / b or 70 * b / value
end

-- A course of gates, in order, against the clock.
Kinds.gates = function(t)
    local list = run.gateList
    if not list then
        list = {}
        if t.world then
            for i, g in ipairs(t.world) do list[i] = g end
        else
            for i, g in ipairs(t.gates) do list[i] = { at(run.f, g) } end
        end
        run.gateList, run.next = list, 1
        run.marker = createMarker(list[1][1], list[1][2], 1, "checkpoint", t.width / 2, 255, 255, 0, 150)
        setElementDimension(run.marker, getElementDimension(localPlayer))
    end
    local g = list[run.next]
    if distTo(run.vehicle, g[1], g[2]) < t.width / 2 + 2 then
        run.next = run.next + 1
        if isElement(run.marker) then destroyElement(run.marker) end
        if run.next > #list then
            return finish(medalScore(getTickCount() - run.started, t.medals) - penalties())
        end
        local n = list[run.next]
        run.marker = createMarker(n[1], n[2], 1, "checkpoint", t.width / 2, 255, 255, 0, 150)
        setElementDimension(run.marker, getElementDimension(localPlayer))
    end
end

-- Stop inside the buoys' region against the clock.
Kinds.region = function(t)
    local cx, cy = at(run.f, t.region)
    local v = run.vehicle
    local vx, vy = getElementPosition(v)
    local dx, dy = vx - cx, vy - cy
    local across, along = dx * run.f.rx + dy * run.f.ry, dx * run.f.fx + dy * run.f.fy
    if math.abs(across) <= t.width / 2 and math.abs(along) <= t.depth / 2 and speedOf(v) < 0.5 then
        finish(medalScore(getTickCount() - run.started, t.medals) - penalties())
    end
end

-- Over the ramp: the distance from take-off to touching water again, landing between the buoys' lines.
Kinds.fishjump = function(t)
    local v = run.vehicle
    local airborne = not isVehicleOnGround(v) and not isElementInWater(v)
    local x, y = getElementPosition(v)
    if airborne and not run.takeoff then run.takeoff = { x, y } end
    if run.takeoff and not airborne and not run.landed then
        run.landed = true
        local distance = getDistanceBetweenPoints2D(x, y, run.takeoff[1], run.takeoff[2])
        local rx, ry = at(run.f, t.ramp)
        local across = math.abs((x - rx) * run.f.rx + (y - ry) * run.f.ry)
        if distance < 5 then run.takeoff, run.landed = nil, nil return end
        finish(across <= t.width and medalScore(distance, t.medals, true) or 0)
    end
end

-- Flying: rings (tori) in order, optionally landing at the end.
local function ringMarker(p)
    local m = createMarker(p[1], p[2], p[3], "ring", R.ringRadius, 255, 255, 0, 160)
    setElementDimension(m, getElementDimension(localPlayer))
    return m
end

local function inRing(v, p)
    local x, y, z = getElementPosition(v)
    return getDistanceBetweenPoints3D(x, y, z, p[1], p[2], p[3]) < R.ringRadius
end

Kinds.rings = function(t)
    local v = run.vehicle
    run.next = run.next or 1
    if not run.marker and run.next <= #t.rings then run.marker = ringMarker(t.rings[run.next]) end
    if run.next <= #t.rings and inRing(v, t.rings[run.next]) then
        destroyElement(run.marker) run.marker = nil
        run.next = run.next + 1
        if run.next > #t.rings and not t.land then
            return finish(timeScore(getTickCount() - run.started, t.targetMs) - penalties())
        end
    end
    if t.land and run.next > #t.rings and isVehicleOnGround(v) and speedOf(v) < 0.5 then
        finish(timeScore(getTickCount() - run.started, t.targetMs) - penalties())
    end
end

-- Land and stop as close to the target as possible.
Kinds.landat = function(t)
    local v = run.vehicle
    if not run.marker then
        run.marker = createMarker(t.target[1], t.target[2], t.target[3], "cylinder", 6, 255, 255, 0, 120)
        setElementDimension(run.marker, getElementDimension(localPlayer))
    end
    if isVehicleOnGround(v) and speedOf(v) < 0.5 then
        local d = distTo(v, t.target[1], t.target[2])
        finish(100 - math.max(0, d - 5) * 70 / t.length - penalties())
    end
end

-- Destroy the trucks.
Kinds.destroy = function(t)
    local left = 0
    for _, truck in ipairs(run.props.trucks or {}) do
        if isElement(truck) and not isVehicleBlown(truck) then left = left + 1 end
    end
    if left == 0 then finish(timeScore(getTickCount() - run.started, t.targetMs) - penalties()) end
end

-- Through the first ring, a full loop (pitch) or barrel roll, then through the second.
Kinds.aerobatic = function(t)
    local v = run.vehicle
    run.next = run.next or 1
    if not run.marker and run.next <= 2 then run.marker = ringMarker(t.rings[run.next]) end
    local rx, ry = getElementRotation(v)
    local angle = t.turn == "pitch" and rx or ry
    if run.next == 2 then
        run.turned = (run.turned or 0) + angleDiff(angle, run.lastAngle or angle)
    end
    run.lastAngle = angle
    if run.next <= 2 and inRing(v, t.rings[run.next]) then
        destroyElement(run.marker) run.marker = nil
        run.next = run.next + 1
        if run.next == 3 then
            if (run.turned or 0) < 330 then return finish(0) end
            finish(100 - penalties())
        end
    end
end

-- Parachuting: land on the target, the closer the better.
Kinds.parachute = function(t)
    if not run.marker then
        run.marker = createMarker(t.target[1], t.target[2], t.target[3], "cylinder", t.radius * 2, 255, 255, 0, 140)
        setElementDimension(run.marker, getElementDimension(localPlayer))
    end
    if getTickCount() - run.started > 5000 and isPedOnGround(localPlayer) then
        local x, y = getElementPosition(localPlayer)
        local d = getDistanceBetweenPoints2D(x, y, t.target[1], t.target[2])
        finish(d <= 1 and 100 or d <= t.radius and (100 - (d - 1) / (t.radius - 1) * 30) or math.max(0, 70 - (d - t.radius) * 2))
    end
end

-- Running ---------------------------------------------------------------------------------------------
addEvent("vana-school:run", true)
addEventHandler("vana-school:run", resourceRoot, function(school, index, vehicle, props, origin)
    if run then
        for _, e in ipairs({ run.viaMarker, run.viaBlip, run.homeMarker, run.homeBlip, run.marker }) do
            if isElement(e) then destroyElement(e) end
        end
        Hud.counter("laps", nil) Hud.counter("two", nil)
    end
    run = nil
    if not school then return end
    local test = Schools[school].tests[index]
    run = { test = test, vehicle = vehicle, props = props or {}, f = frame(origin), started = getTickCount(), coneStart = {} }
    setTimer(function()
        if not run then return end
        for i, cone in ipairs(run.props.cones or {}) do
            if isElement(cone) then run.coneStart[i] = { getElementPosition(cone) } end
        end
    end, 1500, 1)
end)

addEventHandler("onClientPreRender", root, function(dt)
    if not run or run.done then return end
    if run.test.kind == "parachute" then
        if getTickCount() - run.started > 1500 then Kinds.parachute(run.test, dt) end
        return
    end
    if not isElement(run.vehicle) then return end
    if isVehicleBlown(run.vehicle) or getPedOccupiedVehicle(localPlayer) ~= run.vehicle then
        if getTickCount() - run.started > 3000 then finish(0) end
        return
    end
    if getTickCount() - run.started < 1500 then return end
    Kinds[run.test.kind](run.test, dt)
end)
