-- One-time conversion of GTA:SA's path graph (data/Paths/NODES0-63.DAT) into map data: one map
-- resource per area, [data]/[paths]/vana-data-paths-NN (vana-paths/paths_data.lua says what's in
-- them), and the vana-paths EDF. Then reads them back the way the game does and checks every node,
-- link and navi node against the DAT files.
-- usage (from the repo root): lua5.1 tools/convert/paths_to_maps.lua [folder with NODES*.DAT]
dofile("vana-lib/lib/map_data.lua")
dofile("vana-paths/paths_format.lua")
dofile("vana-paths/paths_data.lua")

local from = arg[1] or "vana-paths/data"
local OUT = "[data]/[paths]"

local function xml(s)
    return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end
local function unxml(s)
    return (s:gsub("&quot;", '"'):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&"))
end
local function writeFile(path, text)
    os.execute(("mkdir -p %q"):format(path:match("^(.*)/")))
    local f = assert(io.open(path, "w"))
    f:write(text)
    f:close()
end

local areas = {}
for id = 0, 63 do
    local f = assert(io.open(("%s/NODES%d.DAT"):format(from, id), "rb"), "missing NODES" .. id .. ".DAT in " .. from)
    local s = f:read("*a")
    f:close()
    areas[id] = assert(PathsFormat.parse(id, s))
end

local byArea = PathsData.toRecords(areas)
local schemas = {}
for _, schema in ipairs(PathsData.schemas) do schemas[schema.element] = schema end
-- A field at its default isn't written (reading gives the default back): most of a node's flags.
local defaults = {}
for _, schema in ipairs(PathsData.schemas) do
    defaults[schema.element] = {}
    for _, f in ipairs(schema.fields) do
        if f[3] ~= nil then defaults[schema.element][f[1]] = type(f[3]) == "number" and MapData.number(f[3]) or tostring(f[3]) end
    end
end
local counts = { pathnode = 0, pathlink = 0 }
for id = 0, 63 do
    local name = PathsData.resourceName(id)
    local out = { '<map edf:definitions="vana-paths">' }
    for _, schema in ipairs(PathsData.schemas) do
        for _, rec in ipairs(byArea[id][schema.element]) do
            local attrs = {}
            for _, at in ipairs(MapData.toAttributes(schema, rec)) do
                if defaults[schema.element][at[1]] ~= at[2] then attrs[#attrs + 1] = ('%s="%s"'):format(at[1], xml(at[2])) end
            end
            out[#out + 1] = ("    <%s %s />"):format(schema.element, table.concat(attrs, " "))
            counts[schema.element] = (counts[schema.element] or 0) + 1
        end
    end
    out[#out + 1] = "</map>\n"
    writeFile(OUT .. "/" .. name .. "/paths.map", table.concat(out, "\n"))
    writeFile(OUT .. "/" .. name .. "/meta.xml", ([[
<meta>
    <info type="map" name="%s" author="ProjectVana" description="Path graph, area %d (GTA:SA's NODES%d): open it in the Map Editor (definitions: vana-paths)" version="1.0.0" edf:definitions="vana-paths" />
    <map src="paths.map" dimension="0" />
</meta>
]]):format(name, id, id))
end
print(("wrote 64 areas: %d nodes, %d links -> %s/vana-data-paths-NN"):format(counts.pathnode, counts.pathlink, OUT))

-- Back as the game reads them: attributes -> records -> each area's tables.
local cache = {}
local function recordsOf(id)
    if cache[id] ~= nil then return cache[id] end
    local f = io.open(OUT .. "/" .. PathsData.resourceName(id) .. "/paths.map")
    if not f then cache[id] = false return false end
    local recs = { pathnode = {}, pathlink = {}, patharea = {} }
    for line in f:lines() do
        local tag, body = line:match("^%s*<([%w_]+)%s(.-)/>%s*$")
        if tag and schemas[tag] then
            local attr = {}
            for k, v in body:gmatch('([%w_:]+)="(.-)"') do attr[k] = unxml(v) end
            table.insert(recs[tag], PathsData.decode(tag, attr))
        end
    end
    f:close()
    cache[id] = recs
    return recs
end

local rebuilt = {}
local infos = {}
for id = 0, 63 do rebuilt[id] = assert(PathsData.buildArea(id, recordsOf, infos)) end

-- The check: everything the game reads, per node and per link (by its other end, as a node's
-- list order isn't kept; navi nodes by content, as their numbering may shift).
local problems, checked = {}, 0
local function bad(fmt, ...) if #problems < 20 then problems[#problems + 1] = fmt:format(...) end end
local function navi(t, v)
    local A = t[math.floor(v / 1024)]
    local k = v % 1024
    return A and A.naviX[k] and table.concat({ A.naviX[k], A.naviY[k], A.naviDirX[k], A.naviDirY[k], A.naviFlags[k], A.naviArea[k], A.naviNode[k] }, "/")
end
for id = 0, 63 do
    local o, r = areas[id], rebuilt[id]
    if o.nodeCount ~= r.nodeCount or o.vehCount ~= r.vehCount then bad("area %d: %d/%d nodes, now %d/%d", id, o.nodeCount, o.vehCount, r.nodeCount, r.vehCount) end
    for i = 0, o.nodeCount - 1 do
        checked = checked + 1
        for _, key in ipairs({ "x", "y", "z", "width", "flood", "flags" }) do
            if o[key][i] ~= r[key][i] then bad("node %d.%d %s: %s, now %s", id, i, key, tostring(o[key][i]), tostring(r[key][i])) end
        end
        local function entries(t)
            local list = {}
            for e = t.linkStart[i], t.linkStart[i] + (t.flags[i] % 16) - 1 do
                list[t.linkArea[e] .. "." .. t.linkNode[e]] = { t.linkLength[e], t.linkFlags[e], i < t.vehCount and navi(t == o and areas or rebuilt, t.linkNavi[e]) or "-" }
            end
            return list
        end
        local eo, er = entries(o), entries(r)
        for other, v in pairs(eo) do
            local w = er[other]
            if not w then bad("node %d.%d: lost its link to %s", id, i, other)
            elseif v[1] ~= w[1] or v[2] ~= w[2] or v[3] ~= w[3] then
                bad("node %d.%d -> %s: length/flags/navi %s/%s/%s, now %s/%s/%s", id, i, other, v[1], v[2], tostring(v[3]), w[1], w[2], tostring(w[3]))
            end
        end
        for other in pairs(er) do if not eo[other] then bad("node %d.%d: gained a link to %s", id, i, other) end end
    end
    local tr = recordsOf(id).patharea[1]
    local parts = {}
    for k = 1, #o.trailer do local v = o.trailer:byte(k) if v ~= 0 then parts[#parts + 1] = (k - 1) .. ":" .. v end end
    if (tr and tr.trailer or "") ~= table.concat(parts, ",") then bad("area %d: trailer differs", id) end
end
for _, p in ipairs(problems) do print("FAIL " .. p) end
print(#problems == 0 and ("PASS: %d nodes and their links read back as the DAT files have them"):format(checked) or "FAIL")
os.exit(#problems == 0 and 0 or 1)
