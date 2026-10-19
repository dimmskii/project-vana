-- Map data (tools/lib/map_data.lua): parked car generators, in vana-data-parked.
local FIELDS = { "model", "colors", "force", "ignoreLimit", "alarm", "lock", "delay", "enabled", "source" }

MapDatasets.cargens = {
    resource = "vana-data-parked", file = "cargens.map", definition = "vana-parked",
    types = {
        { element = "cargen", friendly = "Car generator", position = true, rotation = "heading",
          fields = {
              { "model", "int", -1, "vehicle model; -1 picks one for the zone (kept once picked)" },
              { "colors", "ints", "-1,-1", "primary,secondary colour; -1 random" },
              { "force", "bool", false, "spawns regardless of the parked-car limit" },
              { "ignoreLimit", "bool", false, "doesn't count toward the parked-car limit" },
              { "alarm", "int", 0, "percent chance of an alarm" },
              { "lock", "int", 0, "percent chance of locked doors" },
              { "delay", "ints", "10000,60000", "respawn delay range (ms)" },
              { "enabled", "bool", true, "generates at all" },
              { "source", "string", "", "where it came from (an IPL in gta3.img, or main.scm's variable)" },
          },
          rep = '<marker type="cylinder" size="2" color="#00A0FF60" />' },
    },
    toRecords = function(g)
        local list = {}
        for _, c in ipairs(g.CarGenerators) do
            local r = { x = c.x, y = c.y, z = c.z, heading = c.heading }
            for _, k in ipairs(FIELDS) do r[k] = c[k] end
            list[#list + 1] = r
        end
        return { cargen = list }
    end,
    fromRecords = function(t)
        local list = {}
        for _, r in ipairs(t.cargen) do
            local c = { x = r.x, y = r.y, z = r.z, heading = r.heading }
            for _, k in ipairs(FIELDS) do c[k] = r[k] end
            list[#list + 1] = c
        end
        return { CarGenerators = list }
    end,
}

-- In the game (not the converter): the tables the code uses.
if MapData.load then
    local data = MapData.load(MapDatasets.cargens)
    CarGenerators = data.CarGenerators
end
