-- Vending machines and food carts: walk up, /use (F) to buy. The server decides. The nearest one in
-- reach is an offer to vana-controls' /use, which shows its prompt.
local nearby -- index into Vendors
local ID = "vana-shops:vendor"

local function offer(index)
    local res = getResourceFromName("vana-controls")
    if not res or getResourceState(res) ~= "running" then return end
    if index then
        local kind = VendorKinds[Vendors[index].kind]
        exports["vana-controls"]:offer(ID, ("buy %s ($%d)"):format(kind.name, kind.price))
    else
        exports["vana-controls"]:withdraw(ID)
    end
end

setTimer(function()
    local found
    if not getPedOccupiedVehicle(localPlayer) and not isPedDead(localPlayer) then
        local x, y, z = getElementPosition(localPlayer)
        local interior = getElementInterior(localPlayer)
        for i, v in ipairs(Vendors) do
            if v.interior == interior and math.abs(v.z - z) < 2.5 and getDistanceBetweenPoints2D(x, y, v.x, v.y) < VendorReach then
                found = i
                break
            end
        end
    end
    if found ~= nearby then
        nearby = found
        offer(nearby)
    end
end, 250, 0)

addEvent("onClientVanaUse", false)
addEventHandler("onClientVanaUse", root, function(id)
    if id == ID and nearby then triggerServerEvent("vana-shops:vend", resourceRoot, nearby) end
end)
addEvent("onClientVanaUseReset", false)
addEventHandler("onClientVanaUseReset", root, function() offer(nearby) end)
