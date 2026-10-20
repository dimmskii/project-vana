-- Map data (tools/lib/map_data.lua): entry/exit markers, in vana-data-interiors. Each marker takes
-- you to the same-named entry in another area, arriving at that entry's exit point (ex, ey, ez).
local FIELDS = { "name", "size", "ex", "ey", "ez", "heading", "flags", "open", "close", "enabled", "instance" }

MapDatasets.entrances = {
    resource = "vana-data-interiors", file = "entrances.map", definition = "vana-interiors",
    types = {
        { element = "entrance", friendly = "Entrance", position = true, interior = "interior",
          fields = {
              { "name", "string", "", "pairs with the same-named entry in another area" },
              { "size", "numbers", "2,2", "trigger widths" },
              { "ex", "number", 0, "exit point x (where you arrive coming through the paired entry)" },
              { "ey", "number", 0, "exit point y" },
              { "ez", "number", 0, "exit point z" },
              { "heading", "number", 0, "facing at the exit point" },
              { "flags", "int", 0, "IPL enex flags (bit 4: a door leading to a shared hub)" },
              { "open", "int", 0, "opening hour" },
              { "close", "int", 24, "closing hour" },
              { "enabled", "bool", true, "usable at all" },
              { "instance", "int", 0, "dimension (0: the shared world; another: a copy of the interior of its own, e.g. a second 24/7)" },
          },
          rep = '<marker type="arrow" size="1" color="#FFDC00AA" />' },
    },
    toRecords = function(g)
        local list = {}
        for _, e in ipairs(g.Entrances) do
            local r = { x = e.x, y = e.y, z = e.z, interior = e.interior }
            for _, k in ipairs(FIELDS) do r[k] = e[k] end
            list[#list + 1] = r
        end
        return { entrance = list }
    end,
    fromRecords = function(t)
        local list = {}
        for _, r in ipairs(t.entrance) do
            local e = { x = r.x, y = r.y, z = r.z, interior = r.interior }
            for _, k in ipairs(FIELDS) do e[k] = r[k] end
            list[#list + 1] = e
        end
        return { Entrances = list }
    end,
}

-- In the game (not the converter): the tables the code uses.
if MapData.load then
    local data = MapData.load(MapDatasets.entrances)
    Entrances = data.Entrances
end
