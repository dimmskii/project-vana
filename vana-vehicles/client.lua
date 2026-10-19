-- The fuel gauge (radio: vana-radio).
local F = VehicleConfig.fuel
local refuel = { active = false, text = nil, shownUntil = 0 }

----------------------------------------------------------------------------------------------------
-- Plain fuel gauge, above the radar (where vanilla draws nothing in a car): when the vehicle's
-- dashboard skin (dashboard_client.lua) isn't shown

local function sx(v) return v * (select(2, guiGetScreenSize()) / 720) end

addEvent("vana-vehicles:refuel", true)
addEventHandler("vana-vehicles:refuel", resourceRoot, function(active, paid, text)
    refuel.active = active
    if not active then
        refuel.text = text or (paid and paid > 0 and ("Refuelled: $" .. paid)) or nil
        refuel.shownUntil = getTickCount() + 3000
    end
end)

addEventHandler("onClientRender", root, function()
    local vehicle = getPedOccupiedVehicle(localPlayer)
    local fuel = vehicle and getElementData(vehicle, "vana:fuel")
    if not fuel or not F.enabled or isPlayerMapVisible() or DashboardShown then return end
    local W, H = guiGetScreenSize()
    -- The radar sits at (40, 344) in vanilla's 640x448 HUD space, 94 x 76.
    local x, w = W * 40 / 640, W * 94 / 640
    local y, h = H * (448 - 104) / 448 - sx(16), sx(7)
    local share = math.max(0, math.min(1, fuel / F.tank))
    dxDrawRectangle(x - 1, y - 1, w + 2, h + 2, tocolor(0, 0, 0, 200))
    local colour = fuel < F.low and tocolor(200, 50, 40, 230) or tocolor(220, 180, 60, 230)
    dxDrawRectangle(x, y, w * share, h, colour)
    dxDrawText("FUEL", x, y - sx(16), x + w, y, tocolor(220, 220, 220, 230), sx(0.9), "default-bold", "left", "bottom")
    if refuel.active then
        dxDrawText("Refuelling...", 0, H * 0.7, W, H * 0.75, tocolor(255, 255, 255), sx(1.4), "default-bold", "center", "center")
    elseif refuel.text and getTickCount() < refuel.shownUntil then
        dxDrawText(refuel.text, 0, H * 0.7, W, H * 0.75, tocolor(255, 255, 255), sx(1.4), "default-bold", "center", "center")
    end
end)
