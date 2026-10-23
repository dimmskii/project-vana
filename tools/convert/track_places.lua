-- Works out where trains meet the rest of the world, from the map data we ship (no game files): every
-- road and footpath link of the path graph ([data]/[paths]) that crosses a track of
-- [data]/vana-data-trains at the same height, and the platform spots at the station stops (the ped
-- path nodes on the platform beside each). Writes crossings.map and platforms.map into
-- vana-data-trains (vana-trains/tracks_data.lua says what's in them), replacing what they held, hand
-- edits included.
-- usage (from the repo root): lua5.1 tools/convert/track_places.lua
dofile("vana-lib/lib/map_data.lua")
dofile("vana-trains/tracks_data.lua")

local OUT = "[data]/" .. TracksData.resource
local SAME_HEIGHT = 3                 -- m between link and rail where they cross (more: a bridge or tunnel)
local PLATFORM_ALONG = 45             -- m either side of a stop along the track (the longest train stopping, halved)
local PLATFORM_FROM, PLATFORM_TO = 3, 16 -- m beside the track
local PLATFORM_ABOVE = { 0.2, 3.5 }   -- m above the rail
local PLATFORM_DEPTH = 4              -- m: nodes this much further out than the platform's edge still count

local function xml(s)
    return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end
local function unxml(s)
    return (s:gsub("&quot;", '"'):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&"))
end
local function elements(path, tag)
    local out = {}
    local f = assert(io.open(path), "missing " .. path)
    for line in f:lines() do
        local t, body = line:match("^%s*<([%w_]+)%s(.-)/>%s*$")
        if t == tag then
            local attr = {}
            for k, v in body:gmatch('([%w_:]+)="(.-)"') do attr[k] = unxml(v) end
            out[#out + 1] = attr
        end
    end
    f:close()
    return out
end
local function writeMap(file, schema, records)
    local out = { '<map edf:definitions="vana-trains">', ("    <!-- %s -->"):format(schema.friendly) }
    for _, rec in ipairs(records) do
        local attrs = {}
        for _, at in ipairs(MapData.toAttributes(schema, rec)) do attrs[#attrs + 1] = ('%s="%s"'):format(at[1], xml(at[2])) end
        out[#out + 1] = ("    <%s %s />"):format(schema.element, table.concat(attrs, " "))
    end
    out[#out + 1] = "</map>\n"
    local f = assert(io.open(OUT .. "/" .. file, "w"))
    f:write(table.concat(out, "\n"))
    f:close()
end

-- The tracks.
local tracknodes = {}
for _, attr in ipairs(elements(OUT .. "/tracks.map", "tracknode")) do
    tracknodes[#tracknodes + 1] = MapData.fromAttributes(TracksData.schemas[1], attr)
end
local tracks = assert(TracksData.build(tracknodes))

-- The path graph: nodes by id, links.
local nodes, links = {}, {}
for area = 0, 63 do
    local path = ("[data]/[paths]/vana-data-paths-%02d/paths.map"):format(area)
    for _, attr in ipairs(elements(path, "pathnode")) do
        nodes[attr.id] = { x = tonumber(attr.posX), y = tonumber(attr.posY), z = tonumber(attr.posZ),
                           kind = attr.kind or "ped", boats = attr.boats == "true" }
    end
    for _, attr in ipairs(elements(path, "pathlink")) do links[#links + 1] = { a = attr.a, b = attr.b } end
end

-- Track segments in a 100 m grid.
local GRID = 100
local grid = {}
local function cells(x0, y0, x1, y1, fn)
    for gx = math.floor(math.min(x0, x1) / GRID), math.floor(math.max(x0, x1) / GRID) do
        for gy = math.floor(math.min(y0, y1) / GRID), math.floor(math.max(y0, y1) / GRID) do fn(gx .. "," .. gy) end
    end
end
for track, t in pairs(tracks) do
    for i = 1, t.count do
        local j = i == t.count and 1 or i + 1
        -- The two lines that aren't loops don't join their ends.
        if j ~= 1 or track == 0 or track == 1 then
            local seg = { track = track, i = i, j = j }
            cells(t.x[i], t.y[i], t.x[j], t.y[j], function(key) grid[key] = grid[key] or {} table.insert(grid[key], seg) end)
        end
    end
end

-- Crossings: where a link and a segment cross in 2D, at the same height.
local crossings, seen = {}, {}
for _, link in ipairs(links) do
    local A, B = nodes[link.a], nodes[link.b]
    if A and B and not A.boats and not B.boats then
        local candidates = {}
        cells(A.x, A.y, B.x, B.y, function(key) for _, seg in ipairs(grid[key] or {}) do candidates[seg] = true end end)
        for seg in pairs(candidates) do
            local t = tracks[seg.track]
            local px, py, qx, qy = t.x[seg.i], t.y[seg.i], t.x[seg.j], t.y[seg.j]
            local d = (B.x - A.x) * (qy - py) - (B.y - A.y) * (qx - px)
            if math.abs(d) > 1e-9 then
                local u = ((px - A.x) * (qy - py) - (py - A.y) * (qx - px)) / d
                local v = ((px - A.x) * (B.y - A.y) - (py - A.y) * (B.x - A.x)) / d
                if u >= 0 and u <= 1 and v >= 0 and v <= 1 then
                    local zl = A.z + (B.z - A.z) * u
                    local zt = t.z[seg.i] + (t.z[seg.j] - t.z[seg.i]) * v
                    local id = ("%d:%s/%s"):format(seg.track, link.a, link.b)
                    if math.abs(zl - zt) < SAME_HEIGHT and not seen[id] then
                        seen[id] = true
                        crossings[#crossings + 1] = { id = id, x = A.x + (B.x - A.x) * u, y = A.y + (B.y - A.y) * u, z = zt,
                            track = seg.track, a = link.a, b = link.b, kind = A.kind == "vehicle" and "vehicle" or "ped" }
                    end
                end
            end
        end
    end
end
table.sort(crossings, function(p, q) return p.id < q.id end)

-- Platform spots: ped nodes beside each stop, on the side whose platform edge is nearest the track.
local spots = {}
local t0 = tracks[0]
for _, stop in ipairs(TracksData.stops(t0)) do
    local i = stop.index
    local j = i == t0.count and 1 or i + 1
    local dx, dy = t0.x[j] - t0.x[i], t0.y[j] - t0.y[i]
    local len = math.sqrt(dx * dx + dy * dy)
    dx, dy = dx / len, dy / len
    local found = { [1] = {}, [-1] = {} }
    local edge = { [1] = math.huge, [-1] = math.huge }
    for id, n in pairs(nodes) do
        if n.kind == "ped" then
            local ax, ay = n.x - stop.x, n.y - stop.y
            local along, lateral, above = ax * dx + ay * dy, ax * dy - ay * dx, n.z - stop.z
            if math.abs(along) <= PLATFORM_ALONG and math.abs(lateral) >= PLATFORM_FROM and math.abs(lateral) <= PLATFORM_TO
                and above >= PLATFORM_ABOVE[1] and above <= PLATFORM_ABOVE[2] then
                local side = lateral > 0 and 1 or -1
                table.insert(found[side], { id = id, n = n, lateral = math.abs(lateral) })
                edge[side] = math.min(edge[side], math.abs(lateral))
            end
        end
    end
    local side = edge[1] <= edge[-1] and 1 or -1
    if edge[side] < math.huge then
        table.sort(found[side], function(p, q) return p.id < q.id end)
        local k = 0
        for _, f in ipairs(found[side]) do
            if f.lateral <= edge[side] + PLATFORM_DEPTH then
                k = k + 1
                -- Facing the track: straight across it, toward the rails.
                local hx, hy = -side * dy, side * dx
                spots[#spots + 1] = { id = ("%s.%d"):format(TracksData.nodeId(0, i - 1), k), x = f.n.x, y = f.n.y, z = f.n.z,
                    heading = (math.deg(math.atan2(hy, hx)) - 90) % 360, stop = TracksData.nodeId(0, i - 1) }
            end
        end
    end
    print(("stop %s: %d platform spots"):format(TracksData.nodeId(0, i - 1), #spots - (spots.counted or 0)))
    spots.counted = #spots
end
spots.counted = nil

writeMap("crossings.map", TracksData.placeSchemas[1], crossings)
writeMap("platforms.map", TracksData.placeSchemas[2], spots)
local f = assert(io.open(OUT .. "/meta.xml", "w"))
f:write(([[
<meta>
    <info type="map" name="%s" author="ProjectVana" description="Railway tracks (GTA:SA's tracks*.dat), their crossings and platforms: open it in the Map Editor (definitions: vana-trains)" version="1.0.0" edf:definitions="vana-trains" />
    <map src="tracks.map" dimension="0" />
    <map src="crossings.map" dimension="0" />
    <map src="platforms.map" dimension="0" />
</meta>
]]):format(TracksData.resource))
f:close()
local byKind = {}
for _, c in ipairs(crossings) do byKind[c.kind .. " track " .. c.track] = (byKind[c.kind .. " track " .. c.track] or 0) + 1 end
for k, n in pairs(byKind) do print(("%-20s %d crossings"):format(k, n)) end
print(("wrote %d crossings, %d platform spots -> %s"):format(#crossings, #spots, OUT))
