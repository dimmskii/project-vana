-- Lazy, area-at-a-time access to the retail path graph. IDs are the game's own (area, 0-based node).
Paths = {}

local floor, max, min, sqrt = math.floor, math.max, math.min, math.sqrt

local AREA_SIZE, WORLD_MIN, GRID = 750, -3000, 8
local CELL = 50
local CELLS = AREA_SIZE / CELL

local areas = {}
local buckets = {}

function Paths.getAreaAt(x, y)
    local ax = min(GRID - 1, max(0, floor((x - WORLD_MIN) / AREA_SIZE)))
    local ay = min(GRID - 1, max(0, floor((y - WORLD_MIN) / AREA_SIZE)))
    return ay * GRID + ax
end

function Paths.loadArea(id)
    if areas[id] then return areas[id] end
    local f = fileOpen(("data/NODES%d.DAT"):format(id), true)
    if not f then return false end
    local s = fileRead(f, fileGetSize(f))
    fileClose(f)
    local area, err = PathsFormat.parse(id, s)
    if not area then
        outputDebugString("[vana-paths] " .. err, 1)
        return false
    end
    areas[id] = area
    return area
end

function Paths.loadAll()
    for id = 0, GRID * GRID - 1 do Paths.loadArea(id) end
end

function Paths.isLoaded(id) return areas[id] ~= nil end

local function flag(v, bit, width) return bitExtract(v, bit, width or 1) end

function Paths.getNode(areaId, id)
    local a = Paths.loadArea(areaId)
    if not a or id < 0 or id >= a.nodeCount then return false end
    local f = a.flags[id]
    return {
        area = areaId, id = id,
        x = a.x[id], y = a.y[id], z = a.z[id],
        kind = id < a.vehCount and "vehicle" or "ped",
        width = a.width[id], floodFill = a.flood[id],
        linkCount = flag(f, 0, 4),
        trafficLevel = flag(f, 4, 2),
        roadblocks = flag(f, 6) == 1,
        boats = flag(f, 7) == 1,
        emergencyOnly = flag(f, 8) == 1,
        notHighway = flag(f, 12) == 1,
        highway = flag(f, 13) == 1,
        spawnProbability = flag(f, 16, 4),
        parking = flag(f, 21) == 1,
    }
end

function Paths.getNodePosition(areaId, id)
    local a = Paths.loadArea(areaId)
    if not a or id < 0 or id >= a.nodeCount then return false end
    return a.x[id], a.y[id], a.z[id]
end

function Paths.getNodeLinks(areaId, id)
    local a = Paths.loadArea(areaId)
    if not a or id < 0 or id >= a.nodeCount then return false end
    local start, links = a.linkStart[id], {}
    local isVehicle = id < a.vehCount
    for i = start, start + flag(a.flags[id], 0, 4) - 1 do
        local lf = a.linkFlags[i]
        local link = {
            area = a.linkArea[i], id = a.linkNode[i], length = a.linkLength[i],
            roadCross = flag(lf, 0) == 1, pedTrafficLight = flag(lf, 1) == 1,
        }
        if isVehicle then
            link.naviArea, link.naviIndex = PathsFormat.splitNaviLink(a.linkNavi[i])
        end
        links[#links + 1] = link
    end
    return links
end

function Paths.getNaviNode(areaId, index)
    local a = Paths.loadArea(areaId)
    if not a or index < 0 or index >= a.naviCount then return false end
    local f = a.naviFlags[index]
    return {
        area = areaId, index = index,
        x = a.naviX[index], y = a.naviY[index],
        targetArea = a.naviArea[index], targetId = a.naviNode[index],
        dirX = a.naviDirX[index], dirY = a.naviDirY[index],
        width = flag(f, 0, 8) / 8,
        leftLanes = flag(f, 8, 3), rightLanes = flag(f, 11, 3),
        trafficLightDirection = flag(f, 14) == 1, -- true: governs traffic heading to the target node
        trafficLight = flag(f, 16, 2), -- 0 none, 1 north-south, 2 west-east
        trainCrossing = flag(f, 18) == 1,
    }
end

local function getBuckets(areaId, kind)
    local key = areaId * 2 + (kind == "vehicle" and 0 or 1)
    if buckets[key] then return buckets[key] end
    local a = Paths.loadArea(areaId)
    if not a then return false end
    local ox, oy = (areaId % GRID) * AREA_SIZE + WORLD_MIN, floor(areaId / GRID) * AREA_SIZE + WORLD_MIN
    local first, last = 0, a.vehCount - 1
    if kind ~= "vehicle" then first, last = a.vehCount, a.nodeCount - 1 end
    local b = {}
    for i = first, last do
        local cx = min(CELLS - 1, max(0, floor((a.x[i] - ox) / CELL)))
        local cy = min(CELLS - 1, max(0, floor((a.y[i] - oy) / CELL)))
        local c = cy * CELLS + cx
        local list = b[c]
        if not list then list = {}; b[c] = list end
        list[#list + 1] = i
    end
    buckets[key] = b
    return b
end

-- kind: "vehicle" or "ped"; z nil: nearest on the map (2D). Returns area, id, distance or false.
function Paths.findNearestNode(x, y, z, kind, radius)
    radius = radius or 100
    local bestArea, bestId, bestDist = false, false, radius
    local a0, a1 = Paths.getAreaAt(x - radius, y - radius), Paths.getAreaAt(x + radius, y + radius)
    for ay = floor(a0 / GRID), floor(a1 / GRID) do
        for ax = a0 % GRID, a1 % GRID do
            local areaId = ay * GRID + ax
            local a, b = Paths.loadArea(areaId), getBuckets(areaId, kind)
            if a and b then
                local ox, oy = ax * AREA_SIZE + WORLD_MIN, ay * AREA_SIZE + WORLD_MIN
                for cy = max(0, floor((y - radius - oy) / CELL)), min(CELLS - 1, floor((y + radius - oy) / CELL)) do
                    for cx = max(0, floor((x - radius - ox) / CELL)), min(CELLS - 1, floor((x + radius - ox) / CELL)) do
                        local list = b[cy * CELLS + cx]
                        if list then
                            for _, i in ipairs(list) do
                                local dx, dy, dz = a.x[i] - x, a.y[i] - y, z and (a.z[i] - z) or 0
                                local d = sqrt(dx * dx + dy * dy + dz * dz)
                                if d < bestDist then bestArea, bestId, bestDist = areaId, i, d end
                            end
                        end
                    end
                end
            end
        end
    end
    if not bestId then return false end
    return bestArea, bestId, bestDist
end

function Paths.getLoadedArea(id) return areas[id] end
