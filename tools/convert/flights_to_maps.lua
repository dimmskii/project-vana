-- One-time conversion of vanilla's flight recordings (data/Paths/carrec.img: carrec041-049, the
-- airport ticket desk's flights, main.scm PLANES) into map data: flights.map in [data]/vana-data-air
-- (vana-air/air_data.lua says what's in it). Then reads it back the way the game does and checks
-- every frame against the recording.
-- usage (from the repo root): lua5.1 tools/convert/flights_to_maps.lua [folder with carrec.img]
dofile("vana-lib/lib/sa_reader.lua")
dofile("vana-lib/lib/map_data.lua")
dofile("vana-air/air_data.lua")

local from = arg[1] or "vana-air/data"
local OUT = "[data]/" .. AirData.resource
local RECORDINGS = { 41, 42, 43, 44, 46, 48, 49 }
-- Where each lands or takes off from: the nearest airport.
local AIRPORTS = { LS = { 1700, -2500 }, SF = { -1500, -100 }, LV = { 1500, 1600 } }
local GEAR_UP_ABOVE, GEAR_DOWN_ABOVE = 30, 60 -- m over the runway: gear up after takeoff, down on approach

local function xml(s)
    return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end
local function unxml(s)
    return (s:gsub("&quot;", '"'):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&"))
end
local function i8(s, o) local v = SA.u8(s, o) return v >= 128 and v - 256 or v end

local f = assert(io.open(from .. "/carrec.img", "rb"), "missing carrec.img in " .. from)
local img = f:read("*a")
f:close()
assert(img:sub(1, 4) == "VER2", "carrec.img: not a VER2 archive")

-- The archive's directory: name -> data.
local entries = {}
for i = 0, SA.u32(img, 5) - 1 do
    local o = 9 + i * 32
    local offset, size = SA.u32(img, o), SA.u16(img, o + 4)
    if size == 0 then size = SA.u16(img, o + 6) end
    entries[SA.fixed(img, o + 8, 24):lower()] = img:sub(offset * 2048 + 1, (offset + size) * 2048)
end

-- A recording: 32-byte frames (time ms, velocity int16 /16384 game units, right and forward int8 /127,
-- steer/gas/brake/handbrake, position floats), until the time stops growing (the sector's padding).
local function frames(data)
    local out = {}
    for k = 1, #data - 31, 32 do
        local t = SA.u32(data, k)
        if #out > 0 and t <= out[#out].t then break end
        local q = function(o) return i8(data, k + o) / 127 end
        out[#out + 1] = { t = t,
            vel = { SA.i16(data, k + 4) / 16384 * 50, SA.i16(data, k + 6) / 16384 * 50, SA.i16(data, k + 8) / 16384 * 50 },
            right = { q(10), q(11), q(12) }, fwd = { q(13), q(14), q(15) },
            x = SA.f32(data, k + 20), y = SA.f32(data, k + 24), z = SA.f32(data, k + 28) }
    end
    return out
end

local function nearestAirport(x, y)
    local best, bestD
    for id, p in pairs(AIRPORTS) do
        local d = (x - p[1]) ^ 2 + (y - p[2]) ^ 2
        if not bestD or d < bestD then best, bestD = id, d end
    end
    return best
end

local function round(v, places) local m = 10 ^ places return math.floor(v * m + 0.5) / m end

local paths, frameRecs, original = {}, {}, {}
for _, n in ipairs(RECORDINGS) do
    local data = assert(entries[("carrec%03d.rrr"):format(n)], ("carrec.img has no carrec%03d.rrr"):format(n))
    local list = frames(data)
    original[tostring(n)] = list
    local first, last = list[1], list[#list]
    local gearUp, gearDown
    for _, fr in ipairs(list) do
        if not gearUp and fr.z > first.z + GEAR_UP_ABOVE then gearUp = fr.t end
        if fr.z > last.z + GEAR_DOWN_ABOVE then gearDown = fr.t end
    end
    paths[#paths + 1] = { id = tostring(n), x = first.x, y = first.y, z = first.z, from = nearestAirport(first.x, first.y),
                          to = nearestAirport(last.x, last.y), gearUp = gearUp, gearDown = gearDown, duration = last.t - first.t }
    for i, fr in ipairs(list) do
        frameRecs[#frameRecs + 1] = { id = n .. "." .. i, path = tostring(n), t = fr.t - first.t, x = fr.x, y = fr.y, z = fr.z,
            fwd = { round(fr.fwd[1], 3), round(fr.fwd[2], 3), round(fr.fwd[3], 3) },
            right = { round(fr.right[1], 3), round(fr.right[2], 3), round(fr.right[3], 3) },
            vel = { round(fr.vel[1], 2), round(fr.vel[2], 2), round(fr.vel[3], 2) } }
    end
    print(("carrec%03d: %s -> %s, %d frames, %.0f s, gear up at %.0f s, down at %.0f s"):format(n, paths[#paths].from, paths[#paths].to,
        #list, (last.t - first.t) / 1000, (gearUp or 0) / 1000, (gearDown or 0) / 1000))
end

local out = { '<map edf:definitions="vana-air">' }
for k, recs in ipairs({ paths, frameRecs }) do
    local schema = AirData.flightSchemas[k]
    out[#out + 1] = ("    <!-- %s -->"):format(schema.friendly)
    for _, rec in ipairs(recs) do
        local attrs = {}
        for _, at in ipairs(MapData.toAttributes(schema, rec)) do attrs[#attrs + 1] = ('%s="%s"'):format(at[1], xml(at[2])) end
        out[#out + 1] = ("    <%s %s />"):format(schema.element, table.concat(attrs, " "))
    end
end
out[#out + 1] = "</map>\n"
local w = assert(io.open(OUT .. "/flights.map", "w"))
w:write(table.concat(out, "\n"))
w:close()
print(("wrote %d flight paths, %d frames -> %s/flights.map"):format(#paths, #frameRecs, OUT))

-- Back as the game reads them.
local back = { flightpath = {}, flightframe = {} }
local schemas = { flightpath = AirData.flightSchemas[1], flightframe = AirData.flightSchemas[2] }
for line in io.lines(OUT .. "/flights.map") do
    local tag, body = line:match("^%s*<([%w_]+)%s(.-)/>%s*$")
    if schemas[tag] then
        local attr = {}
        for k, v in body:gmatch('([%w_:]+)="(.-)"') do attr[k] = unxml(v) end
        table.insert(back[tag], MapData.fromAttributes(schemas[tag], attr))
    end
end
local flights = AirData.buildFlights(back.flightpath, back.flightframe)
local problems = {}
for id, list in pairs(original) do
    local fl = flights[id]
    if not fl or #fl.frames ~= #list then
        problems[#problems + 1] = ("flight %s: %d frames, now %s"):format(id, #list, fl and #fl.frames or "none")
    else
        for i, fr in ipairs(list) do
            local g = fl.frames[i]
            local off = math.max(math.abs(fr.x - g.x), math.abs(fr.y - g.y), math.abs(fr.z - g.z))
            -- As kept: positions to 4 decimals, vectors to 3, velocities to 2.
            if off > 0.0001 or math.abs(fr.fwd[2] - g.fy) > 0.001 or math.abs(fr.vel[1] - g.vx) > 0.01 then
                problems[#problems + 1] = ("flight %s frame %d differs: %.5f %.5f %.5f / %.4f %.4f / %.3f %.3f"):format(id, i, fr.x - g.x, fr.y - g.y, fr.z - g.z, fr.fwd[2], g.fy, fr.vel[1], g.vx)
                break
            end
        end
    end
end
for _, p in ipairs(problems) do print("FAIL " .. p) end
print(#problems == 0 and ("PASS: %d flights read back as carrec.img has them"):format(#RECORDINGS) or "FAIL")
os.exit(#problems == 0 and 0 or 1)
