-- One-time conversion of GTA:SA's railway tracks (data/Paths/tracks.dat, tracks2-4.dat) into map data:
-- [data]/vana-data-trains (vana-trains/tracks_data.lua says what's in it). Then reads it back the way the
-- game does and checks every node against the DAT files.
-- usage (from the repo root): lua5.1 tools/convert/tracks_to_maps.lua [folder with tracks*.dat]
dofile("vana-lib/lib/map_data.lua")
dofile("vana-trains/tracks_format.lua")
dofile("vana-trains/tracks_data.lua")

local from = arg[1] or "vana-trains/data"
local OUT = "[data]/" .. TracksData.resource

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

local tracks = {}
for track = 0, 3 do
    local name = TracksFormat.files[track]
    local f = assert(io.open(from .. "/" .. name, "rb"), "missing " .. name .. " in " .. from)
    local s = f:read("*a")
    f:close()
    tracks[track] = assert(TracksFormat.parse(name, s))
end

local schema = TracksData.schemas[1]
local records = TracksData.toRecords(tracks).tracknode
local out = { '<map edf:definitions="vana-trains">', ("    <!-- %s -->"):format(schema.friendly) }
for _, rec in ipairs(records) do
    local attrs = {}
    for _, at in ipairs(MapData.toAttributes(schema, rec)) do
        if not (at[1] == "stop" and at[2] == "false") then attrs[#attrs + 1] = ('%s="%s"'):format(at[1], xml(at[2])) end
    end
    out[#out + 1] = ("    <tracknode %s />"):format(table.concat(attrs, " "))
end
out[#out + 1] = "</map>\n"
writeFile(OUT .. "/tracks.map", table.concat(out, "\n"))
writeFile(OUT .. "/meta.xml", ([[
<meta>
    <info type="map" name="%s" author="ProjectVana" description="Railway tracks (GTA:SA's tracks*.dat): open it in the Map Editor (definitions: vana-trains)" version="1.0.0" edf:definitions="vana-trains" />
    <map src="tracks.map" dimension="0" />
</meta>
]]):format(TracksData.resource))
print(("wrote %d track nodes -> %s"):format(#records, OUT))

-- Back as the game reads them: attributes -> records -> each track's tables.
local back = {}
for line in io.lines(OUT .. "/tracks.map") do
    local tag, body = line:match("^%s*<([%w_]+)%s(.-)/>%s*$")
    if tag == "tracknode" then
        local attr = {}
        for k, v in body:gmatch('([%w_:]+)="(.-)"') do attr[k] = unxml(v) end
        back[#back + 1] = MapData.fromAttributes(schema, attr)
    end
end
local built = assert(TracksData.build(back))

local problems = {}
local function bad(fmt, ...) if #problems < 20 then problems[#problems + 1] = fmt:format(...) end end
for track = 0, 3 do
    local o, t = tracks[track], built[track]
    if not t or t.count ~= #o then
        bad("track %d: %d nodes, now %s", track, #o, t and t.count or "none")
    else
        for i, node in ipairs(o) do
            -- Positions keep MapData's 4 decimals (0.05 mm at most off the DAT's).
            local off = math.max(math.abs(node.x - t.x[i]), math.abs(node.y - t.y[i]), math.abs(node.z - t.z[i]))
            if off > 0.00005 or node.stop ~= t.stop[i] then
                bad("track %d node %d: %s %s %s %s, now %s %s %s %s", track, i - 1, node.x, node.y, node.z, tostring(node.stop),
                    t.x[i], t.y[i], t.z[i], tostring(t.stop[i]))
            end
        end
        print(("track %d (%s): %d nodes, %.1f m, %d stops"):format(track, TracksFormat.files[track], t.count, t.length, #TracksData.stops(t)))
    end
end
for _, p in ipairs(problems) do print("FAIL " .. p) end
print(#problems == 0 and ("PASS: %d track nodes read back as the DAT files have them"):format(#records) or "FAIL")
os.exit(#problems == 0 and 0 or 1)
