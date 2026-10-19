-- Routes over the vehicle path graph, for the map's GPS (vana-map): weighted A* from the road nearest one point
-- to the road nearest another, both ways along every link (the data's lanes aren't one-way enough to
-- matter for a map line), boat nodes left out. A point without z (a spot picked on the map) snaps to the
-- nearest road on the map. Returns the route as a flat list x1, y1, x2, y2 ...
Route = {}

local sqrt, floor = math.sqrt, math.floor
local MAX_EXPANDED = 40000
-- The distance left counts this much more than the distance so far: a route within a few percent of
-- the shortest, found expanding several times fewer nodes (the search runs on the server's frame).
local GREED = 1.4
local SNAP_RADIUS = { 250, 750, 2000 } -- tried in turn for the road nearest each end

local function key(area, id) return area * 65536 + id end

-- A small binary heap of keys by f-score.
local function push(heap, score, k, f)
    local n = #heap + 1
    heap[n], score[k] = k, f
    while n > 1 do
        local p = floor(n / 2)
        if score[heap[p]] <= f then break end
        heap[n], heap[p] = heap[p], heap[n]
        n = p
    end
end

local function pop(heap, score)
    local top, last = heap[1], heap[#heap]
    heap[#heap] = nil
    if #heap > 0 then
        heap[1] = last
        local n, size = 1, #heap
        while true do
            local l, r, m = n * 2, n * 2 + 1, n
            if l <= size and score[heap[l]] < score[heap[m]] then m = l end
            if r <= size and score[heap[r]] < score[heap[m]] then m = r end
            if m == n then break end
            heap[n], heap[m] = heap[m], heap[n]
            n = m
        end
    end
    return top
end

local function road(x, y, z)
    for _, radius in ipairs(SNAP_RADIUS) do
        local area, id = Paths.findNearestNode(x, y, z, "vehicle", radius)
        if area then return area, id end
    end
end

local function isBoat(a, id) return bitExtract(a.flags[id], 7, 1) == 1 end

function Route.find(fromX, fromY, fromZ, toX, toY, toZ)
    Paths.loadAll()
    local sa, si = road(fromX, fromY, fromZ)
    local ga, gi = road(toX, toY, toZ)
    if not sa or not ga then return false, "no road near" end
    local goal = key(ga, gi)
    local gx, gy = Paths.getNodePosition(ga, gi)
    local start = key(sa, si)
    local cost, from, fscore, closed = { [start] = 0 }, {}, {}, {}
    local heap = {}
    local sx, sy = Paths.getNodePosition(sa, si)
    push(heap, fscore, start, GREED * sqrt((sx - gx) ^ 2 + (sy - gy) ^ 2))
    local expanded = 0
    while #heap > 0 do
        local k = pop(heap, fscore)
        if k == goal then break end
        if not closed[k] then
            closed[k] = true
            expanded = expanded + 1
            if expanded > MAX_EXPANDED then return false, "too far" end
            local area, id = floor(k / 65536), k % 65536
            local a = Paths.getLoadedArea(area)
            local x, y = a.x[id], a.y[id]
            local start0 = a.linkStart[id]
            for i = start0, start0 + bitExtract(a.flags[id], 0, 4) - 1 do
                local na, ni = a.linkArea[i], a.linkNode[i]
                local b = Paths.getLoadedArea(na)
                if b and ni < b.vehCount and not isBoat(b, ni) then
                    local nk = key(na, ni)
                    if not closed[nk] then
                        local nx, ny = b.x[ni], b.y[ni]
                        local dx, dy = nx - x, ny - y
                        local c = cost[k] + sqrt(dx * dx + dy * dy)
                        if not cost[nk] or c < cost[nk] then
                            cost[nk], from[nk] = c, k
                            local hx, hy = nx - gx, ny - gy
                            push(heap, fscore, nk, c + GREED * sqrt(hx * hx + hy * hy))
                        end
                    end
                end
            end
        end
    end
    if not cost[goal] then return false, "no way there" end
    -- Back from the goal, as a flat list from the start.
    local nodes, k = {}, goal
    while k do
        nodes[#nodes + 1] = k
        k = from[k]
    end
    local out = {}
    for i = #nodes, 1, -1 do
        local x, y = Paths.getNodePosition(floor(nodes[i] / 65536), nodes[i] % 65536)
        out[#out + 1], out[#out + 2] = x, y
    end
    return out, cost[goal], expanded
end
