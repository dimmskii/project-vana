-- The railway tracks as map data: GTA:SA's four tracks (data/Paths/tracks*.dat) as tracknode elements in
-- [data]/vana-data-trains, and back. Plain Lua: the converter (tools/convert/tracks_to_maps.lua) and the
-- game (server.lua) share it.
--   tracknode  a track point, id "track.index" (the game's own numbering: 0 the mainland line, 1 the San
--              Fierro tram, 2 and 3 the two short lines missions use): position, and whether trains
--              stop there (the six station stops)
-- Distances along a track are the game's: summed node to node in 2D, the last node joined back to the
-- first (every track wraps), so they are the rail distances getTrainPosition and setTrainPosition use.
TracksData = {}

local floor, sqrt, atan2, deg = math.floor, math.sqrt, math.atan2 or math.atan, math.deg

TracksData.resource = "vana-data-trains"

TracksData.schemas = {
    { element = "tracknode", friendly = "Track node", position = true, id = "id",
      fields = { { "stop", "bool", false, "a station stop: trains that stop halt with their middle here" } },
      rep = '<marker type="corona" size="0.8" color="#C08040A0" />' },
}

function TracksData.nodeId(track, index) return track .. "." .. index end

-- The tracks as the converter reads them (TracksFormat.parse, by track id) -> tracknode records.
function TracksData.toRecords(tracks)
    local out = {}
    for track = 0, 3 do
        for i, node in ipairs(tracks[track] or {}) do
            out[#out + 1] = { id = TracksData.nodeId(track, i - 1), x = node.x, y = node.y, z = node.z, stop = node.stop or nil }
        end
    end
    return { tracknode = out }
end

-- tracknode records -> { [track] = { x = {}, y = {}, z = {}, stop = {}, dist = {}, count, length } }
-- (1-based arrays, node i is the game's i - 1), or false and why. A track's nodes must be numbered
-- from 0 without gaps: the game only knows them in order.
function TracksData.build(records)
    local byTrack = {}
    for _, rec in ipairs(records) do
        local track, index = tostring(rec.id or ""):match("^(%d+)%.(%d+)$")
        track, index = tonumber(track), tonumber(index)
        if not track then return false, ("tracknode %s: its id isn't track.index"):format(tostring(rec.id)) end
        byTrack[track] = byTrack[track] or {}
        if byTrack[track][index + 1] then return false, ("tracknode %s: twice"):format(rec.id) end
        byTrack[track][index + 1] = rec
    end
    local tracks = {}
    for track, list in pairs(byTrack) do
        local count = 0
        for i in pairs(list) do count = math.max(count, i) end
        local t = { x = {}, y = {}, z = {}, stop = {}, dist = {}, count = count }
        local d = 0
        for i = 1, count do
            local rec = list[i]
            if not rec then return false, ("track %d: no node %d"):format(track, i - 1) end
            if i > 1 then d = d + sqrt((rec.x - t.x[i - 1]) ^ 2 + (rec.y - t.y[i - 1]) ^ 2) end
            t.x[i], t.y[i], t.z[i], t.stop[i], t.dist[i] = rec.x, rec.y, rec.z, rec.stop == true, d
        end
        t.length = d + sqrt((t.x[1] - t.x[count]) ^ 2 + (t.y[1] - t.y[count]) ^ 2)
        tracks[track] = t
    end
    return tracks
end

-- A rail distance -> within [0, length).
function TracksData.wrap(t, s) return s - floor(s / t.length) * t.length end

-- The segment a rail distance falls in: i such that dist[i] <= s < dist[i + 1] (i = count: the last
-- node back to the first).
local function segmentAt(t, s)
    local lo, hi = 1, t.count
    while lo < hi do
        local mid = floor((lo + hi + 1) / 2)
        if t.dist[mid] <= s then lo = mid else hi = mid - 1 end
    end
    return lo
end

-- World position and heading (degrees, MTA's rotZ: 0 north, anticlockwise) at a rail distance, facing
-- the way the distance grows.
function TracksData.pointAt(t, s)
    s = TracksData.wrap(t, s)
    local i = segmentAt(t, s)
    local j = i == t.count and 1 or i + 1
    local span = (i == t.count and t.length or t.dist[j]) - t.dist[i]
    local f = span > 0 and (s - t.dist[i]) / span or 0
    local dx, dy = t.x[j] - t.x[i], t.y[j] - t.y[i]
    return t.x[i] + dx * f, t.y[i] + dy * f, t.z[i] + (t.z[j] - t.z[i]) * f, (deg(atan2(dy, dx)) - 90) % 360
end

-- The nearest point of a track to a world position: its rail distance and how far away it is (3D).
function TracksData.nearest(t, x, y, z)
    local best, bestS = math.huge, 0
    for i = 1, t.count do
        local j = i == t.count and 1 or i + 1
        local ax, ay, az = t.x[i], t.y[i], t.z[i]
        local dx, dy, dz = t.x[j] - ax, t.y[j] - ay, t.z[j] - az
        local len2 = dx * dx + dy * dy + dz * dz
        local f = len2 > 0 and math.max(0, math.min(1, ((x - ax) * dx + (y - ay) * dy + (z - az) * dz) / len2)) or 0
        local px, py, pz = ax + dx * f, ay + dy * f, az + dz * f
        local d = (x - px) ^ 2 + (y - py) ^ 2 + (z - pz) ^ 2
        if d < best then
            local span = (i == t.count and t.length or t.dist[j]) - t.dist[i]
            best, bestS = d, t.dist[i] + span * f
        end
    end
    return bestS, sqrt(best)
end

-- The same, searching only the stretch within `window` of rail distance s0 (a train read back near
-- where it should be: a few segments instead of the whole track).
function TracksData.nearestAround(t, x, y, z, s0, window)
    local i = segmentAt(t, TracksData.wrap(t, s0 - window))
    local best, bestS = math.huge, s0
    for _ = 1, t.count do
        local j = i == t.count and 1 or i + 1
        local ax, ay, az = t.x[i], t.y[i], t.z[i]
        local dx, dy, dz = t.x[j] - ax, t.y[j] - ay, t.z[j] - az
        local len2 = dx * dx + dy * dy + dz * dz
        local f = len2 > 0 and math.max(0, math.min(1, ((x - ax) * dx + (y - ay) * dy + (z - az) * dz) / len2)) or 0
        local d = (x - ax - dx * f) ^ 2 + (y - ay - dy * f) ^ 2 + (z - az - dz * f) ^ 2
        local span = (i == t.count and t.length or t.dist[j]) - t.dist[i]
        if d < best then best, bestS = d, TracksData.wrap(t, t.dist[i] + span * f) end
        if TracksData.ahead(t, s0, t.dist[i], true) > window and TracksData.ahead(t, s0, t.dist[i], true) < t.length / 2 then break end
        i = j
    end
    return bestS, sqrt(best)
end

-- Rail distance from a to b going forward (growing distances), or backward.
function TracksData.ahead(t, a, b, forward)
    if forward then return TracksData.wrap(t, b - a) end
    return TracksData.wrap(t, a - b)
end

-- A track's station stops, in track order: { index (1-based), s, x, y, z }.
function TracksData.stops(t)
    local out = {}
    for i = 1, t.count do
        if t.stop[i] then out[#out + 1] = { index = i, s = t.dist[i], x = t.x[i], y = t.y[i], z = t.z[i] } end
    end
    return out
end
