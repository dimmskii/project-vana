-- Map data (vana-lib's map_data): the encounters, in vana-data-encounters. One element per encounter:
-- a single instance of its kind (config/encounters.lua) that appears at its place every day at
-- startHour and is cleaned up at endHour; killed, it stays dead until the next day.
MapDatasets.encounters = {
    resource = "vana-data-encounters", file = "encounters.map", definition = "vana-encounters",
    types = {
        { element = "encounter", friendly = "Encounter", position = true, rotation = "heading", id = "id",
          fields = {
              { "kind", "string", "bigfoot", "what appears (config/encounters.lua EncounterKinds: bigfoot ...)" },
              { "enabled", "bool", true, "appears at all (false: kept for later)" },
              { "name", "string", nil, "its name, shown on the map and in messages (none: the kind's)" },
              { "startHour", "int", 0, "it appears at this game hour, every day (0-23), unless killed that day" },
              { "endHour", "int", 0, "and is cleaned up at this one (the same as startHour: a whole day, from that hour)" },
              { "blip", "string", nil, "vana-map category of its map icon while it's out (none: the kind's; \"none\": no icon)" },
              { "health", "int", nil, "health in GTA's units (none: the kind's)" },
              { "reward", "int", nil, "cash for killing it, shared by the damage each player did (none: the kind's)" },
              { "model", "int", nil, "ped model (none: the kind's; a kind with its own DFF shows that on it)" },
              { "walkingStyle", "int", nil, "walking style (none: the kind's)" },
              { "fightingStyle", "int", nil, "fighting style (none: the kind's)" },
              { "weapon", "int", nil, "weapon in hand (none: fists)" },
              { "anim", "string", nil, "idle animation while it stands, block/name (e.g. ped/idle_tired)" },
              { "ex", "number", nil, "walks to here after appearing (x); none: stays where it appears" },
              { "ey", "number", nil, "y" },
              { "ez", "number", nil, "z" },
              { "params", "string", nil, "anything else its script reads, free-form (key=value;...)" },
          },
          rep = '<marker type="cylinder" size="2" color="#6A4A2A90" />' },
    },
    toRecords = function(g)
        local list = {}
        for _, s in ipairs(g.Encounters) do list[#list + 1] = s end
        return { encounter = list }
    end,
    fromRecords = function(t)
        local list = {}
        for i, r in ipairs(t.encounter) do
            r.id = r.id or ("encounter" .. i)
            list[#list + 1] = r
        end
        return { Encounters = list }
    end,
}

-- In the game (not the converter): the tables the code uses.
if MapData.load then
    local data = MapData.load(MapDatasets.encounters)
    Encounters = data.Encounters
end

-- Whether an encounter spot is open at this game hour.
function encounterOpen(s, hour)
    if s.startHour == s.endHour then return true end
    if s.startHour < s.endHour then return hour >= s.startHour and hour < s.endHour end
    return hour >= s.startHour or hour < s.endHour -- across midnight
end
