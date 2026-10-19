PopData.load()

function getZoneAt(x, y, z)
    local name, zone = Population.zoneAt(x, y, z)
    return name, zone, Population.cityAt(x, y)
end

function getProfile(x, y, z)
    return Population.profile(x, y, z, Population.now())
end

-- counts: what already exists around the spawn point; see Population.pickPed / pickCar.
-- scale: multiplies the vanilla targets (1 = vanilla density).
local function scaled(x, y, z, scale)
    local p = Population.profile(x, y, z, Population.now())
    for _, targets in ipairs({ p.peds, p.cars }) do
        for kind, n in pairs(targets) do targets[kind] = n * (scale or 1) end
    end
    return p
end

function pickPed(x, y, z, counts, scale)
    return Population.pickPed(scaled(x, y, z, scale), counts or {})
end

function pickCar(x, y, z, counts, scale)
    return Population.pickCar(scaled(x, y, z, scale), counts or {})
end

function getPersonality(model)
    return Population.personality(model)
end

function pickScenePed(x, y, z, kind, gang)
    return Population.scenePed(Population.profile(x, y, z, Population.now()), kind, gang)
end

-- A driver's favourite stations (MTA radio channels), as CPed::SetRadioStation picks from.
function getPedRadio(model)
    local ped = PopData.peds[model]
    return ped and ped.radio[1], ped and ped.radio[2]
end

function getPersonalityRules()
    return Personalities
end

-- Console-only: validates the parsed data and samples what populates a few known places.
local PLACES = {
    { "Grove Street", 2495, -1687, 13 },
    { "El Corona", 1750, -2000, 13 },
    { "LS airport", 1550, -2300, 13 },
    { "SF golf club", -2315, -385, 35 },
    { "SF downtown", -1925, 1000, 35 },
}

addCommandHandler("poptest", function(source, _, hourArg)
    if getElementType(source) ~= "console" then return end
    local ok = true
    local function check(cond, msg)
        if not cond then ok = false; outputServerLog("[poptest] FAIL " .. msg) end
    end
    local log = function(msg) outputServerLog("[poptest] " .. msg) end

    for _, zoneType in ipairs(PopData.ZONE_TYPES) do
        local rows = PopData.popcycle[zoneType]
        check(rows and #rows[1] == 12 and #rows[2] == 12, "popcycle rows for " .. zoneType)
        for _, half in ipairs(rows or {}) do
            for _, row in ipairs(half) do check(#row.groups == 18, "popcycle group columns in " .. zoneType) end
        end
    end
    local maxLine = 0
    for _, g in ipairs(PopGroups) do for _, line in ipairs(g.pedgrp) do maxLine = math.max(maxLine, line) end end
    check(PopData.pedGroupCount == maxLine + 1, ("pedgrp.dat has %d lines, groups.lua expects %d"):format(PopData.pedGroupCount, maxLine + 1))
    check(#PopData.unknownPeds == 0, "unknown ped models in pedgrp.dat: " .. table.concat(PopData.unknownPeds, ", "))
    check(#PopData.unknownCars == 0, "unknown vehicle models in cargrp.dat: " .. table.concat(PopData.unknownCars, ", "))
    local zoneNames = {}
    for _, zone in ipairs(PopData.zones) do zoneNames[zone.name] = true end
    local configured = 0
    for name in pairs(PopZones) do
        configured = configured + 1
        check(zoneNames[name], "config zone " .. name .. " not in info.zon")
    end
    log(("data: %d info.zon zones (%d configured), %d ped groups, %d car groups, %d ped models, %d vehicles")
        :format(#PopData.zones, configured, PopData.pedGroupCount, PopData.carGroupCount, PopData.pedCount, PopData.vehicleCount))

    local hour = tonumber(hourArg) or 12
    for _, place in ipairs(PLACES) do
        local name, x, y, z = unpack(place)
        local p = Population.profile(x, y, z, hour, false)
        log(("%s @%02d:00: zone %s (%s, %s), max %d peds / %d cars; ped targets civ %.1f gang %.1f cop %.1f dealer %.1f")
            :format(name, hour, tostring(p.zone), p.type, p.city, p.maxPeds, p.maxCars, p.peds.civilian, p.peds.gang, p.peds.cop, p.peds.dealer))

        -- Fill the area as spawning would, 100 times over, and tally what appears.
        local kinds, gangs, peds, cars = {}, {}, {}, {}
        for _ = 1, 100 do
            local pc, cc = { gangs = {} }, { gangs = {} }
            for _ = 1, 40 do
                local ped = Population.pickPed(p, pc)
                if not ped then break end
                pc[ped.kind] = (pc[ped.kind] or 0) + 1
                kinds[ped.kind] = (kinds[ped.kind] or 0) + 1
                if ped.gang then pc.gangs[ped.gang] = (pc.gangs[ped.gang] or 0) + 1; gangs[ped.gang] = (gangs[ped.gang] or 0) + 1 end
                local pname = PopData.peds[ped.model].name
                peds[pname] = (peds[pname] or 0) + 1
            end
            for _ = 1, 40 do
                local car = Population.pickCar(p, cc)
                if not car then break end
                cc[car.kind] = (cc[car.kind] or 0) + 1
                local vname = PopData.vehicles[car.model].name
                cars[vname] = (cars[vname] or 0) + 1
                check(PopData.peds[car.driver.model], "car without a valid driver model")
            end
        end
        local function top(t, n)
            local list = {}
            for k, v in pairs(t) do list[#list + 1] = { k, v } end
            table.sort(list, function(a, b) return a[2] > b[2] end)
            local out = {}
            for i = 1, math.min(n, #list) do out[i] = list[i][1] .. " " .. list[i][2] end
            return table.concat(out, ", ")
        end
        log("  kinds: " .. top(kinds, 4) .. (next(gangs) and " | gangs: " .. top(gangs, 4) or ""))
        log("  peds: " .. top(peds, 6))
        log("  cars: " .. top(cars, 6))
    end
    -- Every model in a ped group must resolve to a personality.
    local missing = {}
    for _, models in pairs(PopData.pedGroups) do
        for _, id in ipairs(models) do
            local stat = PopData.peds[id] and PopData.peds[id].stat
            if not PopData.pedStats[stat] then missing[#missing + 1] = tostring(stat) end
        end
    end
    check(#missing == 0, "ped stats missing from pedstats.dat: " .. table.concat(missing, ", "))
    local p = Population.personality(PopData.pedIds["fam1"])
    log(("personality FAM1 (%s): fear %.0f temper %.0f lawfulness %.0f attack %.2f"):format(p.stat, p.fear, p.temper, p.lawfulness, p.attackStrength))

    log(ok and "PASS" or "FAIL")
end)

function getDropRules()
    return Drops
end

function pickParkedCar(x, y, z)
    return Population.pickParkedCar(Population.profile(x, y, z, Population.now()))
end

function pickCompanion(x, y, z, spec)
    return Population.pickCompanion(Population.profile(x, y, z, Population.now()), spec)
end

function getCompanionRules()
    return Companions
end

function getServiceUnit(x, y, z, service)
    return Population.serviceUnit(Population.profile(x, y, z, Population.now()), service)
end
