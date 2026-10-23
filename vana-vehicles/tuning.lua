-- Ambient cars' parts as they're made (config/vehicles.lua `tuning`): vanilla's random hydraulics on
-- lowrider-built models, and ours: some taxis with nitro, tuned street racers and lowriders, the odd
-- set of other wheels. Called by vana-traffic, vana-parked and vana-services' random events.
local T = VehicleConfig.tuning
local WHEELS = "Wheels"
local SKIP = { Nitro = true, Hydraulics = true, Stereo = true }

local function shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

-- Up to `count` slots get one random part each, from what the vehicle fits.
local function randomParts(vehicle, count, wheelsOnly)
    local bySlot = {}
    for _, id in ipairs(getVehicleCompatibleUpgrades(vehicle)) do
        local slot = getVehicleUpgradeSlotName(id)
        if not SKIP[slot] and (not wheelsOnly or slot == WHEELS) then
            bySlot[slot] = bySlot[slot] or {}
            table.insert(bySlot[slot], id)
        end
    end
    local slots = {}
    for slot in pairs(bySlot) do slots[#slots + 1] = slot end
    for i, slot in ipairs(shuffle(slots)) do
        if i > count then break end
        local options = bySlot[slot]
        addVehicleUpgrade(vehicle, options[math.random(#options)])
    end
end

-- An added vehicle (vana-cars) gets its own colours and, for emergency ones, sirens.
function dressAdded(vehicle, keepColours)
    local res = getResourceFromName("vana-cars")
    if not res or getResourceState(res) ~= "running" then return false end
    local ok, done = pcall(function() return exports["vana-cars"]:dress(vehicle, keepColours) end)
    return ok and done
end

function tuneRandomly(vehicle)
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then return false end
    dressAdded(vehicle)
    local model = getElementModel(vehicle)
    local handling = getOriginalHandling(model)
    if handling and handling.handlingFlags and math.floor(handling.handlingFlags / 0x10000) % 2 == 1 and math.random() < T.hydraulicGeom then
        addVehicleUpgrade(vehicle, 1087)
    end
    if T.taxis.models[model] and math.random() < T.taxis.chance then
        addVehicleUpgrade(vehicle, T.taxis.nitro[math.random(#T.taxis.nitro)])
    end
    for _, group in ipairs(T.tuned) do
        if not group.models or group.models[model] then
            if math.random() < group.chance then
                randomParts(vehicle, math.random(group.slots[1], group.slots[2]), group.wheelsOnly)
                local paintjobs = VehicleConfig.paintjobs[model]
                if paintjobs and group.paintjob and math.random() < group.paintjob then setVehiclePaintjob(vehicle, math.random(0, paintjobs - 1)) end
                -- Performance parts (performance.lua): each category by its chance, a level from its range.
                local tune = {}
                for cat, roll in pairs(group.performance or {}) do
                    if math.random() < roll[1] then tune[cat] = math.random(roll[2], roll[3]) end
                end
                if next(tune) then setTuneTable(vehicle, tune) end
            end
            break
        end
    end
    return true
end

-- For the mod garages: how many paintjobs a model has.
function getPaintjobCount(model)
    return VehicleConfig.paintjobs[model] or 0
end

-- Console-only: tune a few hundred cars and check the rates (Voodoo: HYDRAULIC_GEOM, a lowrider;
-- the taxi; the Elegy, a street racer; the Admiral, anything else).
addCommandHandler("tuningtest", function(source)
    if getElementType(source) ~= "console" then return end
    local n, rates = 400, {}
    for _, model in ipairs({ 412, 420, 562, 445 }) do
        local hyd, nitro, parts, pj, turbo = 0, 0, 0, 0, 0
        for i = 1, n do
            local v = createVehicle(model, i * 4, 0, -100)
            tuneRandomly(v)
            for _, id in ipairs(getVehicleUpgrades(v)) do
                if id == 1087 then hyd = hyd + 1 elseif id == 1008 or id == 1009 or id == 1010 then nitro = nitro + 1 else parts = parts + 1 end
            end
            if getVehiclePaintjob(v) ~= 3 then pj = pj + 1 end
            if getTune(v).turbo then turbo = turbo + 1 end
            destroyElement(v)
        end
        rates[#rates + 1] = ("%d: hydraulics %d%%, nitro %d%%, %.2f parts/car, paintjob %d%%, turbo %d%%"):format(model, 100 * hyd / n,
            100 * nitro / n, parts / n, 100 * pj / n, 100 * turbo / n)
    end
    outputServerLog("[tuningtest] " .. table.concat(rates, "; "))
end)
