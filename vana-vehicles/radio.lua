-- Car radio stations. Each car with a radio has a station ("vana:radio": vana-radio's station ID,
-- 1..11 vanilla's, 0 off), first picked as vanilla does: one of its driver's two favourites
-- (peds.ide), else the model's default. vana-radio plays it and retunes it.

local function call(resource, fn, ...)
    local res = getResourceFromName(resource)
    if not res or getResourceState(res) ~= "running" then return end
    local result = { pcall(function(...) return exports[resource][fn](exports[resource], ...) end, ...) }
    if result[1] then return unpack(result, 2) end
end

-- driverModel: the ped model choosing (as CPed::SetRadioStation), or nil for the model's default.
function assignRadio(vehicle, driverModel)
    if not isElement(vehicle) or getElementData(vehicle, "vana:radio") ~= false and getElementData(vehicle, "vana:radio") ~= nil then
        return false
    end
    local info = VehicleRadio[getElementModel(vehicle)]
    if not info or info[1] ~= "civilian" then return false end
    local station = info[2]
    if driverModel then
        local r1, r2 = call("vana-population", "getPedRadio", driverModel)
        local pick = math.random() < 0.5 and r1 or r2
        if pick and pick >= 1 and pick <= 11 then station = pick end
    end
    setElementData(vehicle, "vana:radio", station)
    return station
end

-- A player getting into a vehicle: its dashboard skin, chosen once (config/dashboards.lua).
addEventHandler("onVehicleEnter", root, function(player)
    if getElementType(player) ~= "player" or getElementData(source, "vana:dashboard") then return end
    local model = getElementModel(source)
    if not Dashboards.none[model] then setElementData(source, "vana:dashboard", Dashboards.models[model] or Dashboards.default) end
end)

-- A player getting into a car with no station yet takes its driver's favourite, as in vanilla.
addEventHandler("onVehicleEnter", root, function(player)
    if getElementType(player) ~= "player" then return end
    local driver = getVehicleOccupant(source, 0)
    assignRadio(source, driver and driver ~= player and getElementType(driver) == "ped" and getElementModel(driver) or nil)
end)
