-- Vending machines and food carts: walk up, press enter/exit (F) to buy. The server decides.
local nearby -- index into Vendors

setTimer(function()
    nearby = nil
    if getPedOccupiedVehicle(localPlayer) or isPedDead(localPlayer) then return end
    local x, y, z = getElementPosition(localPlayer)
    local interior = getElementInterior(localPlayer)
    for i, v in ipairs(Vendors) do
        if v.interior == interior and math.abs(v.z - z) < 2.5 and getDistanceBetweenPoints2D(x, y, v.x, v.y) < VendorReach then
            nearby = i
            return
        end
    end
end, 250, 0)

addEventHandler("onClientKey", root, function(key, pressed)
    if not nearby or not pressed then return end
    for bound in pairs(getBoundKeys("enter_exit") or {}) do
        if bound == key then
            triggerServerEvent("vana-shops:vend", resourceRoot, nearby)
            cancelEvent()
            return
        end
    end
end)

addEventHandler("onClientRender", root, function()
    if not nearby then return end
    local kind = VendorKinds[Vendors[nearby].kind]
    local key = next(getBoundKeys("enter_exit") or {}) or "F"
    local sw, sh = guiGetScreenSize()
    local s = sh / 720
    local text = ("Press %s to buy %s ($%d)"):format(key:upper(), kind.name, kind.price)
    dxDrawRectangle(40 * s, 120 * s, 360 * s, 34 * s, tocolor(0, 0, 0, 170))
    dxDrawText(text, 52 * s, 120 * s, 400 * s, 154 * s, tocolor(255, 255, 255), 1.15 * s, "default-bold", "left", "center")
end)
