-- Map data (vana-lib's map_data): the railway tracks, in vana-data-trains, read by the server from its
-- files. tracks.map is converted from the game's tracks*.dat by tools/convert/tracks_to_maps.lua;
-- crossings.map and platforms.map are worked out from it and the path graph by
-- tools/convert/track_places.lua (tracks_data.lua).
if not TracksData then dofile("vana-trains/tracks_data.lua") end -- the converter (plain Lua)
local types = {}
for _, schema in ipairs(TracksData.schemas) do types[#types + 1] = schema end
for _, schema in ipairs(TracksData.placeSchemas) do types[#types + 1] = schema end
MapDatasets.trains = {
    resource = TracksData.resource, file = "tracks.map", definition = "vana-trains",
    types = types,
    fromRecords = function(t) return { TrackNodes = t.tracknode, TrackCrossings = t.trackcrossing, PlatformSpots = t.platformspot } end,
}

-- In the game (not the converter): the tracks, built, and the places along them.
if MapData.load then
    local data = MapData.load(MapDatasets.trains)
    local why
    Tracks, why = TracksData.build(data.TrackNodes)
    if not Tracks then outputServerLog("[vana-trains] WARNING: the track data is broken: " .. tostring(why)) Tracks = {} end
    TrackCrossings, PlatformSpots = data.TrackCrossings or {}, data.PlatformSpots or {}
end
