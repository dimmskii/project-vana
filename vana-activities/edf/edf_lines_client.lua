-- Map Editor helper (loaded by our EDF definitions): draws how placed elements connect. Paths (each
-- point's nextid, and spot sets marked as routes) as arrows; links to another element (a burglary
-- door's house) and exit points (ex, ey, ez: where an entrance or door puts you) as lines; the
-- path graph (vana-paths: pathnode, pathlink) as roads and footpaths. Only near the camera.
-- /vanalines toggles it. Copied into each resource whose EDF links elements (tools/sync-libs.sh).
local LINKS = { -- element type -> { property, colour, arrow }
    racecheckpoint = { { "nextid", tocolor(255, 210, 0, 230), true } },
    routepoint = { { "nextid", tocolor(128, 255, 0, 230), true } },
    burglarydoor = { { "house", tocolor(255, 170, 0, 140), false } },
}
-- ex, ey, ez: where an entrance or door puts you, or where a creature walks to.
local EXITS = { entrance = tocolor(255, 220, 0, 200), burglarydoor = tocolor(255, 120, 0, 200), burglaryhouse = tocolor(255, 120, 0, 200),
                encounter = tocolor(150, 100, 60, 220) }
local RANGE = 300
local shown = true

addCommandHandler("vanalines", function()
    shown = not shown
    outputChatBox("Vana editor lines " .. (shown and "on" or "off"))
end)

local function edf(fn, ...)
    local ok, a, b, c = pcall(function(...) return exports.edf[fn](exports.edf, ...) end, ...)
    if ok then return a, b, c end
end

local function positionOf(element)
    local x, y, z = edf("edfGetElementPosition", element)
    if not x then x, y, z = getElementPosition(element) end
    return x, y, z
end

local function arrow(sx, sy, sz, dx, dy, dz, colour)
    dxDrawLine3D(sx, sy, sz + 1, dx, dy, dz + 1, colour, 3)
    local vx, vy = dx - sx, dy - sy
    local len = math.sqrt(vx * vx + vy * vy)
    if len < 1 then return end
    vx, vy = vx / len, vy / len
    local bx, by = dx - vx * 3, dy - vy * 3
    dxDrawLine3D(dx, dy, dz + 1, bx + vy * 1.5, by - vx * 1.5, dz + 1, colour, 3)
    dxDrawLine3D(dx, dy, dz + 1, bx - vy * 1.5, by + vx * 1.5, dz + 1, colour, 3)
end

-- The path graph. Kept as a snapshot of what's near the camera, refreshed twice a second (asking the
-- editor for every element's properties each frame is too slow: an area has thousands): each link
-- as a curve from node through its navi node (where a vehicle link stands) to node, coloured by the
-- nodes' type, an arrow where it's one-way; traffic lights, train and ped crossings marked.
local PATH_RANGE = 180
local PATH_COLOURS = { road = { 64, 192, 255 }, highway = { 255, 150, 0 }, boats = { 40, 90, 255 }, emergency = { 255, 60, 60 },
                       parking = { 180, 90, 255 }, ped = { 80, 230, 80 } }
local pathSnapshot, pathSnapshotAt = {}, 0

local function prop(element, name)
    local v = edf("edfGetElementProperty", element, name)
    if v == "true" then return true elseif v == "false" then return false end
    return v
end

local function nodeStyle(node)
    if prop(node, "kind") ~= "vehicle" then return "ped" end
    if prop(node, "boats") then return "boats" end
    if prop(node, "emergency") then return "emergency" end
    if prop(node, "parking") then return "parking" end
    if prop(node, "highway") then return "highway" end
    return "road"
end

local function snapshotPaths(cx, cy, cz)
    local list = {}
    local styles = {}
    local function style(node)
        if styles[node] == nil then
            local traffic = tonumber(prop(node, "traffic")) or 0
            styles[node] = { nodeStyle(node), traffic }
        end
        return styles[node]
    end
    for _, link in ipairs(getElementsByType("pathlink")) do
        local lx, ly, lz = positionOf(link)
        if lx and getDistanceBetweenPoints3D(cx, cy, cz, lx, ly, lz) < PATH_RANGE then
            local a, b = getElementByID(tostring(prop(link, "a"))), getElementByID(tostring(prop(link, "b")))
            local item = { navi = { lx, ly, lz } }
            if a then item.a = { positionOf(a) } end
            if b then item.b = { positionOf(b) } end
            local s = (a and style(a)) or (b and style(b)) or { "road", 0 }
            local c = PATH_COLOURS[s[1]]
            local fade = 1 - 0.18 * s[2] -- quieter traffic, dimmer
            item.colour = tocolor(c[1] * fade, c[2] * fade, c[3] * fade, 220)
            item.vehicle = prop(link, "dir") ~= nil and prop(link, "dir") ~= ""
            if item.vehicle then
                local left, right = tonumber(prop(link, "lanesLeft")) or 1, tonumber(prop(link, "lanesRight")) or 1
                -- Left lanes run toward the navi node's own node (naviNode, else a), right lanes away.
                local own = prop(link, "naviNode")
                local ownIsB = own and own ~= "" and own == prop(link, "b")
                if left > 0 and right == 0 then item.oneway = ownIsB and "b" or "a"
                elseif right > 0 and left == 0 then item.oneway = ownIsB and "a" or "b" end
                item.light = (tonumber(prop(link, "light")) or 0) > 0
                item.train = prop(link, "train") == true
            end
            item.crossing = (tonumber(prop(link, "crossingA")) or 0) > 0 or (tonumber(prop(link, "crossingB")) or 0) > 0
            list[#list + 1] = item
        end
    end
    for _, node in ipairs(getElementsByType("pathnode")) do
        local x, y, z = positionOf(node)
        if x and getDistanceBetweenPoints3D(cx, cy, cz, x, y, z) < PATH_RANGE then
            local c = PATH_COLOURS[style(node)[1]]
            list[#list + 1] = { dot = { x, y, z }, colour = tocolor(c[1], c[2], c[3], 255) }
        end
    end
    return list
end

local function bezier(p0, p1, p2, t)
    local u = 1 - t
    return u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1], u * u * p0[2] + 2 * u * t * p1[2] + t * t * p2[2],
        u * u * p0[3] + 2 * u * t * p1[3] + t * t * p2[3]
end

local function drawPaths()
    local cx, cy, cz = getCameraMatrix()
    local now = getTickCount()
    if now - pathSnapshotAt > 500 then
        pathSnapshot, pathSnapshotAt = snapshotPaths(cx, cy, cz), now
    end
    local up = 0.3
    for _, it in ipairs(pathSnapshot) do
        if it.dot then
            local x, y, z = it.dot[1], it.dot[2], it.dot[3] + up
            dxDrawLine3D(x - 0.35, y, z, x + 0.35, y, z, it.colour, 4)
            dxDrawLine3D(x, y - 0.35, z, x, y + 0.35, z, it.colour, 4)
        elseif it.a and it.b then
            local a, b = it.a, it.b
            local width = it.crossing and 5 or 2
            local colour = it.crossing and tocolor(255, 230, 0, 230) or it.colour
            if it.vehicle then
                local px, py, pz = a[1], a[2], a[3]
                for k = 1, 8 do
                    local x, y, z = bezier(a, it.navi, b, k / 8)
                    dxDrawLine3D(px, py, pz + up, x, y, z + up, colour, width)
                    px, py, pz = x, y, z
                end
            else
                dxDrawLine3D(a[1], a[2], a[3] + up, b[1], b[2], b[3] + up, colour, width)
            end
            if it.oneway then
                local from, to = it.oneway == "a" and b or a, it.oneway == "a" and a or b
                -- the arrowhead halfway, along the curve
                local mx, my, mz = bezier(from, it.navi, to, 0.5)
                local nx, ny = bezier(from, it.navi, to, 0.55)
                local vx, vy = nx - mx, ny - my
                local len = math.sqrt(vx * vx + vy * vy)
                if len > 0 then
                    vx, vy = vx / len, vy / len
                    dxDrawLine3D(mx + vx, my + vy, mz + up, mx - vx * 0.8 + vy * 0.9, my - vy * 0.8 - vx * 0.9, mz + up, colour, 4)
                    dxDrawLine3D(mx + vx, my + vy, mz + up, mx - vx * 0.8 - vy * 0.9, my - vy * 0.8 + vx * 0.9, mz + up, colour, 4)
                end
            end
            if it.light or it.train then
                local n = it.navi
                local c = it.train and tocolor(255, 255, 255, 255) or tocolor(255, 220, 0, 255)
                dxDrawLine3D(n[1] - 0.6, n[2] - 0.6, n[3] + up + 0.5, n[1] + 0.6, n[2] + 0.6, n[3] + up + 0.5, c, 5)
                dxDrawLine3D(n[1] - 0.6, n[2] + 0.6, n[3] + up + 0.5, n[1] + 0.6, n[2] - 0.6, n[3] + up + 0.5, c, 5)
            end
        elseif it.a or it.b then
            -- the other end is in an area that isn't open: a stub toward it
            local e = it.a or it.b
            dxDrawLine3D(e[1], e[2], e[3] + up, it.navi[1], it.navi[2], it.navi[3] + up, tocolor(255, 80, 80, 200), 2)
        end
    end
end

addEventHandler("onClientRender", root, function()
    if not shown then return end
    drawPaths()
    local cx, cy, cz = getCameraMatrix()
    local function near(x, y, z) return x and getDistanceBetweenPoints3D(cx, cy, cz, x, y, z) < RANGE end
    for elementType, links in pairs(LINKS) do
        for _, element in ipairs(getElementsByType(elementType)) do
            local sx, sy, sz = positionOf(element)
            if near(sx, sy, sz) then
                for _, link in ipairs(links) do
                    local target = edf("edfGetElementProperty", element, link[1])
                    if type(target) == "string" then target = getElementByID(target) end
                    if isElement(target) then
                        local dx, dy, dz = positionOf(target)
                        if link[3] then arrow(sx, sy, sz, dx, dy, dz, link[2]) else dxDrawLine3D(sx, sy, sz + 1, dx, dy, dz + 1, link[2], 2) end
                    end
                end
            end
        end
    end
    -- Spot sets marked as routes (triathlon checkpoints, flight rings): arrows in index order.
    local routes = {}
    for _, element in ipairs(getElementsByType("spot")) do
        local path = edf("edfGetElementProperty", element, "path")
        if path == true or path == "true" then
            local set = edf("edfGetElementProperty", element, "set")
            routes[set] = routes[set] or {}
            table.insert(routes[set], { element = element, index = tonumber(edf("edfGetElementProperty", element, "index")) or 0 })
        end
    end
    for _, list in pairs(routes) do
        table.sort(list, function(a, b) return a.index < b.index end)
        for i = 1, #list - 1 do
            local sx, sy, sz = positionOf(list[i].element)
            if near(sx, sy, sz) then
                local dx, dy, dz = positionOf(list[i + 1].element)
                arrow(sx, sy, sz, dx, dy, dz, tocolor(176, 96, 255, 230))
            end
        end
    end
    for elementType, colour in pairs(EXITS) do
        for _, element in ipairs(getElementsByType(elementType)) do
            local sx, sy, sz = positionOf(element)
            local ex = tonumber(edf("edfGetElementProperty", element, "ex"))
            local ey = tonumber(edf("edfGetElementProperty", element, "ey"))
            local ez = tonumber(edf("edfGetElementProperty", element, "ez"))
            if ex and ey and ez and near(sx, sy, sz) and getDistanceBetweenPoints3D(sx, sy, sz, ex, ey, ez) < RANGE then
                dxDrawLine3D(sx, sy, sz + 0.5, ex, ey, ez + 0.5, colour, 1.5)
                dxDrawLine3D(ex - 0.4, ey, ez + 0.5, ex + 0.4, ey, ez + 0.5, colour, 3)
                dxDrawLine3D(ex, ey - 0.4, ez + 0.5, ex, ey + 0.4, ez + 0.5, colour, 3)
            end
        end
    end
end)
