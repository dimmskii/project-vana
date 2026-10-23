-- Loads the added vehicles' TXDs and DFFs onto their own models (allocated by the server: no vanilla
-- model is replaced), and the clean, high-resolution shared vehicle textures into every vehicle model.
local base -- the shared textures (CarBaseTextures)

local function importBase(model)
    if base then engineImportTXD(base, model) end
end

local function load(def, skin)
    local model = engineGetModelIDFromName(def.name)
    if not model then
        outputDebugString(("vana-cars: no model for %s (the server didn't make one)"):format(def.name), 2)
        return
    end
    local txdPath = CarFiles(def) .. ".txd"
    if fileExists(txdPath) then
        local txd = engineLoadTXD(txdPath)
        if txd then engineImportTXD(txd, model) end
    end
    importBase(model)
    if not skin or def.dff then
        local dff = engineLoadDFF(CarFiles(def) .. ".dff")
        if dff then engineReplaceModel(dff, model) end
    end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    base = engineLoadTXD(CarBaseTextures.file)
    for model = 400, 611 do importBase(model) end
    for _, def in ipairs(CarVehicles) do load(def) end
    for _, def in ipairs(CarSkins) do load(def, true) end
end)
