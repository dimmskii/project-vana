-- The retail population data in data/ (copied from the player's own GTA:SA install), read with the
-- shared game-file library (sa_reader, sa_ide, sa_dat) and turned into what population.lua needs.
PopData = {}

-- popcycle.dat sections, in file order.
PopData.ZONE_TYPES = {
    "business", "desert", "entertainment", "countryside", "residential_rich", "residential_average",
    "residential_poor", "gangland", "beach", "shopping", "park", "industry", "entertainment_busy",
    "shopping_busy", "shopping_posh", "residential_rich_secluded", "airport", "golf_club",
    "out_of_town_factory", "airport_runway",
}
PopData.CITIES = { "los_santos", "san_fierro", "las_venturas" }

local function readFile(path)
    local s = SA.readFile(path)
    if not s then error("vana-population: missing " .. path .. " (see docs/setup.md)") end
    return s
end

-- Model race, as CPopulation::FindPedRaceFromName: the first of the first two letters that names one.
local RACE_LETTERS = { B = "black", H = "hispanic", O = "oriental", I = "oriental", W = "white" }
local function raceOf(name)
    for i = 1, 2 do
        local race = RACE_LETTERS[name:sub(i, i):upper()]
        if race then return race end
    end
    return false
end

function PopData.load()
    -- Models
    local pedFields, pedIds, pedCount = SAIde.index(SAIde.parse(readFile("data/peds.ide"), { "peds" }).peds)
    PopData.peds, PopData.pedIds, PopData.pedCount = {}, pedIds, pedCount
    for id, f in pairs(pedFields) do
        -- radio1 / radio2: the favourite stations, 0-based (Playback FM = 0); MTA channels are one higher.
        PopData.peds[id] = { name = f[2], pedType = f[4], stat = f[5], race = raceOf(f[2]),
                             radio = { (tonumber(f[10]) or -1) + 1, (tonumber(f[11]) or -1) + 1 } }
    end
    local vehFields, vehIds, vehCount = SAIde.index(SAIde.parse(readFile("data/vehicles.ide"), { "cars" }).cars)
    PopData.vehicles, PopData.vehicleIds, PopData.vehicleCount = {}, vehIds, vehCount
    for id, f in pairs(vehFields) do
        PopData.vehicles[id] = { name = f[2], type = f[4], class = f[8] }
    end

    -- Model groups: one list of model IDs per non-comment line (0-based, as the engine indexes them).
    local function groups(path, ids)
        local out, unknown = {}, {}
        for _, names in ipairs(SADat.rows(readFile(path))) do
            local models = {}
            for _, name in ipairs(names) do
                local id = ids[name:lower()]
                if id then models[#models + 1] = id else unknown[#unknown + 1] = name end
            end
            out[#out + 1] = models
        end
        local zeroBased = {}
        for i, models in ipairs(out) do zeroBased[i - 1] = models end
        return zeroBased, #out, unknown
    end
    PopData.pedGroups, PopData.pedGroupCount, PopData.unknownPeds = groups("data/pedgrp.dat", pedIds)
    PopData.carGroups, PopData.carGroupCount, PopData.unknownCars = groups("data/cargrp.dat", vehIds)

    -- popcycle.dat: [zone type][1 weekday | 2 weekend][1..12 two-hour slot]
    PopData.popcycle = {}
    local names = {}
    for i, name in ipairs(PopData.ZONE_TYPES) do names[i] = name:upper() end
    local sections = SADat.popcycle(readFile("data/popcycle.dat"), names)
    for _, name in ipairs(PopData.ZONE_TYPES) do
        local rows = sections[name:upper()]
        if rows then
            local weekday, weekend = {}, {}
            for i, n in ipairs(rows) do
                local groupPercs = {}
                for g = 7, #n do groupPercs[#groupPercs + 1] = n[g] end
                local row = { peds = n[1], cars = n[2], dealers = n[3], gang = n[4], cops = n[5], other = n[6], groups = groupPercs }
                if i <= 12 then weekday[i] = row elseif i <= 24 then weekend[i - 12] = row end
            end
            PopData.popcycle[name] = { weekday, weekend }
        end
    end

    -- pedstats.dat: personality per stat type (peds.ide names one per model).
    PopData.pedStats = {}
    for _, f in ipairs(SADat.rows(readFile("data/pedstats.dat"))) do
        if #f >= 11 then
            PopData.pedStats[f[1]] = {
                fleeDistance = tonumber(f[2]), headingChangeRate = tonumber(f[3]), fear = tonumber(f[4]),
                temper = tonumber(f[5]), lawfulness = tonumber(f[6]), sexiness = tonumber(f[7]),
                attackStrength = tonumber(f[8]), defendWeakness = tonumber(f[9]), shootingRate = tonumber(f[10]),
                decisionMaker = tonumber(f[11]),
            }
        end
    end

    -- Zones: info.zon navigation zones (smallest first) and map.zon city regions.
    local function zones(path)
        local out = {}
        for _, z in ipairs(SADat.zones(readFile(path))) do
            out[#out + 1] = { name = z.name:upper(), x1 = z.x1, y1 = z.y1, z1 = z.z1, x2 = z.x2, y2 = z.y2, z2 = z.z2,
                              level = z.level, area = (z.x2 - z.x1) * (z.y2 - z.y1) }
        end
        table.sort(out, function(a, b) return a.area < b.area end)
        return out
    end
    PopData.zones = zones("data/info.zon")
    PopData.regions = zones("data/map.zon")
end
