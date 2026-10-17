-- Parsers for the retail population data in data/ (copied from the player's own GTA:SA install).
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
    local f = fileOpen(path, true)
    if not f then error("vana-population: missing " .. path .. " (see docs/setup.md)") end
    local s = fileRead(f, fileGetSize(f))
    fileClose(f)
    return s
end

local function lines(s)
    return s:gmatch("[^\r\n]+")
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function split(s, sep)
    local out = {}
    for part in (s .. sep):gmatch("(.-)" .. sep) do out[#out + 1] = trim(part) end
    return out
end

-- Strips '#' and '//' comments.
local function code(line)
    return trim((line:gsub("#.*", ""):gsub("//.*", "")))
end

-- peds.ide / vehicles.ide: id -> fields, a lowercase name -> id map, and the model count.
local function parseIde(s, section)
    local byId, byName, inside, count = {}, {}, false, 0
    for line in lines(s) do
        local l = code(line)
        if l == section then
            inside = true
        elseif l == "end" then
            inside = false
        elseif inside and l ~= "" then
            -- Like the engine's loader: commas are whitespace (a few retail lines miss them).
            local f = {}
            for field in l:gsub(",", " "):gmatch("%S+") do f[#f + 1] = field end
            local id = tonumber(f[1])
            if id then
                byId[id], byName[f[2]:lower()], count = f, id, count + 1
            end
        end
    end
    return byId, byName, count
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
    local pedFields, pedIds, pedCount = parseIde(readFile("data/peds.ide"), "peds")
    PopData.peds, PopData.pedIds, PopData.pedCount = {}, pedIds, pedCount
    for id, f in pairs(pedFields) do
        PopData.peds[id] = { name = f[2], pedType = f[4], stat = f[5], race = raceOf(f[2]) }
    end
    local vehFields, vehIds, vehCount = parseIde(readFile("data/vehicles.ide"), "cars")
    PopData.vehicles, PopData.vehicleIds, PopData.vehicleCount = {}, vehIds, vehCount
    for id, f in pairs(vehFields) do
        PopData.vehicles[id] = { name = f[2], type = f[4], class = f[8] }
    end

    -- Model groups: one list of model IDs per non-comment line (0-based, as the engine indexes them).
    local function groups(path, ids)
        local out, unknown = {}, {}
        for line in lines(readFile(path)) do
            local l = code(line)
            if l ~= "" then
                local models = {}
                for _, name in ipairs(split(l, ",")) do
                    local id = ids[name:lower()]
                    if id then models[#models + 1] = id elseif name ~= "" then unknown[#unknown + 1] = name end
                end
                out[#out + 1] = models
            end
        end
        local zeroBased = {}
        for i, models in ipairs(out) do zeroBased[i - 1] = models end
        return zeroBased, #out, unknown
    end
    PopData.pedGroups, PopData.pedGroupCount, PopData.unknownPeds = groups("data/pedgrp.dat", pedIds)
    PopData.carGroups, PopData.carGroupCount, PopData.unknownCars = groups("data/cargrp.dat", vehIds)

    -- popcycle.dat: [zone type][1 weekday | 2 weekend][1..12 two-hour slot]
    PopData.popcycle = {}
    local section, rows = nil, nil
    local known = {}
    for _, name in ipairs(PopData.ZONE_TYPES) do known[name:upper()] = name end
    for line in lines(readFile("data/popcycle.dat")) do
        local header = line:match("^//%s*([%u_]+)")
        if header and known[header] then
            section, rows = known[header], {}
            PopData.popcycle[section] = rows
        elseif section then
            local l = code(line)
            if l ~= "" then
                local n = {}
                for v in l:gmatch("%-?%d+") do n[#n + 1] = tonumber(v) end
                local groupPercs = {}
                for g = 7, #n do groupPercs[#groupPercs + 1] = n[g] end
                rows[#rows + 1] = { peds = n[1], cars = n[2], dealers = n[3], gang = n[4], cops = n[5], other = n[6], groups = groupPercs }
            end
        end
    end
    for _, rowsOfType in pairs(PopData.popcycle) do
        local weekday, weekend = {}, {}
        for i = 1, 12 do weekday[i], weekend[i] = rowsOfType[i], rowsOfType[i + 12] end
        rowsOfType[1], rowsOfType[2] = weekday, weekend
        for i = 3, 24 do rowsOfType[i] = nil end
    end

    -- pedstats.dat: personality per stat type (peds.ide names one per model).
    PopData.pedStats = {}
    for line in lines(readFile("data/pedstats.dat")) do
        local l = code(line)
        local f = {}
        for field in l:gmatch("%S+") do f[#f + 1] = field end
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
        for line in lines(readFile(path)) do
            local f = split(code(line), ",")
            if #f >= 9 then
                local x1, y1, z1, x2, y2, z2 = tonumber(f[3]), tonumber(f[4]), tonumber(f[5]), tonumber(f[6]), tonumber(f[7]), tonumber(f[8])
                if x1 then
                    out[#out + 1] = { name = f[1]:upper(), x1 = math.min(x1, x2), y1 = math.min(y1, y2), z1 = math.min(z1, z2),
                                      x2 = math.max(x1, x2), y2 = math.max(y1, y2), z2 = math.max(z1, z2),
                                      level = tonumber(f[9]), area = math.abs((x2 - x1) * (y2 - y1)) }
                end
            end
        end
        table.sort(out, function(a, b) return a.area < b.area end)
        return out
    end
    PopData.zones = zones("data/info.zon")
    PopData.regions = zones("data/map.zon")
end
