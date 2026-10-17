-- Walking routes over the retail ped path graph, and when to cross roads. Pure logic: no elements,
-- so the same code drives real peds and the pedtest simulation.
PedPlanner = {}

local sqrt = math.sqrt

-- Peds walk with a straight native go-to toward the next sidewalk node or two (GTA's own route
-- follower draws on two 64-slot pools, and a crowd of walkers exhausting them crashes the game).
PedPlanner.LOOKAHEAD = 6          -- metres of route ahead to aim at while walking
PedPlanner.RETARGET_WITHIN = 3.5
PedPlanner.MIN_RETARGET_MS = 400
PedPlanner.WALK_SPEED = 1.4       -- m/s, used to judge whether a crossing can be finished on the walk signal
PedPlanner.EARLY_WALK_MS = 6000   -- with at least this much walk signal left, start any crossing
PedPlanner.ROUTE_AHEAD = 12
PedPlanner.random = math.random

local paths = exports["vana-paths"]
local nodes = {}

function PedPlanner.getNode(area, id)
    local key = area * 65536 + id
    local node = nodes[key]
    if node == nil then
        node = paths:getNode(area, id) or false
        if node then node.links = paths:getNodeLinks(area, id) or {} end
        nodes[key] = node
    end
    return node
end

function PedPlanner.isUsable(node, flood)
    return node and node.kind == "ped" and node.floodFill == flood
end

local function entry(node, link, from)
    local e = { area = node.area, id = node.id, x = node.x, y = node.y, z = node.z }
    -- Retail data flags most crossings on one direction only (1,547 of ~1,700), so the crossing
    -- and ped-light flags belong to the segment: take them from either direction.
    local reverse
    if link then
        for _, back in ipairs(node.links) do
            if back.area == from.area and back.id == from.id then reverse = back break end
        end
    end
    if link and (link.roadCross or reverse and reverse.roadCross) then
        -- The segment from the previous node to this one crosses a road.
        e.crossing = true
        e.lit = link.pedTrafficLight or (reverse and reverse.pedTrafficLight) or false
        e.length = sqrt((node.x - from.x) ^ 2 + (node.y - from.y) ^ 2)
    end
    return e
end

-- Next link from cur, arriving from prev: prefers straight on, never turns back unless the path ends.
function PedPlanner.pickNext(prev, cur, flood)
    local options, weights, total = {}, {}, 0
    local back
    for _, link in ipairs(cur.links) do
        local node = PedPlanner.getNode(link.area, link.id)
        if PedPlanner.isUsable(node, flood) then
            if prev and link.area == prev.area and link.id == prev.id then
                back = link
            else
                local w = 1
                if prev then
                    local ax, ay, bx, by = cur.x - prev.x, cur.y - prev.y, node.x - cur.x, node.y - cur.y
                    local la, lb = sqrt(ax * ax + ay * ay), sqrt(bx * bx + by * by)
                    if la > 0 and lb > 0 then
                        local c = (ax * bx + ay * by) / (la * lb)
                        w = c < -0.3 and 0.05 or 1 + c
                    end
                end
                options[#options + 1], weights[#weights + 1], total = link, w, total + w
            end
        end
    end
    if #options == 0 then return back end
    local r = PedPlanner.random() * total
    for i, link in ipairs(options) do
        r = r - weights[i]
        if r <= 0 then return link end
    end
    return options[#options]
end

function PedPlanner.newRoute(area, id)
    local node = PedPlanner.getNode(area, id)
    if not node or node.kind ~= "ped" then return false end
    local route = { idx = 1, flood = node.floodFill, approved = {}, entry(node) }
    PedPlanner.extend(route)
    if #route < 2 then return false end
    route.idx = 2
    return route
end

function PedPlanner.extend(route)
    while #route - route.idx < PedPlanner.ROUTE_AHEAD do
        local cur, prev = route[#route], route[#route - 1]
        local link = PedPlanner.pickNext(prev, PedPlanner.getNode(cur.area, cur.id), route.flood)
        if not link then return false end
        route[#route + 1] = entry(PedPlanner.getNode(link.area, link.id), link, cur)
    end
    return true
end

function PedPlanner.advance(route, x, y)
    while route.idx < #route do
        local e, nxt = route[route.idx], route[route.idx + 1]
        local dx, dy = e.x - x, e.y - y
        -- Passing a node by walking beyond it is fine, except at a kerb: a ped has only reached the
        -- start of a crossing by standing at it.
        local near = dx * dx + dy * dy < 4
        if near or not nxt.crossing and (x - e.x) * (nxt.x - e.x) + (y - e.y) * (nxt.y - e.y) > 0 then
            route.idx = route.idx + 1
        else
            break
        end
    end
    if route.idx > 16 then
        for _ = 1, 8 do
            local e = table.remove(route, 1)
            route.approved[e] = nil
        end
        route.idx = route.idx - 8
    end
end

-- Where a ped at (x, y) should walk now.
--   signal: "walk", "dont_walk" or "off" (vana-paths getPedSignal)
--   walkMsLeft: time left on the walk signal
--   isClear(from, to): whether an unlit crossing has no traffic close by
-- Returns a target table: x, y, z, hold (waiting at a kerb), index.
function PedPlanner.chooseTarget(route, x, y, signal, walkMsLeft, isClear)
    local px, py, dist = x, y, 0
    for j = route.idx, #route do
        local e = route[j]
        local from = route[j - 1]
        if e.crossing and from and not route.approved[e] then
            -- A ped already out on the crossing is never stopped halfway.
            local onCrossing = false
            if j == route.idx then
                local ux, uy = (e.x - from.x) / e.length, (e.y - from.y) / e.length
                local along = (x - from.x) * ux + (y - from.y) * uy
                local across = math.abs((x - from.x) * uy - (y - from.y) * ux)
                -- Beyond the 2 m arrival radius, so a ped merely arriving at the kerb never counts.
                onCrossing = along > 3 and across < 3
            end
            local go
            if onCrossing then
                go = true
            elseif e.lit and signal ~= "off" then
                -- Anything goes early in the walk phase; later only crossings that can mostly be finished.
                go = signal == "walk" and (walkMsLeft >= PedPlanner.EARLY_WALK_MS or
                    walkMsLeft / 1000 * PedPlanner.WALK_SPEED >= e.length * 0.6)
            else
                go = isClear(from, e)
            end
            if not go then
                return { x = from.x, y = from.y, z = from.z, hold = true, index = j - 1 }
            end
            route.approved[e] = { signal = signal, walkMsLeft = walkMsLeft, onCrossing = onCrossing }
        end
        dist = dist + sqrt((e.x - px) ^ 2 + (e.y - py) ^ 2)
        px, py = e.x, e.y
        if dist >= PedPlanner.LOOKAHEAD then
            return { x = e.x, y = e.y, z = e.z, hold = false, index = j }
        end
    end
    local last = route[#route]
    return { x = last.x, y = last.y, z = last.z, hold = false, index = #route }
end

function PedPlanner.needsNewTarget(current, target, x, y, sinceLastMs)
    if not current or current.hold ~= target.hold then return true end
    if target.hold then return (current.x - target.x) ^ 2 + (current.y - target.y) ^ 2 > 1 end
    if sinceLastMs < PedPlanner.MIN_RETARGET_MS then return false end
    -- The same target again would only restart the native task (a stuck unit is re-sent by its owner logic).
    if (current.x - target.x) ^ 2 + (current.y - target.y) ^ 2 < 1 then return false end
    return (current.x - x) ^ 2 + (current.y - y) ^ 2 < PedPlanner.RETARGET_WITHIN ^ 2
end

-- Whether a fresh route leads somewhere, rather than bouncing inside a tiny isolated path fragment.
function PedPlanner.isRouteOpen(route)
    local seen, count = {}, 0
    for _, e in ipairs(route) do
        local key = e.area * 65536 + e.id
        if not seen[key] then seen[key], count = true, count + 1 end
    end
    return count >= 6
end
