-- Added vehicles: each a new model of its own on a vanilla parent (Neon's server-side engineRequestModel:
-- the same ID on every client, no vanilla model replaced), with its handling; the client loads its DFF
-- and TXD (client.lua). Other resources ask here which models there are, where they belong (car groups,
-- service variants), and have their vehicles dressed (colours, sirens).
local added = {}   -- name -> { model, def (CarVehicles or CarSkins entry), skin }
local byModel = {} -- model -> the same entry

local function warn(text) outputServerLog("[vana-cars] WARNING: " .. text) end

-- A handling.cfg value as setModelHandling takes it.
local DRIVE = { F = "fwd", R = "rwd", ["4"] = "awd" }
local ENGINE = { P = "petrol", D = "diesel", E = "electric" }
local LIGHTS = { [0] = "long", [1] = "small", [2] = "big", [3] = "tall" }
local function handlingValue(property, raw)
    if property == "driveType" then return DRIVE[raw:upper()] end
    if property == "engineType" then return ENGINE[raw:upper()] end
    if property == "modelFlags" or property == "handlingFlags" then return tonumber(raw, 16) end
    if property == "headLight" or property == "tailLight" then return LIGHTS[tonumber(raw)] end
    if property == "ABS" then return tonumber(raw) == 1 end
    return tonumber(raw)
end

-- Handling MTA keeps for itself (setModelHandling refuses them): the car's value and its lights' shapes.
local NOT_SETTABLE = { monetary = true, headLight = true, tailLight = true }

local function applyHandling(model, line)
    local fields = {}
    for f in line:gmatch("%S+") do fields[#fields + 1] = f end
    local com = {}
    for i, property in ipairs(CarHandlingColumns) do
        local raw = fields[i + 1]
        if raw then
            if property:find("^centerOfMass") then
                com[#com + 1] = tonumber(raw)
                if #com == 3 then setModelHandling(model, "centerOfMass", com) end
            elseif not NOT_SETTABLE[property] then
                local value = handlingValue(property, raw)
                if value ~= nil and not setModelHandling(model, property, value) then
                    warn(("model %d: handling %s = %s not taken"):format(model, property, raw))
                end
            end
        end
    end
end

local function allocate(def, skin)
    local model = engineRequestModel("vehicle", def.parent, def.name)
    if not model then return warn(("couldn't make a model for %s (on %d)"):format(def.name, def.parent)) end
    local entry = { model = model, def = def, skin = skin }
    added[def.name], byModel[model] = entry, entry
    if def.handling then applyHandling(model, def.handling) end
end

for _, def in ipairs(CarVehicles) do allocate(def) end
for _, def in ipairs(CarSkins) do allocate(def, true) end

-- carcols.dat sets: whitespace-separated, each "primary,secondary[,3rd,4th]".
local function colourSets(text)
    local sets = {}
    for token in tostring(text or ""):gmatch("[^%s]+") do
        local set = {}
        for n in token:gmatch("%d+") do set[#set + 1] = tonumber(n) end
        if #set >= 2 then sets[#sets + 1] = set end
    end
    return sets
end

---------------------------------------------------------------------------------------------------
-- Exports

-- A model by name (ours: the model allocated for it), or false.
function getModel(name)
    local entry = added[tostring(name):lower()]
    return entry and entry.model or false
end

-- Every added model: { name, model, parent, type, class, label, display, groups, skin }.
function getAddedVehicles()
    local list = {}
    for name, e in pairs(added) do
        list[#list + 1] = { name = name, model = e.model, parent = e.def.parent, type = e.def.type, class = e.def.class,
                            label = e.def.label, display = e.def.display, groups = e.def.groups or {}, skin = e.skin }
    end
    table.sort(list, function(a, b) return a.model < b.model end)
    return list
end

-- The game-text key and plain name of an added model (for display: the label's text, else `display`).
function getModelName(model)
    local e = byModel[model]
    if not e then return false end
    return e.def.label, e.def.display
end

-- The vanilla model a model is built on (itself for a vanilla one).
function getParent(model)
    local e = byModel[model]
    return e and e.def.parent or model
end

-- What to use for a vanilla service vehicle here: it or one of its variants (CarVariants), at random;
-- a retexture of it now and then (CarSkins chance). city: vana-population's city name; zone: info.zon's.
function pickVariant(model, city, zone)
    local pool, replaced = { model }, false
    for _, v in ipairs(CarVariants[model] or {}) do
        local here = true
        if v.cities then
            here = false
            for _, c in ipairs(v.cities) do if c == city then here = true end end
        end
        if v.zones then
            here = false
            for _, z in ipairs(v.zones) do if tostring(zone):upper() == z:upper() then here = true end end
        end
        if here then
            if v.replace and not replaced then pool, replaced = {}, true end
            for _, name in ipairs(v.models) do
                if added[name] then pool[#pool + 1] = added[name].model end
            end
        end
    end
    if #pool == 0 then pool = { model } end
    local pick = pool[math.random(#pool)]
    for _, def in ipairs(CarSkins) do
        if def.parent == pick and added[def.name] and math.random() < (def.chance or 0) then return added[def.name].model end
    end
    return pick
end

-- A vehicle just made by any resource: an added model gets one of its own colour sets (unless
-- keepColours: a kept car rebuilt with its own), and sirens if it's an emergency vehicle (the game only
-- gives its own models theirs).
function dress(vehicle, keepColours)
    if not isElement(vehicle) then return false end
    local e = byModel[getElementModel(vehicle)]
    if not e then return false end
    local sets = colourSets(e.def.colours)
    if #sets > 0 and not keepColours then
        local s = sets[math.random(#sets)]
        setVehicleColor(vehicle, s[1], s[2], s[3] or 0, s[4] or 0)
    end
    local siren = CarSirens[e.def.parent]
    if siren and not e.skin then
        addVehicleSirens(vehicle, 2, 2, false, true, true, false)
        for i, c in ipairs(siren.colours) do
            setVehicleSirens(vehicle, i, i == 1 and -0.45 or 0.45, 0, siren.z, c[1], c[2], c[3], 255, 255)
        end
    end
    return true
end

-- Console-only: every added model made, with its files and a name.
addCommandHandler("carstest", function(source)
    if getElementType(source) ~= "console" then return end
    local ok, problems, n = true, {}, 0
    local function check(cond, text) if not cond then ok = false problems[#problems + 1] = text end end
    for _, def in ipairs(CarVehicles) do
        n = n + 1
        local e = added[def.name]
        check(e ~= nil, def.name .. ": no model")
        check(fileExists(CarFiles(def) .. ".dff"), def.name .. ": no " .. CarFiles(def) .. ".dff")
        check(def.noTxd or fileExists(CarFiles(def) .. ".txd"), def.name .. ": no " .. CarFiles(def) .. ".txd")
        check(def.display or def.label, def.name .. ": no name")
        check(def.credit and def.credit ~= "", def.name .. ": no credit")
        if #colourSets(def.colours) == 0 and def.type ~= "trailer" and def.type ~= "train" then
            outputServerLog("[carstest] note: " .. def.name .. " has no colours of its own (its parent's)")
        end
    end
    for _, def in ipairs(CarSkins) do
        n = n + 1
        check(added[def.name] ~= nil, def.name .. ": no model")
        check(fileExists(CarFiles(def) .. ".txd"), def.name .. ": no " .. CarFiles(def) .. ".txd")
        check(not def.dff or fileExists(CarFiles(def) .. ".dff"), def.name .. ": no " .. CarFiles(def) .. ".dff")
    end
    for vanilla, list in pairs(CarVariants) do
        for _, v in ipairs(list) do
            for _, name in ipairs(v.models) do check(added[name] ~= nil, ("variant %s of %d: not an added vehicle"):format(name, vanilla)) end
        end
    end
    check(fileExists(CarBaseTextures.file), "no " .. CarBaseTextures.file)
    for _, p in ipairs(problems) do outputServerLog("[carstest] FAIL " .. p) end
    local first, last
    for _, e in pairs(added) do
        first = math.min(first or e.model, e.model)
        last = math.max(last or e.model, e.model)
    end
    outputServerLog(("[carstest] %d models (ids %s-%s)"):format(n, tostring(first), tostring(last)))
    outputServerLog("[carstest] " .. (ok and "PASS" or "FAIL"))
end)
