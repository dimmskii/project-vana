-- Console-only: drives virtual units along real planned routes under the vanilla light cycle and
-- checks the planner's decisions. No elements are created.
local paths = exports["vana-paths"]

local DT, DURATION, CARS = 0.25, 300, 100
local ACCEL, DECEL, CRUISE = 3, 8, 13
local FRONT = 2.5

-- Vanilla cycle in ms, as driven by vana-lights.
local function lightAt(ms)
    local m = ms % 32768
    if m < 10000 then return 0 elseif m < 12000 then return 1 elseif m < 22000 then return 3 elseif m < 24000 then return 4 end
    return 2
end

local function randomRoute()
    for _ = 1, 200 do
        local area, id = paths:findNearestNode(math.random(-2900, 2900), math.random(-2900, 2900), 20, "vehicle", 200)
        local node = area and Planner.getNode(area, id)
        if node and node.floodFill == 1 and Planner.isUsable(node, 1) then
            local route = Planner.newRoute(area, id)
            if route then return route end
        end
    end
end

-- A closed level crossing on a straight road: a car far enough away stops RAIL_CLEAR + STOP_BACK
-- before the rails, one too close to stop commits, and nobody waits once it's open.
local function crossingCase()
    local function route()
        return { idx = 2, decisions = {}, { area = 0, id = 0, x = 0, y = 0, z = 0 },
                 { area = 0, id = 1, x = 0, y = 100, z = 0, rail = { { id = "c", x = 0, y = 50 } } },
                 { area = 0, id = 2, x = 0, y = 200, z = 0 } }
    end
    local far = Planner.chooseTarget(route(), 0, 0, 10, 0, FRONT, { c = true })
    local line = 50 - Planner.RAIL_CLEAR - Planner.STOP_BACK - FRONT
    local close = Planner.chooseTarget(route(), 0, 44, 15, 0, FRONT, { c = true })
    local open = Planner.chooseTarget(route(), 0, 0, 10, 0, FRONT, {})
    local ok = far.hold and math.abs(far.y - line) < 0.01 and not close.hold and not open.hold
    outputServerLog(("[traffictest] level crossing: stops %s at %.1f (line %.1f), too close to stop %s, open %s")
        :format(far.hold and "yes" or "NO", far.y or -1, line, close.hold and "STOPS" or "goes", open.hold and "STOPS" or "goes"))
    return ok
end

-- Runs as a coroutine resumed every frame, one unit at a time: a cold start (every node fetched
-- through vana-paths' exports) would otherwise exceed the script time limit.
local function run(seed)
    math.randomseed(tonumber(seed) or 1234)
    local t0 = getTickCount()
    local stats = { redRuns = 0, wrongWay = 0, committedRed = 0, amberRuns = 0, uturns = 0, deadEndTurns = 0, badNodes = 0, stalled = 0, lightStops = 0, lightPasses = 0, centreStops = 0 }
    local totalDist, retargets = 0, 0

    for _ = 1, CARS do
        local route = randomRoute()
        local x, y = route[1].x, route[1].y
        local v, travelled, holding, checked = 0, 0, false, 1
        local sent, sentAt = nil, -math.huge

        for step = 0, DURATION / DT do
            local ms = step * DT * 1000
            local state = lightAt(ms)
            Planner.extend(route)

            -- Every planned node must be a usable road node, and a turn back must be a dead end.
            for k = checked + 1, #route do
                local e = route[k]
                if not Planner.isUsable(Planner.getNode(e.area, e.id), route.flood) then stats.badNodes = stats.badNodes + 1 end
                local before = route[k - 2]
                local turnedBack = before and before.area == e.area and before.id == e.id
                if e.link and Planner.lanes(e.link) == 0 and not turnedBack then stats.wrongWay = stats.wrongWay + 1 end
                if turnedBack then
                    local mid = route[k - 1]
                    local exits = 0
                    for _, link in ipairs(Planner.getNode(mid.area, mid.id).links) do
                        if Planner.isUsable(Planner.getNode(link.area, link.id), route.flood) and Planner.lanes(link) > 0 then exits = exits + 1 end
                    end
                    if exits > 1 then stats.uturns = stats.uturns + 1 else stats.deadEndTurns = stats.deadEndTurns + 1 end
                end
            end
            checked = #route

            local target = Planner.chooseTarget(route, x, y, v, state, FRONT)
            if Planner.needsNewTarget(sent, target, x, y, ms - sentAt) then sent, sentAt, retargets = target, ms, retargets + 1 end
            local want = CRUISE
            if target.hold then
                local toStop = (target.x - x) * target.light.dirX + (target.y - y) * target.light.dirY
                want = math.min(CRUISE, math.sqrt(2 * DECEL * 0.6 * math.max(0, toStop)))
            end
            if want > v then v = math.min(want, v + ACCEL * DT) else v = math.max(want, v - DECEL * DT) end
            if target.hold and v < 0.5 and not holding then
                stats.lightStops = stats.lightStops + 1
                -- Stop points sit in a lane, right of the centre line on two-way roads (never on it).
                local link = route[target.index].link
                local lateral = (target.x - target.light.x) * target.light.dirY - (target.y - target.light.y) * target.light.dirX
                if link and Planner.laneCenters(link)[1] > 0 and lateral < 2 then stats.centreStops = stats.centreStops + 1 end
            end
            holding = target.hold and v < 0.5

            -- Move along the route polyline, watching the light governing each stop line we cross.
            local d = v * DT
            while d > 0 and route.idx <= #route do
                local e = route[route.idx]
                local light = e.light
                local beforeAhead = light and (light.x - x) * light.dirX + (light.y - y) * light.dirY - FRONT
                local dx, dy = e.x - x, e.y - y
                local seg = math.sqrt(dx * dx + dy * dy)
                local nx, ny
                if seg <= d then
                    nx, ny, d = e.x, e.y, d - seg
                    route.idx = route.idx + 1
                else
                    nx, ny, d = x + dx / seg * d, y + dy / seg * d, 0
                end
                if light then
                    local afterAhead = (light.x - nx) * light.dirX + (light.y - ny) * light.dirY - FRONT
                    if beforeAhead > 0 and afterAhead <= 0 then
                        local colour = paths:getCarLight(light.trafficLight, state)
                        if colour == "red" and route.decisions[light] == "go-amber" then
                            stats.committedRed = stats.committedRed + 1
                        elseif colour == "red" then stats.redRuns = stats.redRuns + 1
                        elseif colour == "amber" then stats.amberRuns = stats.amberRuns + 1
                        else stats.lightPasses = stats.lightPasses + 1 end
                    end
                end
                travelled = travelled + math.sqrt((nx - x) ^ 2 + (ny - y) ^ 2)
                x, y = nx, ny
            end
            Planner.advance(route, x, y)
        end
        totalDist = totalDist + travelled
        if travelled < 500 then stats.stalled = stats.stalled + 1 end
        coroutine.yield()
    end

    local ok = crossingCase() and stats.centreStops == 0 and stats.redRuns == 0 and stats.wrongWay == 0 and stats.uturns == 0 and stats.badNodes == 0 and stats.stalled == 0 and stats.lightStops > 0
    outputServerLog(("[traffictest] %d units x %ds simulated in %d ms (across frames), avg %.1f km each"):format(CARS, DURATION, getTickCount() - t0, totalDist / CARS / 1000))
    outputServerLog(("[traffictest] light stops %d, green passes %d, amber passes %d, amber-committed red clears %d, red runs %d")
        :format(stats.lightStops, stats.lightPasses, stats.amberRuns, stats.committedRed, stats.redRuns))
    outputServerLog(("[traffictest] native retargets %.1f per unit-minute"):format(retargets / CARS / (DURATION / 60)))
    outputServerLog(("[traffictest] u-turns %d (dead ends %d), bad nodes %d, wrong-way links %d, stalled units %d")
        :format(stats.uturns, stats.deadEndTurns, stats.badNodes, stats.wrongWay, stats.stalled))
    outputServerLog(("[traffictest] stops on the centre line of a two-way road: %d"):format(stats.centreStops))
    outputServerLog("[traffictest] " .. (ok and "PASS" or "FAIL"))
end

addCommandHandler("traffictest", function(source, _, seed)
    if getElementType(source) ~= "console" then return end
    local co = coroutine.create(run)
    local function step()
        local ok, err = coroutine.resume(co, seed)
        if not ok then outputServerLog("[traffictest] error: " .. tostring(err)) return end
        if coroutine.status(co) ~= "dead" then setTimer(step, 0, 1) end
    end
    step()
end)
