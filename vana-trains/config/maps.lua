-- Map data (vana-lib's map_data): the railway tracks, in vana-data-trains, read by the server from its
-- files. Converted from the game's tracks*.dat by tools/convert/tracks_to_maps.lua (tracks_data.lua).
if not TracksData then dofile("vana-trains/tracks_data.lua") end -- the converter (plain Lua)
MapDatasets.trains = {
    resource = TracksData.resource, file = "tracks.map", definition = "vana-trains",
    types = TracksData.schemas,
    fromRecords = function(t) return { TrackNodes = t.tracknode } end,
}

-- In the game (not the converter): the tracks, built.
if MapData.load then
    local why
    Tracks, why = TracksData.build(MapData.load(MapDatasets.trains).TrackNodes)
    if not Tracks then outputServerLog("[vana-trains] WARNING: the track data is broken: " .. tostring(why)) Tracks = {} end
end
