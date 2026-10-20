-- Map data (vana-lib's map_data): where encounters can happen, in vana-data-encounters. One element
-- type for every creature or NPC: what appears (creature), when (hours, weather), where it heads, and
-- a free-form params string for what one creature needs that the others don't.
local function weatherList(s)
    if type(s) ~= "string" or s == "" then return nil end
    local set = {}
    for w in s:gmatch("%d+") do set[tonumber(w)] = true end
    return next(set) and set or nil
end

local function weatherString(set)
    if not set then return nil end
    local list = {}
    for w in pairs(set) do list[#list + 1] = w end
    table.sort(list)
    return table.concat(list, ",")
end

MapDatasets.encounters = {
    resource = "vana-data-encounters", file = "encounters.map", definition = "vana-encounters",
    types = {
        { element = "encounter", friendly = "Encounter spawn", position = true,
          fields = {
              { "creature", "string", "bigfoot", "who appears here (config/encounters.lua: bigfoot ...)" },
              { "startHour", "int", 0, "from this game hour (0-23); the same as endHour: any time" },
              { "endHour", "int", 0, "until this game hour (exclusive)" },
              { "weather", "string", nil, "only in these vanilla weathers (comma-separated IDs, e.g. 9 for fog); none: the creature's own rule" },
              { "ex", "number", nil, "walks to here (x); none: stays where it appears" },
              { "ey", "number", nil, "y" },
              { "ez", "number", nil, "z" },
              { "params", "string", nil, "anything else this creature reads, free-form (key=value;...)" },
              { "note", "string", nil, "free-form note" },
          },
          rep = '<marker type="cylinder" size="2" color="#6A4A2A90" />' },
    },
    toRecords = function(g)
        local list = {}
        for _, s in ipairs(g.Encounters) do
            list[#list + 1] = { x = s[1], y = s[2], z = s[3], creature = s.creature, startHour = s.startHour, endHour = s.endHour,
                                weather = weatherString(s.weathers), ex = s.ex, ey = s.ey, ez = s.ez, params = s.params, note = s.note }
        end
        return { encounter = list }
    end,
    fromRecords = function(t)
        local list = {}
        for _, r in ipairs(t.encounter) do
            list[#list + 1] = { r.x, r.y, r.z, creature = r.creature, startHour = r.startHour or 0, endHour = r.endHour or 0,
                                weathers = weatherList(r.weather), ex = r.ex, ey = r.ey, ez = r.ez, params = r.params, note = r.note }
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
