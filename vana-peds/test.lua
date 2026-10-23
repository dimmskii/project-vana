-- Console-only: walks virtual peds along real planned routes under the vanilla light cycle and
-- checks the crossing decisions. No elements are created.
local paths = exports["vana-paths"]

local DT, DURATION, PEDS = 0.25, 300, 200
local SPEED = 1.4

-- Vanilla cycle (as driven by vana-lights): returns the MTA state and ms left in the phase.
local PHASES = { { 0, 10000 }, { 1, 2000 }, { 3, 10000 }, { 4, 2000 }, { 2, 8768 } }
local function lightAt(ms)
    local m = ms % 32768
    for _, p in ipairs(PHASES) do
        if m < p[2] then return p[1], p[2] - m end
        m = m - p[2]
    end
    return 2, 0
end

local function randomRoute()
    for _ = 1, 400 do
        local area, id = paths:findNearestNode(math.random(-2900, 2900), math.random(-2900, 2900), 20, "ped", 200)
        local node = area and PedPlanner.getNode(area, id)
        if node and node.spawnProbability > 0 then
            local route = PedPlanner.newRoute(area, id)
            if route and not route[2].crossing and PedPlanner.isRouteOpen(route) then return route end
        end
    end
end

addCommandHandler("pedtest", function(source, _, seed)
    if getElementType(source) ~= "console" then return end
    math.randomseed(tonumber(seed) or 1234)
    local t0 = getTickCount()
    local stats = { litCrossings = 0, unlitCrossings = 0, badStarts = 0, lateFinishes = 0, uturns = 0, deadEnds = 0,
                    badNodes = 0, stalled = 0, retargets = 0, waits = 0, waitMs = 0 }
    local totalDist = 0

    for _ = 1, PEDS do
        local route = randomRoute()
        local x, y = route[1].x, route[1].y
        local travelled, checked = 0, 1
        local sent, sentAt, waitStart = nil, -math.huge, nil
        local crossingEntry, crossingEndsBy

        for step = 0, DURATION / DT do
            local ms = step * DT * 1000
            local state, phaseLeft = lightAt(ms)
            local signal = paths:getPedSignal(state)
            PedPlanner.extend(route)

            for k = checked + 1, #route do
                local e = route[k]
                if not PedPlanner.isUsable(PedPlanner.getNode(e.area, e.id), route.flood) then stats.badNodes = stats.badNodes + 1 end
                local before = route[k - 2]
                if before and before.area == e.area and before.id == e.id then
                    local mid, exits = route[k - 1], 0
                    for _, link in ipairs(PedPlanner.getNode(mid.area, mid.id).links) do
                        if PedPlanner.isUsable(PedPlanner.getNode(link.area, link.id), route.flood) then exits = exits + 1 end
                    end
                    if exits > 1 then stats.uturns = stats.uturns + 1 else stats.deadEnds = stats.deadEnds + 1 end
                end
            end
            checked = #route

            local target = PedPlanner.chooseTarget(route, x, y, signal, signal == "walk" and phaseLeft or 0, function() return true end)
            if PedPlanner.needsNewTarget(sent, target, x, y, ms - sentAt) then
                sent, sentAt, stats.retargets = target, ms, stats.retargets + 1
            end
            if target.hold then
                if not waitStart then waitStart, stats.waits = ms, stats.waits + 1 end
            elseif waitStart then
                stats.waitMs, waitStart = stats.waitMs + (ms - waitStart), nil
            end

            -- Walk toward the target along the route polyline (holding peds stop at their kerb node).
            local d = SPEED * DT
            while d > 0 and route.idx <= #route do
                local e = route[route.idx]
                if target.hold and route.idx > target.index then break end
                local dx, dy = e.x - x, e.y - y
                local seg = math.sqrt(dx * dx + dy * dy)
                local nx, ny
                if seg <= d then
                    nx, ny, d = e.x, e.y, d - seg
                    route.idx = route.idx + 1
                else
                    nx, ny, d = x + dx / seg * d, y + dy / seg * d, 0
                end
                -- Stepping onto a crossing: it must have been approved before the ped left the kerb.
                if e.crossing and crossingEntry ~= e then
                    local from = route[route.idx - 1] == e and route[route.idx - 2] or route[route.idx - 1]
                    local progress = from and ((nx - from.x) * (e.x - from.x) + (ny - from.y) * (e.y - from.y)) / e.length or 0
                    if progress > 0.5 then
                        crossingEntry = e
                        local approval = route.approved[e]
                        if not approval or approval.onCrossing then
                            stats.badStarts = stats.badStarts + 1
                        elseif e.lit then
                            stats.litCrossings = stats.litCrossings + 1
                            if approval.signal ~= "walk" then stats.badStarts = stats.badStarts + 1 end
                            crossingEndsBy = ms + phaseLeft
                        else
                            stats.unlitCrossings = stats.unlitCrossings + 1
                        end
                    end
                end
                travelled = travelled + math.sqrt((nx - x) ^ 2 + (ny - y) ^ 2)
                x, y = nx, ny
            end
            -- Still on a lit crossing well after the walk signal ended.
            if crossingEndsBy and crossingEntry and route[route.idx - 1] == crossingEntry then
                if ms > crossingEndsBy + 6000 then stats.lateFinishes = stats.lateFinishes + 1 end
                crossingEndsBy = nil
            end
            PedPlanner.advance(route, x, y)
        end
        totalDist = totalDist + travelled
        if travelled < 150 then stats.stalled = stats.stalled + 1 end
    end

    -- A closed level crossing: a ped short of it waits RAIL_CLEAR before the rails, one past that
    -- point walks on, and nobody waits once it's open.
    local function crossingRoute()
        return { idx = 2, approved = {}, { area = 0, id = 0, x = 0, y = 0, z = 0 },
                 { area = 0, id = 1, x = 0, y = 20, z = 0, rail = { { id = "c", x = 0, y = 10 } } },
                 { area = 0, id = 2, x = 0, y = 40, z = 0 } }
    end
    local yes = function() return true end
    local short = PedPlanner.chooseTarget(crossingRoute(), 0, 0, "off", 0, yes, { c = true })
    local past = PedPlanner.chooseTarget(crossingRoute(), 0, 8, "off", 0, yes, { c = true })
    local open = PedPlanner.chooseTarget(crossingRoute(), 0, 0, "off", 0, yes, {})
    local railOk = short.hold and math.abs(short.y - (10 - PedPlanner.RAIL_CLEAR)) < 0.01 and not past.hold and not open.hold
    outputServerLog(("[pedtest] level crossing: waits %s at %.1f, past the wait point %s, open %s")
        :format(short.hold and "yes" or "NO", short.y or -1, past.hold and "WAITS" or "walks on", open.hold and "WAITS" or "walks on"))

    local ok = railOk and stats.badStarts == 0 and stats.uturns == 0 and stats.badNodes == 0 and stats.stalled == 0 and stats.litCrossings > 0
    outputServerLog(("[pedtest] %d peds x %ds simulated in %d ms, avg %.0f m walked, %.1f retargets per ped-minute")
        :format(PEDS, DURATION, getTickCount() - t0, totalDist / PEDS, stats.retargets / PEDS / (DURATION / 60)))
    outputServerLog(("[pedtest] crossings: %d lit, %d unlit; %d started without approval; %d finished >6s after walk ended; %d kerb waits, avg %.1fs")
        :format(stats.litCrossings, stats.unlitCrossings, stats.badStarts, stats.lateFinishes, stats.waits,
            stats.waits > 0 and stats.waitMs / stats.waits / 1000 or 0))
    outputServerLog(("[pedtest] u-turns %d (dead ends %d), bad nodes %d, stalled peds %d")
        :format(stats.uturns, stats.deadEnds, stats.badNodes, stats.stalled))
    outputServerLog("[pedtest] " .. (ok and "PASS" or "FAIL"))
end)
