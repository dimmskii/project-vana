-- Performance parts (config/vehicles.lua `performance`): a car's tune is element data `vana:tune`
-- (category -> level, synced: the turbo's whine is played by clients), kept with the car like its
-- colours. Its handling is always worked out from the model's original handling with the tune's
-- levels on top, so levels never compound and a rebalanced config applies to every car.
local P = VehicleConfig.performance
local touched = {} -- every handling property any level changes
for _, cat in pairs(P.categories) do
    for _, level in ipairs(cat.levels) do
        for prop in pairs(level.mul or {}) do touched[prop] = true end
        for prop in pairs(level.set or {}) do touched[prop] = true end
    end
end

local function copy(t)
    local out = {}
    for k, v in pairs(type(t) == "table" and t or {}) do out[k] = v end
    return out
end

function getTune(vehicle)
    return copy(isElement(vehicle) and getElementData(vehicle, "vana:tune"))
end

-- The handling the tune gives this car: the original values of everything any level touches, then
-- each level's multipliers and settings.
local function applyTune(vehicle, tune)
    local original = getOriginalHandling(getElementModel(vehicle))
    if not original then return end
    local values = {}
    for prop in pairs(touched) do values[prop] = original[prop] end
    for name, level in pairs(tune) do
        local def = P.categories[name] and P.categories[name].levels[level]
        if def then
            for prop, m in pairs(def.mul or {}) do
                if type(values[prop]) == "number" then values[prop] = values[prop] * m end
            end
            for prop, v in pairs(def.set or {}) do values[prop] = v end
        end
    end
    for prop, v in pairs(values) do
        if v ~= nil then setVehicleHandling(vehicle, prop, v) end
    end
end

-- The whole tune at once (the garages' try-on and restore, rebuilding a kept car). Unknown categories
-- and levels are dropped; level 0 is stock.
function setTuneTable(vehicle, tune)
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then return false end
    local clean = {}
    for name, level in pairs(type(tune) == "table" and tune or {}) do
        local cat = P.categories[name]
        level = tonumber(level)
        if cat and level and cat.levels[level] then clean[name] = level end
    end
    setElementData(vehicle, "vana:tune", next(clean) and clean or nil)
    applyTune(vehicle, clean)
    return true
end

function setTune(vehicle, category, level)
    local tune = getTune(vehicle)
    tune[category] = (level or 0) > 0 and level or nil
    return setTuneTable(vehicle, tune)
end

-- For the mod garages: the categories in order, each { key, name, levels = { { name, price } } }.
function getTuneOptions()
    local out = {}
    for _, key in ipairs(P.order) do
        local cat = P.categories[key]
        local levels = {}
        for i, l in ipairs(cat.levels) do levels[i] = { name = l.name, price = l.price } end
        out[#out + 1] = { key = key, name = cat.name, levels = levels }
    end
    return out
end

-- Console-only: a car tuned and untuned gets back exactly its model's handling, and stage 3 + turbo
-- multiply as configured.
addCommandHandler("performancetest", function(source)
    if getElementType(source) ~= "console" then return end
    local v = createVehicle(411, 0, 0, -60)
    local original = getOriginalHandling(411)
    setTuneTable(v, { engine = 3, turbo = 1, brakes = 2, drivetrain = 1, armour = 2, lightweight = 1 })
    local h = getVehicleHandling(v)
    local accel = original.engineAcceleration * 1.32 * 1.25
    local mass = original.mass * 1.12 * 0.88
    local ok = math.abs(h.engineAcceleration - accel) < 0.01 and h.driveType == "awd" and h.ABS == true and math.abs(h.mass - mass) < 1
    setTuneTable(v, {})
    local back = getVehicleHandling(v)
    for prop in pairs(touched) do
        if back[prop] ~= original[prop] and not (type(back[prop]) == "number" and math.abs(back[prop] - original[prop]) < 1e-4) then
            ok = false
            outputServerLog("[performancetest] " .. prop .. " not restored: " .. tostring(back[prop]) .. " vs " .. tostring(original[prop]))
        end
    end
    destroyElement(v)
    outputServerLog("[performancetest] " .. (ok and "PASS" or "FAIL"))
end)
