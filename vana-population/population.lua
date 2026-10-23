-- Vanilla population selection (CPopCycle / CPopulation), driven by data/ and config/.
Population = {}
Population.random = math.random

local ROAD_TYPES = { car = true, bike = true, bmx = true, quad = true, mtruck = true }
local GANG_GROUP_BASE = 18           -- popcycle group index of the first gang (ballas)
local DEALER_GROUP = 28
-- CPopulation::ChoosePolicePedOccupation / police cars by city; countryside uses the county sheriff.
local COPS = {
    los_santos = { ped = 280, car = 596 }, san_fierro = { ped = 281, car = 597 },
    las_venturas = { ped = 282, car = 598 }, countryside = { ped = 283, car = 599 }, desert = { ped = 288, car = 599 },
}
local MEDICS = { los_santos = 274, las_venturas = 275, san_fierro = 276 }

local function inBox(z, x, y, zz)
    return x >= z.x1 and x <= z.x2 and y >= z.y1 and y <= z.y2 and zz >= z.z1 and zz <= z.z2
end

-- The smallest info.zon zone with population settings that contains the point.
function Population.zoneAt(x, y, z)
    for _, zone in ipairs(PopData.zones) do
        if PopZones[zone.name] and inBox(zone, x, y, z) then return zone.name, PopZones[zone.name] end
    end
    return false, { type = "countryside" }
end

function Population.cityAt(x, y)
    for _, region in ipairs(PopData.regions) do
        if inBox(region, x, y, 0) then return PopData.CITIES[region.level] or "los_santos" end
    end
    return "los_santos"
end

local function gangSum(gangs)
    local sum = 0
    for _, strength in pairs(gangs or {}) do sum = sum + strength end
    return sum
end

-- Population targets around a point (CPopCycle::UpdatePercentages). hour 0-23; weekend boolean.
function Population.profile(x, y, z, hour, weekend)
    local zoneName, zone = Population.zoneAt(x, y, z)
    local row = PopData.popcycle[zone.type][weekend and 2 or 1][math.floor(hour / 2) % 12 + 1]

    -- Dealers only where the zone has them (vanilla floors this at 10% but only streams dealer
    -- models where they deal).
    local dealers = (zone.dealers or 0) > 0 and math.max(0.1, zone.dealers / 100) or 0
    local gangs = math.min(0.5, gangSum(zone.gangs) / 100)
    local cops = gangs >= 0.15 and math.max(0.03, 0.3 - gangs) or math.max(0.02, gangs)
    if zone.noCops then cops = 0 end
    local other
    local sum = dealers + gangs + cops
    if sum <= 1 then other = 1 - sum else dealers, gangs, cops, other = dealers / sum, gangs / sum, cops / sum, 0 end

    local p = {
        zone = zoneName, type = zone.type, city = Population.cityAt(x, y), races = zone.races, gangs = zone.gangs or {},
        row = row, maxPeds = row.peds, maxCars = row.cars,
    }
    p.peds = { dealer = row.peds * row.dealers / 100 * dealers, gang = row.peds * row.gang / 100 * gangs,
               cop = row.peds * row.cops / 100 * cops, civilian = row.peds * row.other / 100 * other }
    p.cars = { dealer = 0, gang = row.cars * row.gang / 100 * gangs,
               cop = row.cars * row.cops / 100 * cops, civilian = row.cars * row.other / 100 * other }
    return p
end

-- Which kind to add next: the largest deficit, randomised when small (CPopCycle::FindNewPedType).
local function pickKind(targets, counts)
    local best, bestChance = false, 0
    for _, kind in ipairs({ "civilian", "cop", "dealer", "gang" }) do
        local chance = targets[kind] - (counts[kind] or 0)
        if chance < 2 then chance = chance * Population.random() end
        if chance > bestChance then best, bestChance = kind, chance end
    end
    return best
end

-- The gang furthest below its share of the zone's gang strength (CPopCycle::PickGangToCreateMembersOf).
local function pickGang(profile, gangCounts, gangTarget)
    local sum, best, bestScore = gangSum(profile.gangs), false, -math.huge
    for gang, strength in pairs(profile.gangs) do
        local score = strength / sum - (gangCounts[gang] or 0) / math.max(gangTarget, 1)
        if score > bestScore then best, bestScore = gang, score end
    end
    return best
end

local function randomFrom(list)
    if #list == 0 then return false end
    return list[Population.random(#list)]
end

local function cityIndex(city)
    for i, name in ipairs(PopData.CITIES) do if name == city then return i end end
    return 1
end

local function groupModels(groupIndex, city, races)
    local line = PopGroups[groupIndex + 1].pedgrp[cityIndex(city)]
    local models = {}
    for _, id in ipairs(PopData.pedGroups[line] or {}) do
        local race = PopData.peds[id] and PopData.peds[id].race
        local allowed = not races or not race
        if not allowed then
            for _, r in ipairs(races) do if r == race then allowed = true break end end
        end
        if allowed then models[#models + 1] = id end
    end
    return models
end

-- A civilian group by the popcycle percentages (CPopCycle::PickARandomGroupOfOtherPeds).
local function pickCivilianGroup(row)
    local total = 0
    for _, perc in ipairs(row.groups) do total = total + perc end
    local r = Population.random() * total
    for i, perc in ipairs(row.groups) do
        r = r - perc
        if r <= 0 and perc > 0 then return i - 1 end
    end
    return 7 -- casual_average
end

local function cops(profile)
    return COPS[profile.type] or COPS[profile.city]
end

local FIREFIGHTERS = { los_santos = 277, las_venturas = 278, san_fierro = 279 }
-- Units that are the same everywhere: SWAT Enforcer, FBI Rancher, army Barracks and Rhino.
local SPECIAL_UNITS = {
    swat = { ped = 285, car = 427 }, fbi = { ped = 286, car = 490 },
    army = { ped = 287, car = 433 }, tank = { ped = 287, car = 432 },
}

-- A vanilla service vehicle or one of the added vehicles beside it here (vana-cars' variants: the
-- city's police car, the airports' fire brigade...). Itself without vana-cars.
function Population.variant(model, profile)
    local res = getResourceFromName and getResourceFromName("vana-cars")
    if not res or getResourceState(res) ~= "running" then return model end
    local ok, pick = pcall(function() return exports["vana-cars"]:pickVariant(model, profile.city, profile.zone) end)
    return ok and pick or model
end

-- Emergency service crew and vehicle for a place: "police", "heli" (police Maverick with local
-- cops), "swat", "fbi", "army", "tank", "medics" or "fire".
function Population.serviceUnit(profile, service)
    if service == "medics" then return { ped = MEDICS[profile.city] or MEDICS.los_santos, car = Population.variant(416, profile) } end
    if service == "fire" then return { ped = FIREFIGHTERS[profile.city] or FIREFIGHTERS.los_santos, car = Population.variant(407, profile) } end
    if SPECIAL_UNITS[service] then
        local u = SPECIAL_UNITS[service]
        return { ped = u.ped, car = Population.variant(u.car, profile) }
    end
    local c = cops(profile)
    if service == "heli" then return { ped = c.ped, car = 497 } end
    return { ped = c.ped, car = Population.variant(c.car, profile) }
end

-- The added vehicles (vana-cars) as members of the car groups and the vehicle table: taken again
-- whenever vana-cars starts (its models' IDs come from it).
local baseGroups -- the vanilla car groups, before any added vehicles
function Population.addVehicles(list)
    if not baseGroups then
        baseGroups = {}
        for g, models in pairs(PopData.carGroups) do
            baseGroups[g] = {}
            for i, m in ipairs(models) do baseGroups[g][i] = m end
        end
    end
    for g, models in pairs(baseGroups) do
        PopData.carGroups[g] = {}
        for i, m in ipairs(models) do PopData.carGroups[g][i] = m end
    end
    local n = 0
    for _, v in ipairs(list or {}) do
        PopData.vehicles[v.model] = { name = v.name, type = v.type, class = v.class, added = true }
        for _, g in ipairs(v.groups or {}) do
            if PopData.carGroups[g] then
                table.insert(PopData.carGroups[g], v.model)
                n = n + 1
            end
        end
    end
    return n
end

-- One of the gang's weapons (armedChance), and whether it starts in hand (drawnChance) or holstered.
local function gangWeapon(gang)
    local g = Gangs[gang]
    if not g or Population.random() >= g.armedChance then return false end
    local armed = {}
    for _, weapon in ipairs(g.weapons) do if weapon ~= 0 then armed[#armed + 1] = weapon end end
    return randomFrom(armed), Population.random() < (g.drawnChance or 0.5)
end

-- The model's pedstats.dat personality plus per-ped random variance (config/personalities.lua).
function Population.personality(model)
    local ped = PopData.peds[model]
    local base = ped and PopData.pedStats[ped.stat] or PopData.pedStats.STAT_STD_MISSION
    local spread = Personalities.variance
    local function vary(field, lo, hi)
        local value = base[field] + (Population.random() * 2 - 1) * (spread[field] or 0)
        return math.max(lo, math.min(hi, value))
    end
    return {
        stat = ped and ped.stat or "STAT_STD_MISSION",
        fear = vary("fear", 0, 100), temper = vary("temper", 0, 100), lawfulness = vary("lawfulness", 0, 100),
        attackStrength = vary("attackStrength", 0.1, 5), defendWeakness = base.defendWeakness,
        fleeDistance = base.fleeDistance, shootingRate = base.shootingRate, decisionMaker = base.decisionMaker,
    }
end

local function ped(kind, model, extra)
    local spec = extra or {}
    spec.kind, spec.model, spec.personality = kind, model, Population.personality(model)
    return spec
end

-- A ped for a scripted scene (vana-services world events): "gang" (a member of `gang`, armed and
-- with the weapon drawn) or "criminal" (the place's street dealers).
function Population.scenePed(profile, kind, gang)
    if kind == "gang" and Gangs[gang] then
        local model = randomFrom(groupModels(GANG_GROUP_BASE + Gangs[gang].id, profile.city))
        local armed = {}
        for _, weapon in ipairs(Gangs[gang].weapons) do if weapon ~= 0 then armed[#armed + 1] = weapon end end
        return model and ped("gang", model, { gang = gang, weapon = randomFrom(armed), weaponDrawn = true })
    end
    local model = randomFrom(groupModels(DEALER_GROUP, profile.city))
    return model and ped("civilian", model)
end

-- A ped to add near a player. counts: { civilian, cop, dealer, gang, gangs = { [gang] = n } }.
-- Returns { kind, model, gang, group, weapon } or false when the area is full.
function Population.pickPed(profile, counts)
    local kind = pickKind(profile.peds, counts)
    if kind == "gang" then
        local gang = pickGang(profile, counts.gangs or {}, profile.peds.gang)
        local model = gang and randomFrom(groupModels(GANG_GROUP_BASE + Gangs[gang].id, profile.city))
        if model then
            local weapon, drawn = gangWeapon(gang)
            return ped("gang", model, { gang = gang, weapon = weapon, weaponDrawn = drawn })
        end
    elseif kind == "dealer" then
        local model = randomFrom(groupModels(DEALER_GROUP, profile.city))
        if model then return ped("dealer", model) end
    elseif kind == "cop" then
        return ped("cop", cops(profile).ped, { weapon = 22, weaponDrawn = false })
    elseif kind == "civilian" then
        for _ = 1, 10 do
            local group = pickCivilianGroup(profile.row)
            local model = randomFrom(groupModels(group, profile.city, profile.races))
            if model then return ped("civilian", model, { group = PopGroups[group + 1].name, groupIndex = group }) end
        end
    end
    return false
end

local function roadCars(carGroup)
    local list = {}
    for _, id in ipairs(PopData.carGroups[carGroup] or {}) do
        local v = PopData.vehicles[id]
        if v and ROAD_TYPES[v.type] then list[#list + 1] = id end
    end
    return list
end

-- A road vehicle and driver to add near a player; counts as for pickPed, by vehicle.
-- Returns { kind, model, group, driver = ped spec } or false.
function Population.pickCar(profile, counts)
    local kind = pickKind(profile.cars, counts)
    if kind == "gang" then
        local gang = pickGang(profile, counts.gangs or {}, profile.cars.gang)
        local group = gang and GANG_GROUP_BASE + Gangs[gang].id
        local model = group and randomFrom(roadCars(group))
        local members = group and groupModels(group, profile.city)
        local driver = model and randomFrom(members)
        if driver then
            local function member(m)
                local weapon, drawn = gangWeapon(gang)
                return ped("gang", m, { gang = gang, weapon = weapon, weaponDrawn = drawn })
            end
            -- Gang cars roll with their crew (one to three more).
            local crew = {}
            for i = 1, Population.random(1, 3) do crew[i] = member(randomFrom(members)) end
            return { kind = "gang", model = model, gang = gang, driver = member(driver), passengers = crew }
        end
    elseif kind == "cop" then
        local c = cops(profile)
        local partner = Population.random() < 0.5 and { ped("cop", c.ped, { weapon = 22, weaponDrawn = false }) } or {}
        return { kind = "cop", model = Population.variant(c.car, profile), driver = ped("cop", c.ped, { weapon = 22, weaponDrawn = false }), passengers = partner }
    elseif kind == "civilian" then
        for _ = 1, 10 do
            local group = pickCivilianGroup(profile.row)
            local model = randomFrom(roadCars(group))
            local driver = model and randomFrom(groupModels(group, profile.city, profile.races))
            if driver then
                local name = PopGroups[group + 1].name
                local passengers = {}
                if Population.random() < Personalities.civilianPassengerChance then
                    local other = randomFrom(groupModels(group, profile.city, profile.races))
                    if other then passengers[1] = ped("civilian", other, { group = name }) end
                end
                return { kind = "civilian", model = model, group = name, driver = ped("civilian", driver, { group = name }), passengers = passengers }
            end
        end
    end
    return false
end

-- A car for a parked car generator with no fixed model: a car suited to the zone, nothing big
-- (vanilla rejects boats and anything longer than 8 m).
function Population.pickParkedCar(profile)
    for _ = 1, 10 do
        local list = {}
        for _, id in ipairs(roadCars(pickCivilianGroup(profile.row))) do
            local v = PopData.vehicles[id]
            if v.type == "car" and v.class ~= "big" and v.class ~= "ignore" then list[#list + 1] = id end
        end
        local model = randomFrom(list)
        if model then return model end
    end
    return false
end

-- Someone to walk with: a gang member's fellow member, or a civilian's partner of the opposite sex
-- from the same group.
function Population.pickCompanion(profile, spec)
    if spec.kind == "gang" and Gangs[spec.gang] then
        local model = randomFrom(groupModels(GANG_GROUP_BASE + Gangs[spec.gang].id, profile.city))
        if not model then return false end
        local weapon, drawn = gangWeapon(spec.gang)
        return ped("gang", model, { gang = spec.gang, weapon = weapon, weaponDrawn = drawn })
    elseif spec.kind == "civilian" and spec.groupIndex then
        local want = PopData.peds[spec.model].pedType == "CIVMALE" and "CIVFEMALE" or "CIVMALE"
        local list = {}
        for _, id in ipairs(groupModels(spec.groupIndex, profile.city, profile.races)) do
            if PopData.peds[id].pedType == want then list[#list + 1] = id end
        end
        local model = randomFrom(list)
        if model then return ped("civilian", model, { group = spec.group, groupIndex = spec.groupIndex }) end
    end
    return false
end

-- Hour and weekend for population purposes: in-game hour, real-world weekend (Saturday, Sunday).
function Population.now()
    local hour = getTime()
    local weekday = getRealTime().weekday
    return hour, weekday == 0 or weekday == 6
end
