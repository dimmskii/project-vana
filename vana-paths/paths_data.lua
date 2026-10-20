-- The path graph as map data: GTA:SA's NODES<area>.DAT as elements in [data]/[paths]/vana-data-paths-NN,
-- one map resource per area (the game's own split), and back. Plain Lua: the converter
-- (tools/convert/paths_to_maps.lua) and the game (paths.lua) share it.
--   pathnode  a node, id "area.index" (the game's own): position, vehicle or ped, width, flood fill,
--             and its flags decoded (traffic, spawn, roadblocks, boats, emergency, highway, parking)
--   pathlink  a connection between two nodes (the game stores each one in both nodes' lists): a, b;
--             a vehicle link also holds its navi node (the lane point between them, where the
--             element stands; a ped link stands at its middle): direction, lane width and lanes,
--             traffic light; per side, the crossing flags; its length only where it isn't the
--             distance rounded down. A link crossing areas lives in its navi's area (ped: a's)
--   patharea  what else an area's file held (its 384-byte trailer, a few 1s and 3s)
-- Not kept: the filler block (always 0000FFFF), the nodes' runtime pointer and constant cost,
-- their stored link start and count, and the order within each node's link list (rebuilt).
PathsData = {}

local floor = math.floor

function PathsData.resourceName(area) return ("vana-data-paths-%02d"):format(area) end
function PathsData.areaOfResource(name) return tonumber(name:match("^vana%-data%-paths%-(%d+)$")) end

local function bits(v, from, width) return floor(v / 2 ^ from) % 2 ^ width end
local function bool(v) return v == 1 end
local function b(v) return v and 1 or 0 end

-- Node flags: link count (0-3, from the links), traffic (4-5), roadblocks (6), boats (7),
-- emergency only (8), not highway (12), highway (13), spawn probability (16-19), parking (21);
-- anything else kept as extraFlags.
function PathsData.decodeNodeFlags(f)
    local d = {
        traffic = bits(f, 4, 2), roadblocks = bool(bits(f, 6, 1)), boats = bool(bits(f, 7, 1)),
        emergency = bool(bits(f, 8, 1)), notHighway = bool(bits(f, 12, 1)), highway = bool(bits(f, 13, 1)),
        spawn = bits(f, 16, 4), parking = bool(bits(f, 21, 1)),
    }
    d.extraFlags = f - PathsData.encodeNodeFlags(d, bits(f, 0, 4))
    return d
end

function PathsData.encodeNodeFlags(d, linkCount)
    return (linkCount or 0) + d.traffic * 16 + b(d.roadblocks) * 64 + b(d.boats) * 128 + b(d.emergency) * 256
        + b(d.notHighway) * 4096 + b(d.highway) * 8192 + d.spawn * 65536 + b(d.parking) * 2097152 + (d.extraFlags or 0)
end

-- Navi flags: width (0-7, eighths of a metre), left lanes (8-10), right lanes (11-13), traffic light
-- direction (14), traffic light (16-17: 0 none, 1 north-south, 2 west-east), train crossing (18).
function PathsData.decodeNaviFlags(f)
    local d = {
        width = bits(f, 0, 8) / 8, lanesLeft = bits(f, 8, 3), lanesRight = bits(f, 11, 3),
        lightDir = bool(bits(f, 14, 1)), light = bits(f, 16, 2), train = bool(bits(f, 18, 1)),
    }
    d.extraFlags = f - PathsData.encodeNaviFlags(d)
    return d
end

function PathsData.encodeNaviFlags(d)
    return floor(d.width * 8 + 0.5) + d.lanesLeft * 256 + d.lanesRight * 2048 + b(d.lightDir) * 16384
        + d.light * 65536 + b(d.train) * 262144 + (d.extraFlags or 0)
end

-- A link's length as the game would have it: the 3D distance rounded down, at most 255.
function PathsData.linkLength(x1, y1, z1, x2, y2, z2)
    local dx, dy, dz = x2 - x1, y2 - y1, z2 - z1
    return math.min(255, floor(math.sqrt(dx * dx + dy * dy + dz * dz)))
end

-- The element schemas (vana-lib's map_data format); defaults are the commonest values, left out
-- of the files.
local nodeFields = {
    { "kind", "string", "ped", "vehicle or ped (a vehicle node is a road, boat or emergency path)" },
    { "width", "number", 2, "path width (m, in eighths)" },
    { "flood", "int", 1, "flood fill: which connected network it belongs to (routing only joins nodes of one)" },
    { "traffic", "int", 0, "traffic level, 0 (full) to 3 (none)" },
    { "spawn", "int", 15, "spawn probability, 0-15" },
    { "roadblocks", "bool", false, "police roadblocks can be set up here" },
    { "boats", "bool", false, "a boat path" },
    { "emergency", "bool", false, "emergency vehicles only" },
    { "highway", "bool", false, "a highway" },
    { "notHighway", "bool", false, "explicitly not a highway" },
    { "parking", "bool", false, "a parking spot" },
    { "extraFlags", "int", 0, "flag bits with no known meaning, kept as the game had them" },
}
local linkFields = {
    { "a", "string", nil, "one end: a pathnode id (area.index); a vehicle link's navi node is a's unless naviNode says" },
    { "b", "string", nil, "the other end" },
    { "naviNode", "string", nil, "the node this link's navi node belongs to, when it isn't a" },
    { "dir", "numbers", nil, "vehicle link: the lane direction at its navi node (x,y, hundredths)" },
    { "width", "number", 0, "vehicle link: the lane width at its navi node (m, in eighths)" },
    { "lanesLeft", "int", 1, "vehicle link: lanes one way" },
    { "lanesRight", "int", 1, "vehicle link: lanes the other way" },
    { "lightDir", "bool", false, "vehicle link: the traffic light governs traffic heading to the navi node's node" },
    { "light", "int", 0, "vehicle link: traffic light, 0 none, 1 north-south, 2 west-east" },
    { "train", "bool", false, "vehicle link: a train crossing" },
    { "extraFlags", "int", 0, "vehicle link: navi flag bits with no known meaning" },
    { "crossingA", "int", 0, "flags on a's side: 1 a road crossing, 2 a ped traffic light (3 both)" },
    { "crossingB", "int", 0, "flags on b's side" },
    { "length", "int", nil, "its length when it isn't the distance rounded down" },
}
PathsData.schemas = {
    { element = "pathnode", friendly = "Path node", position = true, id = "id", fields = nodeFields,
      rep = '<marker type="corona" size="0.6" color="#40C0FF90" />' },
    { element = "pathlink", friendly = "Path link", position = true, fields = linkFields,
      rep = '<marker type="corona" size="0.4" color="#FFD04090" />' },
    { element = "patharea", friendly = "Path area", position = true, id = "id",
      fields = { { "trailer", "string", nil, "the 384 bytes after its links: index:value pairs of the non-zero ones" } },
      rep = '<marker type="corona" size="2" color="#FFFFFF40" />' },
}

-- The areas as the converter reads them (PathsFormat.parse, by area id) -> each area's element
-- records for its file: { [area] = { pathnode = {...}, pathlink = {...}, patharea = {...} } }.
function PathsData.toRecords(areas)
    local out = {}
    local function nid(ar, i) return ar .. "." .. i end
    for areaId, A in pairs(areas) do
        local nodes = {}
        for i = 0, A.nodeCount - 1 do
            local d = PathsData.decodeNodeFlags(A.flags[i])
            d.id, d.x, d.y, d.z = nid(areaId, i), A.x[i], A.y[i], A.z[i]
            d.kind = i < A.vehCount and "vehicle" or "ped"
            d.width, d.flood = A.width[i], A.flood[i]
            nodes[#nodes + 1] = d
        end
        local area = { id = "area" .. areaId, x = (areaId % 8) * 750 - 3000 + 375, y = floor(areaId / 8) * 750 - 3000 + 375, z = 0 }
        if A.trailer then
            local parts = {}
            for k = 1, #A.trailer do
                local v = A.trailer:byte(k)
                if v ~= 0 then parts[#parts + 1] = (k - 1) .. ":" .. v end
            end
            if #parts > 0 then area.trailer = table.concat(parts, ",") end
        end
        out[areaId] = { pathnode = nodes, pathlink = {}, patharea = { area } }
    end
    -- Each connection once, from the entry that speaks for it: a vehicle link from its navi node's
    -- own node's side (else the lower id's), filed in the navi's area; a ped link from the lower
    -- id, in its area.
    for ar, B in pairs(areas) do
        for i = 0, B.nodeCount - 1 do
            for e = B.linkStart[i], B.linkStart[i] + bits(B.flags[i], 0, 4) - 1 do
                local oa, oi = B.linkArea[e], B.linkNode[e]
                local lower = ar < oa or (ar == oa and i < oi)
                local isVehicle = i < B.vehCount
                local naviArea, naviIndex, mine, home
                if isVehicle then
                    naviArea, naviIndex = floor(B.linkNavi[e] / 1024), B.linkNavi[e] % 1024
                    local N = areas[naviArea]
                    local attA, attI = N.naviArea[naviIndex], N.naviNode[naviIndex]
                    local attachedHere = attA == ar and attI == i
                    local attachedThere = attA == oa and attI == oi
                    mine, home = attachedHere or (not attachedThere and lower), naviArea
                else
                    mine, home = lower, ar
                end
                if mine then
                    local O = areas[oa]
                    local back
                    for r = O.linkStart[oi], O.linkStart[oi] + bits(O.flags[oi], 0, 4) - 1 do
                        if O.linkArea[r] == ar and O.linkNode[r] == i then back = r break end
                    end
                    local rec = { a = nid(ar, i), b = nid(oa, oi), crossingA = B.linkFlags[e], crossingB = back and O.linkFlags[back] or 0 }
                    if B.linkLength[e] ~= PathsData.linkLength(B.x[i], B.y[i], B.z[i], O.x[oi], O.y[oi], O.z[oi]) then rec.length = B.linkLength[e] end
                    if isVehicle then
                        local N = areas[naviArea]
                        for k, v in pairs(PathsData.decodeNaviFlags(N.naviFlags[naviIndex])) do rec[k] = v end
                        rec.x, rec.y, rec.z = N.naviX[naviIndex], N.naviY[naviIndex], (B.z[i] + O.z[oi]) / 2
                        rec.dir = { N.naviDirX[naviIndex], N.naviDirY[naviIndex] }
                        local attA, attI = N.naviArea[naviIndex], N.naviNode[naviIndex]
                        if not (attA == ar and attI == i) then rec.naviNode = nid(attA, attI) end
                        rec.order = naviIndex -- in navi order, so their indices come back the same
                    else
                        rec.x, rec.y, rec.z = (B.x[i] + O.x[oi]) / 2, (B.y[i] + O.y[oi]) / 2, (B.z[i] + O.z[oi]) / 2
                        rec.order = 100000 + ar * 100000 + i
                    end
                    table.insert(out[home].pathlink, rec)
                end
            end
        end
    end
    for _, recs in pairs(out) do
        table.sort(recs.pathlink, function(p, q) return p.order < q.order end)
        for _, l in ipairs(recs.pathlink) do l.order = nil end
    end
    return out
end

-- Element attributes (strings, as in the file) -> a record, fast: defaults worked out once per
-- schema (there are 140,000 of these). Gives what MapData.fromAttributes would.
local decoders = {}
function PathsData.decode(element, attr)
    local d = decoders[element]
    if not d then
        local schema
        for _, sc in ipairs(PathsData.schemas) do if sc.element == element then schema = sc end end
        if not schema then return nil end
        d = {}
        for _, f in ipairs(schema.fields) do
            local default = f[3]
            if f[2] == "numbers" and type(default) == "string" then default = nil end
            d[#d + 1] = { f[1], f[2], default }
        end
        decoders[element] = d
    end
    local rec = { id = attr.id, x = tonumber(attr.posX), y = tonumber(attr.posY), z = tonumber(attr.posZ) }
    for i = 1, #d do
        local f = d[i]
        local v = attr[f[1]]
        if v == nil or v == "" then
            rec[f[1]] = f[3]
        elseif f[2] == "number" or f[2] == "int" then
            rec[f[1]] = tonumber(v)
        elseif f[2] == "bool" then
            rec[f[1]] = v == "true"
        elseif f[2] == "numbers" then
            local p, q = v:match("^%s*([^,]+)%s*,%s*([^,]+)%s*$")
            rec[f[1]] = { tonumber(p), tonumber(q) }
        else
            rec[f[1]] = v
        end
    end
    return rec
end

local NEIGHBOURS = { -9, -8, -7, -1, 1, 7, 8, 9 }

-- An area's tables (the shape PathsFormat.parse gives: 0-based parallel arrays) from element
-- records. recordsOf(area) gives an area's { pathnode = {...}, pathlink = {...} } (or nil); links
-- into this area from its neighbours' files are found there. infos: a table kept between calls
-- (each area's node index, built once).
function PathsData.buildArea(areaId, recordsOf, infos)
    local own = recordsOf(areaId)
    if not own then return false end
    infos = infos or {}
    -- Per area: node index by id (the id's own where it's "area.index", vehicle nodes first as the
    -- game needs; anything new or out of place the next free one), the ordered nodes, and each
    -- vehicle link's navi index (its place among the file's vehicle links).
    local function infoOf(ar)
        if infos[ar] ~= nil then return infos[ar] end
        local recs = ar >= 0 and ar < 64 and recordsOf(ar)
        if not recs then infos[ar] = false return false end
        local veh, ped = {}, {}
        for _, n in ipairs(recs.pathnode or {}) do
            if n.kind == "vehicle" then veh[#veh + 1] = n else ped[#ped + 1] = n end
        end
        local key = {}
        for _, n in ipairs(recs.pathnode or {}) do key[n] = tonumber(n.id:match("%.(%d+)$")) or 1e9 end
        local function byIndex(p, q)
            local pi, qi = key[p], key[q]
            if pi ~= qi then return pi < qi end
            return p.id < q.id
        end
        table.sort(veh, byIndex)
        table.sort(ped, byIndex)
        local list, index, navi = {}, {}, {}
        for _, n in ipairs(veh) do list[#list + 1] = n end
        for _, n in ipairs(ped) do list[#list + 1] = n end
        for i, n in ipairs(list) do index[n.id] = i - 1 end
        local k = 0
        for _, l in ipairs(recs.pathlink or {}) do
            if l.dir then navi[l] = ar * 1024 + k; k = k + 1 end
        end
        infos[ar] = { recs = recs, list = list, index = index, vehCount = #veh, navi = navi, naviCount = k, area = ar }
        return infos[ar]
    end
    -- A node id -> its area, index and record: in the area its id names, else this area or a neighbour.
    local function resolve(id)
        local named = tonumber(id:match("^(%d+)%."))
        local info = infoOf(named or areaId)
        if info and info.index[id] then return info.area, info.index[id], info.list[info.index[id] + 1] end
        for k = 0, #NEIGHBOURS do
            local ar = k == 0 and areaId or areaId + NEIGHBOURS[k]
            info = infoOf(ar)
            if info and info.index[id] then return ar, info.index[id], info.list[info.index[id] + 1] end
        end
    end
    -- A link's two ends, resolved once (kept on the record).
    local function ends(l)
        if l.ends == nil then
            local aa, ai, an = resolve(l.a)
            local ba, bi, bn = resolve(l.b)
            l.ends = aa and ba and { aa, ai, an, ba, bi, bn } or false
        end
        return l.ends
    end
    -- A file's links that reach another area (what a neighbour needs from it), found once.
    local function crossOf(info)
        if info.cross then return info.cross end
        info.cross = {}
        for _, l in ipairs(info.recs.pathlink or {}) do
            local e = ends(l)
            if e and (e[1] ~= info.area or e[4] ~= info.area) then info.cross[#info.cross + 1] = l end
        end
        return info.cross
    end
    local me = infoOf(areaId)
    local a = {
        id = areaId, nodeCount = #me.list, vehCount = me.vehCount, pedCount = #me.list - me.vehCount, naviCount = me.naviCount,
        x = {}, y = {}, z = {}, width = {}, flood = {}, flags = {}, linkStart = {},
        naviX = {}, naviY = {}, naviArea = {}, naviNode = {}, naviDirX = {}, naviDirY = {}, naviFlags = {},
        linkArea = {}, linkNode = {}, linkNavi = {}, linkLength = {}, linkFlags = {},
    }
    for i, n in ipairs(me.list) do
        local k = i - 1
        a.x[k], a.y[k], a.z[k], a.width[k], a.flood[k] = n.x, n.y, n.z, n.width, n.flood
    end
    for _, l in ipairs(own.pathlink or {}) do
        local v = me.navi[l]
        if v then
            local k = v % 1024
            a.naviX[k], a.naviY[k] = l.x, l.y
            a.naviDirX[k], a.naviDirY[k] = l.dir[1], l.dir[2]
            a.naviFlags[k] = PathsData.encodeNaviFlags(l)
            local ar, i = resolve(l.naviNode or l.a)
            a.naviArea[k], a.naviNode[k] = ar or areaId, i or 0
        end
    end
    -- Each node's links: every link naming it, in this file or a neighbour's (a link crossing areas
    -- lives in one of them).
    local entries = {}
    local function addLinks(info, links)
        for _, l in ipairs(links) do
            local e = ends(l)
            if e then
                local aa, ai, an, ba, bi, bn = e[1], e[2], e[3], e[4], e[5], e[6]
                local navi = info.navi[l] or 0
                local len = l.length or PathsData.linkLength(an.x, an.y, an.z, bn.x, bn.y, bn.z)
                if aa == areaId then
                    entries[ai] = entries[ai] or {}
                    table.insert(entries[ai], { ba, bi, navi, l.crossingA or 0, len })
                end
                if ba == areaId then
                    entries[bi] = entries[bi] or {}
                    table.insert(entries[bi], { aa, ai, navi, l.crossingB or 0, len })
                end
            end
        end
    end
    addLinks(me, own.pathlink or {})
    for _, d in ipairs(NEIGHBOURS) do
        local info = infoOf(areaId + d)
        if info then addLinks(info, crossOf(info)) end
    end
    local linkCount = 0
    for k = 0, a.nodeCount - 1 do
        a.linkStart[k] = linkCount
        local mine = entries[k] or {}
        for _, e in ipairs(mine) do
            a.linkArea[linkCount], a.linkNode[linkCount], a.linkNavi[linkCount] = e[1], e[2], e[3]
            a.linkFlags[linkCount], a.linkLength[linkCount] = e[4], e[5]
            linkCount = linkCount + 1
        end
        a.flags[k] = PathsData.encodeNodeFlags(me.list[k + 1], math.min(15, #mine))
    end
    a.linkCount = linkCount
    return a
end
