-- Loads the added vehicles' TXDs and DFFs onto their own models (allocated by the server: no vanilla
-- model is replaced), and the clean, high-resolution shared vehicle textures into every vehicle model.
-- The models' files aren't sent at join (hundreds of MB): each is downloaded the first time a vehicle of
-- it streams in (until then it shows as its parent), and the service vehicles' variants in the
-- background, a few at a time.
local base       -- the shared textures (CarBaseTextures)
local defs = {}  -- model -> { def, skin }
local state = {} -- model -> "loading" | "loaded"
local waiting = {} -- file path -> model, while downloading
local PREFETCH_AT_ONCE = 2

local function importBase(model)
    if base then engineImportTXD(base, model) end
end

local function files(entry)
    local list, def = {}, entry.def
    if not def.noTxd then list[#list + 1] = CarFiles(def) .. ".txd" end
    if not entry.skin or def.dff then list[#list + 1] = CarFiles(def) .. ".dff" end
    return list
end

-- Everything downloaded: the TXD (with the shared textures), then the DFF, onto the model.
local function apply(model)
    local entry = defs[model]
    local def = entry.def
    if not def.noTxd then
        local txd = engineLoadTXD(CarFiles(def) .. ".txd")
        if txd then engineImportTXD(txd, model) end
    end
    importBase(model)
    if not entry.skin or def.dff then
        local dff = engineLoadDFF(CarFiles(def) .. ".dff")
        if dff then engineReplaceModel(dff, model) end
    end
    state[model] = "loaded"
end

local function want(model)
    local entry = defs[model]
    if not entry or state[model] then return end
    state[model] = "loading"
    -- Marked before asking: a file already here completes at once.
    local list = files(entry)
    for _, path in ipairs(list) do waiting[path] = model end
    for _, path in ipairs(list) do
        if not downloadFile(path) then waiting[path] = nil end
    end
    for _, m in pairs(waiting) do if m == model then return end end
    if state[model] == "loading" then apply(model) end
end

addEventHandler("onClientFileDownloadComplete", resourceRoot, function(path, success)
    local model = waiting[path]
    if not model then return end
    waiting[path] = nil
    if not success then
        outputDebugString("vana-cars: couldn't download " .. path, 2)
        state[model] = nil
        return
    end
    for _, m in pairs(waiting) do if m == model then return end end
    apply(model)
end)

addEventHandler("onClientElementStreamIn", root, function()
    if getElementType(source) == "vehicle" then want(getElementModel(source)) end
end)
addEventHandler("onClientElementModelChange", root, function(_, model)
    if getElementType(source) == "vehicle" and isElementStreamedIn(source) then want(model) end
end)

-- The service vehicles' variants (police, ambulances, fire trucks...): fetched in the background.
local prefetch = {}
local function prefetchNext()
    local busy = 0
    for _, s in pairs(state) do if s == "loading" then busy = busy + 1 end end
    while busy < PREFETCH_AT_ONCE and #prefetch > 0 do
        local model = table.remove(prefetch, 1)
        if not state[model] then
            want(model)
            busy = busy + 1
        end
    end
    if #prefetch > 0 then setTimer(prefetchNext, 2000, 1) end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    base = engineLoadTXD(CarBaseTextures.file)
    for model = 400, 611 do importBase(model) end
    local byName = {}
    for _, def in ipairs(CarVehicles) do byName[def.name] = { def = def } end
    for _, def in ipairs(CarSkins) do byName[def.name] = { def = def, skin = true } end
    for name, entry in pairs(byName) do
        local model = engineGetModelIDFromName(name)
        if model then defs[model] = entry
        else outputDebugString(("vana-cars: no model for %s (the server didn't make one)"):format(name), 2) end
    end
    -- What's already around.
    for _, v in ipairs(getElementsByType("vehicle", root, true)) do want(getElementModel(v)) end
    for _, list in pairs(CarVariants) do
        for _, v in ipairs(list) do
            for _, name in ipairs(v.models) do
                local model = engineGetModelIDFromName(name)
                if model then prefetch[#prefetch + 1] = model end
            end
        end
    end
    prefetchNext()
end)
