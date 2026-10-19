-- The dashboard of the vehicle you're in: its skin's textures (read from the skin's TXD with
-- sa_txd.lua, once) drawn as config/dashboards.lua lays them out.
local skins = {}   -- name -> { name -> texture } or false (didn't load)
DashboardShown = false -- read by the plain fuel gauge in client.lua, which stands in without a skin

local function skin(name)
    if skins[name] == nil then
        local def = Dashboards.skins[name]
        local textures = def and SATxd.load(def.txd)
        skins[name] = textures and next(textures) and textures or false
        if not skins[name] then outputDebugString("[vana-vehicles] dashboard skin " .. tostring(name) .. " didn't load", 2) end
    end
    return skins[name]
end

-- Values the parts show: speed (km/h), fuel (0..1), nitro (0..1, nil without nitro), locked.
local function values(vehicle)
    local vx, vy, vz = getElementVelocity(vehicle)
    local fuel = getElementData(vehicle, "vana:fuel")
    local nitro = getVehicleUpgradeOnSlot(vehicle, 8) ~= 0 and (getVehicleNitroLevel(vehicle) or 0) or nil
    return {
        speed = math.sqrt(vx * vx + vy * vy + vz * vz) * 50 * 3.6,
        fuel = fuel and VehicleConfig.fuel.enabled and fuel / VehicleConfig.fuel.tank or nil,
        fuelUnits = fuel,
        nitro = nitro,
        locked = isVehicleLocked(vehicle) or nil,
    }
end

-- Shown with the radar: vana-map's (GTA's own is hidden), else GTA's.
function radarShown()
    local map = getResourceFromName("vana-map")
    if map and getResourceState(map) == "running" then return exports["vana-map"]:isRadarShown() end
    return isPlayerHudComponentVisible("radar") and not isPlayerMapVisible()
end

addEventHandler("onClientRender", root, function()
    DashboardShown = false
    local vehicle = getPedOccupiedVehicle(localPlayer)
    local name = vehicle and getElementData(vehicle, "vana:dashboard")
    if not name or not radarShown() then return end
    local textures = skin(name)
    if not textures then return end
    DashboardShown = true
    local W, H = guiGetScreenSize()
    local k = H / 448
    local function box(part)
        local w, h = part.size and part.size[1] * k or 0, part.size and part.size[2] * k or 0
        local cx, cy = W - (640 - part.at[1]) * k, H - (448 - part.at[2]) * k
        return cx - w / 2, cy - h / 2, w, h, cx, cy
    end
    local v = values(vehicle)
    for _, part in ipairs(Dashboards.skins[name].parts) do
        local value = part.value and v[part.value]
        if not part.value or value ~= nil then
            local x, y, w, h, cx, cy = box(part)
            if part.kind == "image" and textures[part.texture] then
                dxDrawImage(x, y, w, h, textures[part.texture])
            elseif part.kind == "needle" and textures[part.texture] then
                dxDrawImage(x, y, w, h, textures[part.texture], part.zero + value * part.per)
            elseif part.kind == "lamp" then
                local tex = textures[part.textures[(v.fuelUnits or 0) < part.below and 2 or 1]]
                if tex then dxDrawImage(x, y, w, h, tex) end
            elseif part.kind == "text" then
                local c = part.colour or { 255, 255, 255 }
                dxDrawText(("%d"):format(value), cx - 40 * k, cy - 8 * k, cx + 40 * k, cy + 8 * k, tocolor(c[1], c[2], c[3], 230),
                    (part.scale or 1) * k / 1.6, "default-bold", "center", "center")
            end
        end
    end
end)
