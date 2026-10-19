-- The radar icons, drawn upright in the mod garages' and Pay 'n' Sprays' markers, always facing you:
-- vanilla's own sprites (radar_modGarage, radar_spray) from hud.txd (data/hud.txd, copied at setup).
local SIZE, RANGE = 1.5, 80 -- metres across; how far away they show
local points = {}           -- { x, y, z (the icon's middle), sprite }
local textures              -- name -> texture, false if hud.txd didn't load

for _, g in ipairs(GarageConfig.garages) do points[#points + 1] = { g.x, g.y, g.z + 1.0, "radar_modgarage" } end
for _, g in ipairs(SprayConfig.garages) do
    points[#points + 1] = { g.corner[1] + (g.a[1] + g.b[1]) / 2, g.corner[2] + (g.a[2] + g.b[2]) / 2, g.corner[3] + 1.6, "radar_spray" }
end

addEventHandler("onClientRender", root, function()
    if getElementInterior(localPlayer) ~= 0 or getElementDimension(localPlayer) ~= 0 then return end
    if textures == nil then
        textures = SATxd.load("data/hud.txd") or false
        if not textures then outputDebugString("[vana-shops] data/hud.txd didn't load (see docs/setup.md): no icons in the garage markers", 2) end
    end
    if not textures then return end
    local cx, cy, cz = getCameraMatrix()
    for _, p in ipairs(points) do
        local tex = textures[p[4]]
        if tex and getDistanceBetweenPoints3D(cx, cy, cz, p[1], p[2], p[3]) < RANGE then
            -- No facing point given: the line's quad turns to the camera.
            dxDrawMaterialLine3D(p[1], p[2], p[3] + SIZE / 2, p[1], p[2], p[3] - SIZE / 2, tex, SIZE)
        end
    end
end)
