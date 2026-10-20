-- Map data (tools/lib/map_data.lua): gym equipment, in vana-data-gym.
MapDatasets.gym = {
    -- clients: client scripts read it too, so it runs as a map resource (vana-lib's map_data)
    resource = "vana-data-gym", clients = true, file = "gym.map", definition = "vana-gym",
    types = {
        { element = "gymequipment", friendly = "Gym equipment", position = true, rotation = "heading", interior = "interior",
          fields = { { "kind", "string", "bike", "bike, treadmill, bench or mat" } },
          rep = '<marker type="cylinder" size="1" color="#FF780060" />' },
    },
    toRecords = function(g)
        local list = {}
        for _, e in ipairs(g.GymEquipment) do
            list[#list + 1] = { kind = e.kind, interior = e.interior, x = e.x, y = e.y, z = e.z, heading = e.heading }
        end
        return { gymequipment = list }
    end,
    fromRecords = function(t)
        local list = {}
        for _, r in ipairs(t.gymequipment) do
            list[#list + 1] = { kind = r.kind, interior = r.interior, x = r.x, y = r.y, z = r.z, heading = r.heading }
        end
        return { GymEquipment = list }
    end,
}

-- In the game (not the converter): the tables the code uses.
if MapData.load then
    local data = MapData.load(MapDatasets.gym)
    GymEquipment = data.GymEquipment
end
