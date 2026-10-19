-- Map data (tools/lib/map_data.lua): where creatures appear, in vana-data-wildlife.
MapDatasets.wildlife = {
    resource = "vana-data-wildlife", file = "wildlife.map", definition = "vana-wildlife",
    types = {
        { element = "bigfootspawn", friendly = "Bigfoot spawn", position = true,
          fields = {
              { "fog", "bool", false, "only in fog (vanilla weather 9); otherwise in any weather" },
              { "ex", "number", nil, "walks to here (x); none: stays where he appears" },
              { "ey", "number", nil, "y" },
              { "ez", "number", nil, "z" },
          },
          rep = '<marker type="cylinder" size="2" color="#6A4A2A90" />' },
    },
    toRecords = function(g)
        local list = {}
        for _, s in ipairs(g.BigfootSpawns) do
            list[#list + 1] = { x = s[1], y = s[2], z = s[3], fog = s.fog, ex = s.ex, ey = s.ey, ez = s.ez }
        end
        return { bigfootspawn = list }
    end,
    fromRecords = function(t)
        local list = {}
        for _, r in ipairs(t.bigfootspawn) do
            list[#list + 1] = { r.x, r.y, r.z, fog = r.fog, ex = r.ex, ey = r.ey, ez = r.ez }
        end
        return { BigfootSpawns = list }
    end,
}

-- In the game (not the converter): the tables the code uses.
if MapData.load then
    local data = MapData.load(MapDatasets.wildlife)
    BigfootSpawns = data.BigfootSpawns
end
