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

-- Debug topic "load" (docs/debug.md): each model set up, and what was last set up before a crash. The
-- last step is also kept in a file, since a crash inside engineReplaceModel takes the queued event with it.
local TRACE = "@load-trace.txt"
local function debugLog(text)
    local v = getElementData(resourceRoot, "vana:debug")
    if v == "all" or (type(v) == "string" and ("," .. v .. ","):find(",load,", 1, true)) then
        triggerServerEvent("vana-core:debug", localPlayer, "vana-cars", "load", text)
    end
end
-- The game has room for 50 vehicle models set up at once (its CVehicleStructure pool); one more and it
-- crashes in CVehicleModelInfo::PreprocessHierarchy (0x4C8F24). MTA's model cache alone keeps up to 56
-- vehicle models loaded (with 128 MB+ of streaming memory), on top of the ones in view: with hundreds
-- of different models in traffic that fills the pool. So the cache is kept small.
local MODEL_CACHE = 12
local POOL_WARN = 44
local function loadedVehicleModels()
    local n = 0
    for model = 400, 611 do
        if engineStreamingGetModelLoadState(model) ~= "unloaded" then n = n + 1 end
    end
    for model in pairs(defs) do
        if engineStreamingGetModelLoadState(model) ~= "unloaded" then n = n + 1 end
    end
    return n
end
local function trace(text)
    local f = fileCreate(TRACE)
    if f then fileWrite(f, text) fileClose(f) end
end

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
    local what = ("%s (%d)%s"):format(def.name, model, isMTAWindowActive() and "" or ", window in the background")
    trace(("%d loading %s"):format(getRealTime().timestamp, what))
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
    trace(("%d loaded %s"):format(getRealTime().timestamp, what))
    debugLog(("loaded %s; %d vehicle models loaded"):format(what, loadedVehicleModels()))
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

addEventHandler("onClientResourceStop", resourceRoot, function()
    trace("clean")
    engineStreamingSetModelCacheLimits()
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    if fileExists(TRACE) then
        local f = fileOpen(TRACE, true)
        local last = f and fileRead(f, fileGetSize(f)) or ""
        if f then fileClose(f) end
        local at, step = last:match("^(%d+) (.*)$")
        if at then debugLog(("last session didn't stop cleanly; its last model step, %d s before this start: %s"):format(getRealTime().timestamp - tonumber(at), step)) end
    end
    trace("clean")
    engineStreamingSetModelCacheLimits(MODEL_CACHE)
    -- How close the pool is getting (debug), at most once a minute.
    local warned = 0
    setTimer(function()
        local n = loadedVehicleModels()
        if n >= POOL_WARN and getTickCount() - warned > 60000 then
            warned = getTickCount()
            debugLog(("%d vehicle models loaded (the game has room for 50)"):format(n))
        end
    end, 5000, 0)
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
