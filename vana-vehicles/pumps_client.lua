-- The gas station icon, drawn upright in each pump's marker and always facing you, as vana-shops draws
-- the garage and spray icons in theirs. Ours: icons/radar_gasstn.png (vanilla has no fuel icon).
local SIZE, RANGE = 1.5, 80 -- metres across; how far away it shows
local F = VehicleConfig.fuel
local texture -- false if the icon didn't load

addEventHandler("onClientRender", root, function()
    if not F.enabled or getElementInterior(localPlayer) ~= 0 or getElementDimension(localPlayer) ~= 0 then return end
    if texture == nil then
        texture = dxCreateTexture(F.pumpMarker.icon, "argb", true, "clamp") or false
        if not texture then outputDebugString("[vana-vehicles] " .. F.pumpMarker.icon .. " didn't load: no icons in the pump markers", 2) end
    end
    if not texture then return end
    local cx, cy, cz = getCameraMatrix()
    for _, p in ipairs(F.pumps) do
        local z = p[3] + 1.0
        if getDistanceBetweenPoints3D(cx, cy, cz, p[1], p[2], z) < RANGE then
            -- No facing point given: the line's quad turns to the camera.
            dxDrawMaterialLine3D(p[1], p[2], z + SIZE / 2, p[1], p[2], z - SIZE / 2, texture, SIZE)
        end
    end
end)
