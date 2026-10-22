-- Reader for retail GTA:SA data/Paths/tracks*.dat: the converter's (tools/convert/tracks_to_maps.lua);
-- the game reads the tracks from map data (tracks_data.lua).
-- Text: the node count, then one node a line, "x y z flag". flag 1 marks the six station stops (all
-- on the mainland line). The game numbers the tracks in the order it loads the files, which is not
-- the files' own numbering (checked against Neon's copy of the default tracks, Shared/gta/TrackNodes.h).
TracksFormat = {}

TracksFormat.files = { [0] = "tracks.dat", [1] = "tracks3.dat", [2] = "tracks2.dat", [3] = "tracks4.dat" }

-- A file's text -> { { x, y, z, stop }, ... } (1-based; node i is the game's i - 1), or false and why.
function TracksFormat.parse(name, s)
    local lines = {}
    for line in s:gmatch("[^\r\n]+") do
        if line:match("%S") then lines[#lines + 1] = line end
    end
    local count = tonumber(lines[1])
    if not count then return false, name .. ": no node count on its first line" end
    if #lines - 1 ~= count then return false, ("%s: %d nodes listed, header says %d"):format(name, #lines - 1, count) end
    local nodes = {}
    for i = 2, #lines do
        local x, y, z, flag = lines[i]:match("^%s*(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")
        x, y, z, flag = tonumber(x), tonumber(y), tonumber(z), tonumber(flag)
        if not (x and y and z and flag) then return false, ("%s: line %d isn't x y z flag"):format(name, i) end
        nodes[#nodes + 1] = { x = x, y = y, z = z, stop = flag == 1 }
    end
    return nodes
end
