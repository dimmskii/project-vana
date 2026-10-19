-- Route planning and drive targets over the retail path graph. Pure logic: no elements, so the
-- same code drives real units and the traffictest simulation.
Planner = {}

local sqrt = math.sqrt

Planner.LOOKAHEAD = 80      -- metres of route ahead to aim at while cruising
Planner.RETARGET_WITHIN = 40 -- retarget once this close to the cruise target (native drive-to slows near it)
Planner.MIN_RETARGET_MS = 1500
Planner.STOP_BACK = 3       -- the front bumper stops this far behind the navi point of a red light
Planner.AMBER_DECEL = 5     -- m/s^2; on amber, stop only if this deceleration still makes the stop point
Planner.HARD_DECEL = 7      -- m/s^2; on red, go through only if even this can't stop before the line
Planner.ROUTE_AHEAD = 12    -- nodes kept planned ahead of the unit
Planner.LANE_WIDTH = 5.4    -- the engine's lane width (CCarPathLink::OneWayLaneOffset)
Planner.random = math.random

local paths = exports["vana-paths"]
local nodes = {}

function Planner.getNode(area, id)
    local key = area * 65536 + id
    local node = nodes[key]
    if node == nil then
        node = paths:getNode(area, id) or false
        if node then node.links = paths:getNodeLinks(area, id) or {} end
        nodes[key] = node
    end
    return node
end

-- Light governing a car on this link (cached on the link; colour is evaluated at runtime).
local function linkLight(link)
    if link.light == nil then
        link.light = link.naviArea and paths:getGoverningLight(link.naviArea, link.naviIndex, link.area, link.id) or false
    end
    return link.light
end

-- Lanes carrying traffic along this link (from its node toward link.area/link.id). Checked against
-- the retail roads: leftLanes run toward the navi node's target, rightLanes away from it (with the
-- opposite reading, 93% of divided roads would have their opposite carriageway on the right).
local function naviOf(link)
    if link.navi == nil then link.navi = link.naviArea and paths:getNaviNode(link.naviArea, link.naviIndex) or false end
    return link.navi
end

function Planner.lanes(link)
    if link.lanes == nil then
        local navi = naviOf(link)
        if not navi then
            link.lanes = 1
        else
            local toward = navi.targetArea == link.area and navi.targetId == link.id
            link.lanes = toward and navi.leftLanes or navi.rightLanes
        end
    end
    return link.lanes
end

-- Lane centres for traffic along this link, in metres to the right of the path line (which runs
-- down the middle of the road): on a two-way road our lanes sit right of the centre line; on a
-- one-way road they are spread across it.
function Planner.laneCenters(link)
    if link.centers == nil then
        local navi = naviOf(link)
        local mine, other = 1, 0
        if navi then
            local toward = navi.targetArea == link.area and navi.targetId == link.id
            mine = math.max(1, toward and navi.leftLanes or navi.rightLanes)
            other = toward and navi.rightLanes or navi.leftLanes
        end
        local centers = {}
        for i = 1, mine do
            centers[i] = (other > 0 and (i - 0.5) or (i - (mine + 1) / 2)) * Planner.LANE_WIDTH
        end
        link.centers = centers
    end
    return link.centers
end

-- The lane a unit at (x, y) drives in now (index into the current link's centres), tracked on the
-- route so targets ahead keep it.
local function currentLane(route, x, y)
    local prev, cur = route[route.idx - 1], route[route.idx]
    if not prev or not cur or not cur.link then return route.lane or 1 end
    local dx, dy = cur.x - prev.x, cur.y - prev.y
    local len = sqrt(dx * dx + dy * dy)
    if len < 0.1 then return route.lane or 1 end
    local lateral = ((x - prev.x) * dy - (y - prev.y) * dx) / len
    local best, bestDist = 1, math.huge
    for i, c in ipairs(Planner.laneCenters(cur.link)) do
        if math.abs(c - lateral) < bestDist then best, bestDist = i, math.abs(c - lateral) end
    end
    route.lane = best
    return best
end

-- (x, y) moved into lane `lane` of `link`, for travel along (dirX, dirY).
local function inLane(x, y, dirX, dirY, link, lane)
    if not link then return x, y end
    local centers = Planner.laneCenters(link)
    local offset = centers[math.min(lane, #centers)]
    return x + dirY * offset, y - dirX * offset
end

local function direction(a, b)
    local dx, dy = b.x - a.x, b.y - a.y
    local len = sqrt(dx * dx + dy * dy)
    if len < 0.1 then return 0, 0 end
    return dx / len, dy / len
end

function Planner.isUsable(node, flood)
    return node and node.kind == "vehicle" and not node.boats and not node.emergencyOnly and node.floodFill == flood
end

local function entry(node, link)
    return { area = node.area, id = node.id, x = node.x, y = node.y, z = node.z, highway = node.highway,
             light = link and linkLight(link) or false, link = link }
end

-- Picks the next link from cur, arriving from prev. Prefers straight on, never turns back unless
-- the road ends.
function Planner.pickNext(prev, cur, flood)
    local options, weights, total = {}, {}, 0
    local back
    for _, link in ipairs(cur.links) do
        local node = Planner.getNode(link.area, link.id)
        if Planner.isUsable(node, flood) and prev and link.area == prev.area and link.id == prev.id then
            -- Turning back is the last resort, even against the lanes at a one-way dead end.
            back = link
        elseif Planner.isUsable(node, flood) and Planner.lanes(link) > 0 then
            do
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
    local r = Planner.random() * total
    for i, link in ipairs(options) do
        r = r - weights[i]
        if r <= 0 then return link end
    end
    return options[#options]
end

function Planner.newRoute(area, id)
    local node = Planner.getNode(area, id)
    if not node or node.kind ~= "vehicle" then return false end
    local route = { idx = 1, flood = node.floodFill, decisions = {}, entry(node) }
    Planner.extend(route)
    if #route < 2 then return false end
    route.idx = 2
    return route
end

function Planner.extend(route)
    while #route - route.idx < Planner.ROUTE_AHEAD do
        local cur, prev = route[#route], route[#route - 1]
        local link = Planner.pickNext(prev, Planner.getNode(cur.area, cur.id), route.flood)
        if not link then return false end
        if prev and link.area == prev.area and link.id == prev.id then route.turnBacks = (route.turnBacks or 0) + 1 end
        route[#route + 1] = entry(Planner.getNode(link.area, link.id), link)
    end
    return true
end

-- Moves route.idx past every node the unit at (x, y) has reached or driven past.
function Planner.advance(route, x, y)
    while route.idx < #route do
        local e, nxt = route[route.idx], route[route.idx + 1]
        local dx, dy = e.x - x, e.y - y
        if dx * dx + dy * dy < 36 or (x - e.x) * (nxt.x - e.x) + (y - e.y) * (nxt.y - e.y) > 0 then
            route.idx = route.idx + 1
        else
            break
        end
    end
    if route.idx > 16 then
        for _ = 1, 8 do
            local e = table.remove(route, 1)
            if e.light then route.decisions[e.light] = nil end
        end
        route.idx = route.idx - 8
    end
end

-- Where a unit at (x, y) moving at speed m/s should drive now. front is the distance from the
-- vehicle's position to its front bumper. Returns a target table: x, y, z (vehicle position to
-- reach), mode ("normal" or "accurate"), hold (stopping for a light), light, index.
function Planner.chooseTarget(route, x, y, speed, lightState, front)
    front = front or 0
    local lane = currentLane(route, x, y)
    local lookahead = math.max(Planner.LOOKAHEAD, speed * speed / (2 * Planner.AMBER_DECEL) + 15)
    local px, py, dist = x, y, 0
    for j = route.idx, #route do
        local e = route[j]
        local light = e.light
        if light then
            -- Route distance to the stop line: what is driven to reach the previous node, plus the
            -- remaining stretch measured along the light's own direction.
            local ahead = dist + (light.x - px) * light.dirX + (light.y - py) * light.dirY - front
            if ahead > -1 then
                local colour = paths:getCarLight(light.trafficLight, lightState)
                local decision = route.decisions[light]
                if colour ~= "red" and colour ~= "amber" then
                    route.decisions[light] = nil
                elseif decision ~= "go-amber" and decision ~= "go-red" then
                    -- Once told to stop, keep stopping. Otherwise amber stops if it can be done comfortably
                    -- at the stop point, and red stops unless the line can't be made even braking hard;
                    -- failing that, commit and clear the junction.
                    local stop = decision == "hold"
                    if not stop and colour == "amber" then
                        stop = ahead - Planner.STOP_BACK > speed * speed / (2 * Planner.AMBER_DECEL)
                    elseif not stop then
                        stop = ahead > speed * speed / (2 * Planner.HARD_DECEL)
                    end
                    if stop then
                        route.decisions[light] = "hold"
                        local back = Planner.STOP_BACK + front
                        local sx, sy = inLane(light.x - light.dirX * back, light.y - light.dirY * back, light.dirX, light.dirY, e.link, lane)
                        return { x = sx, y = sy, z = e.z, mode = "accurate", hold = true, light = light, index = j }
                    end
                    route.decisions[light] = "go-" .. colour
                end
            end
        end
        dist = dist + sqrt((e.x - px) ^ 2 + (e.y - py) ^ 2)
        px, py = e.x, e.y
        if dist >= lookahead then
            local dirX, dirY = direction(route[j - 1] or e, e)
            local tx, ty = inLane(e.x, e.y, dirX, dirY, e.link, lane)
            return { x = tx, y = ty, z = e.z, mode = "normal", hold = false, index = j }
        end
    end
    local last = route[#route]
    local dirX, dirY = direction(route[#route - 1] or last, last)
    local tx, ty = inLane(last.x, last.y, dirX, dirY, last.link, lane)
    return { x = tx, y = ty, z = last.z, mode = "normal", hold = false, index = #route }
end

-- Whether the unit's native task needs a new target. Restarting the task re-plans GTA's road route,
-- so cruise targets are only replaced when the unit gets close to them.
function Planner.needsNewTarget(current, target, x, y, sinceLastMs)
    if not current or current.hold ~= target.hold then return true end
    if target.hold then return (current.x - target.x) ^ 2 + (current.y - target.y) ^ 2 > 4 end
    if sinceLastMs < Planner.MIN_RETARGET_MS then return false end
    -- The same target again would only restart the native task (a stuck unit is re-sent by its owner logic).
    if (current.x - target.x) ^ 2 + (current.y - target.y) ^ 2 < 1 then return false end
    return (current.x - x) ^ 2 + (current.y - y) ^ 2 < Planner.RETARGET_WITHIN ^ 2
end
