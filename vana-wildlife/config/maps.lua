-- Map data (vana-lib's map_data): where animals live, in vana-data-wildlife. Seeded once from Myths
-- Maker 2.7's animal pack (tools/seed/seed_wildlife.py: each animal folder's ini, one element per
-- location); ours afterwards, edit freely in the Map Editor.
local FIELDS = {
    { "species", "string", "deer", "which animal (config/species.lua)" },
    { "angle", "number", 0, "heading the animals face when they appear (degrees)" },
    { "quantity", "int", 1, "how many live here at once" },
    { "startHour", "int", 0, "from this game hour (0-23); the same as endHour: any time" },
    { "endHour", "int", 0, "until this game hour (exclusive)" },
    { "findRadius", "number", 80, "a player within this (m) wakes the spot up" },
    { "spawnRadius", "number", 10, "they appear within this (m) of the spot" },
    { "health", "int", 100, "each one's health" },
    { "damage", "int", 0, "the damage a bite or blow does (predators)" },
    { "attacksPeds", "bool", false, "goes for people (players and peds) on its own" },
    { "attacksAnimals", "bool", false, "goes for other animals" },
    { "respawn", "int", 10, "seconds before one that died or left comes back" },
    { "weather", "int", -1, "only in this vanilla weather; -1: any" },
    { "note", "string", nil, "free-form note (seeded: the pack's folder it came from)" },
}

MapDatasets.wildlife = {
    resource = "vana-data-wildlife", file = "wildlife.map", definition = "vana-wildlife",
    types = {
        { element = "wildlifespawner", friendly = "Wildlife spawner", position = true, fields = FIELDS,
          rep = '<marker type="cylinder" size="2" color="#4A8A3A80" />' },
    },
    toRecords = function(g)
        local list = {}
        for _, s in ipairs(g.WildlifeSpawners) do
            local r = { x = s[1], y = s[2], z = s[3] }
            for _, f in ipairs(FIELDS) do r[f[1]] = s[f[1]] end
            list[#list + 1] = r
        end
        return { wildlifespawner = list }
    end,
    fromRecords = function(t)
        local list = {}
        for _, r in ipairs(t.wildlifespawner) do
            local s = { r.x, r.y, r.z }
            for _, f in ipairs(FIELDS) do s[f[1]] = r[f[1]] end
            list[#list + 1] = s
        end
        return { WildlifeSpawners = list }
    end,
}

-- In the game (not the converter): the tables the code uses.
if MapData.load then
    local data = MapData.load(MapDatasets.wildlife)
    WildlifeSpawners = data.WildlifeSpawners
end
