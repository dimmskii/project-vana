-- Map data (vana-lib's map_data): the path graph, one map resource per area
-- ([data]/[paths]/vana-data-paths-NN), read by the server from its files (paths_data.lua).
if not PathsData then dofile("vana-paths/paths_data.lua") end -- the converter (plain Lua)
MapDatasets.paths = {
    resource = "vana-data-paths-NN", file = "paths.map", definition = "vana-paths", perArea = true,
    types = PathsData.schemas,
}
