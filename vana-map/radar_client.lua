-- The radar, ours in place of GTA's (hidden): where GTA's would be (Neon's radar layout: position and
-- size in pixels), the radar tiles around you in a disc on the stock radar's water (#738AAF), turned
-- with the camera or north up (preferences), vanilla's ring round it, every point and blip (draw_client.lua)
-- at the preferred size, the GPS route, north and you. Like vanilla: nearby icons (shops, gas stations)
-- only within their range (times the preferred multiplier), the rest kept at the rim when off the
-- disc; squares show above or below you as triangles; the radar sees further the faster you drive, and
-- further still flying. Indoors: no map, just the disc with blips.
Radar = {}
local WATER, INDOORS = tocolor(0x73, 0x8A, 0xAF), tocolor(16, 16, 20, 235)
local ROUTE = tocolor(220, 60, 200, 235)
local FOOT, DRIVE, FLY = 150, 300, 480 -- metres from the middle to the rim: on foot, driving fast, flying high
local target, mask, size -- the render target (size x size), the disc shader
local range = FOOT
local hidden -- by another script (exports setRadarHidden)

local function layout()
    local ok, x, y = pcall(getPlayerHudComponentProperty, "radar", "position")
    local ok2, w = pcall(getPlayerHudComponentProperty, "radar", "size")
    if ok and ok2 and type(x) == "number" and type(w) == "number" and w > 0 then return x, y, w end
    -- Vanilla's place: (40, 344) in its 640 x 448 HUD space, 94 across.
    local sw, sh = guiGetScreenSize()
    return sw * 40 / 640, sh * 344 / 448, sw * 94 / 640
end

function Radar.shown()
    return not hidden and not MapView.isOpen() and not isPedDead(localPlayer)
end

-- Exports for other client scripts (vana-vehicles' dashboards sit by the radar).
function isRadarShown() return Radar.shown() end
function setRadarHidden(on) hidden = on and true or nil end

addEventHandler("onClientResourceStart", resourceRoot, function()
    setPlayerHudComponentVisible("radar", false)
    MapDraw.load()
end)
addEventHandler("onClientResourceStop", resourceRoot, function() setPlayerHudComponentVisible("radar", true) end)

-- How far the radar sees: vanilla's zoom out with speed, and with height in the air.
local function wantedRange()
    local vehicle = getPedOccupiedVehicle(localPlayer)
    if not vehicle then return FOOT end
    local vx, vy, vz = getElementVelocity(vehicle)
    local speed = math.sqrt(vx * vx + vy * vy + vz * vz) * 50 -- m/s
    local kind = getVehicleType(vehicle)
    if kind == "Plane" or kind == "Helicopter" then
        local x, y, z = getElementPosition(vehicle)
        local ground = getGroundPosition(x, y, z) or z
        return DRIVE + (FLY - DRIVE) * math.min(1, math.max(0, (z - ground) / 200))
    end
    return FOOT + (DRIVE - FOOT) * math.min(1, speed / 45)
end

-- World offset (dx, dy) to the disc, in pixels from its middle: `sin`, `cos` of the heading at the top.
local function rotate(dx, dy, sin, cos, k)
    return (cos * dx - sin * dy) * k, -(sin * dx + cos * dy) * k
end

addEventHandler("onClientRender", root, function()
    if not Radar.shown() then return end
    local x, y, w = layout()
    local d = math.floor(w + 0.5)
    if d < 8 then return end
    if size ~= d then
        if isElement(target) then destroyElement(target) end
        target, size = dxCreateRenderTarget(d, d, true), d
        if not mask then mask = dxCreateShader("mask.fx") end
        if mask and target then dxSetShaderValue(mask, "gTexture", target) end
    end
    if not target or not mask then return end

    local px, py, pz = getElementPosition(localPlayer)
    local vehicle = getPedOccupiedVehicle(localPlayer)
    if vehicle then px, py, pz = getElementPosition(vehicle) end
    range = range + (wantedRange() - range) * 0.05
    local r = d / 2
    local k = r / range -- pixels per metre
    local heading = 0 -- the world direction at the top of the disc, clockwise from north
    if MapDraw.pref("minimap.rotation", "camera") == "camera" then
        local cx, cy, _, lx, ly = getCameraMatrix()
        heading = math.atan2(lx - cx, ly - cy)
    end
    local sin, cos = math.sin(heading), math.cos(heading)
    local indoors = getElementInterior(localPlayer) ~= 0

    -- The map, in the render target.
    dxSetRenderTarget(target, true)
    dxDrawRectangle(0, 0, d, d, indoors and INDOORS or WATER)
    if not indoors then
        local T, half = MapDraw.TILE, MapDraw.WORLD / 2
        local tilePx = T * k
        local reach = range * 1.42
        local rot = -math.deg(heading)
        for row = math.max(0, math.floor((half - py - reach) / T)), math.min(MapDraw.TILES - 1, math.floor((half - py + reach) / T)) do
            for col = math.max(0, math.floor((px + half - reach) / T)), math.min(MapDraw.TILES - 1, math.floor((px + half + reach) / T)) do
                local tex = MapDraw.tile(row, col)
                if tex then
                    -- Unturned (north up), then turned about the disc's middle.
                    local ux, uy = r + (-half + col * T - px) * k, r - (half - row * T - py) * k
                    dxDrawImage(ux, uy, tilePx + 1, tilePx + 1, tex, rot, r - (ux + tilePx / 2), r - (uy + tilePx / 2))
                end
            end
        end
        local route = MapView.route()
        if route then
            local lx, ly = rotate(route[1] - px, route[2] - py, sin, cos, k)
            for i = 3, #route - 1, 2 do
                local nx, ny = rotate(route[i] - px, route[i + 1] - py, sin, cos, k)
                if (lx * lx + ly * ly) < (r * 1.5) ^ 2 or (nx * nx + ny * ny) < (r * 1.5) ^ 2 then
                    dxDrawLine(r + lx, r + ly, r + nx, r + ny, ROUTE, math.max(2, d / 60))
                end
                lx, ly = nx, ny
            end
        end
    end
    dxSetRenderTarget()
    dxDrawImage(x, y, d, d, mask)

    -- The ring: vanilla's radardisc, a quarter, four times round the disc.
    local disc = MapDraw.sprite("radardisc")
    if disc then
        local pad = d * 0.045
        local q = d / 2 + pad
        dxDrawImage(x - pad, y - pad, q, q, disc, 0)
        dxDrawImage(x + d / 2, y - pad, q, q, disc, 90)
        dxDrawImage(x + d / 2, y + d / 2, q, q, disc, 180)
        dxDrawImage(x - pad, y + d / 2, q, q, disc, 270)
    end

    -- Points and blips.
    local icon = d * 0.12 * (tonumber(MapDraw.pref("minimap.blipSize", 1)) or 1)
    local near = tonumber(MapDraw.pref("minimap.blipRange", 1)) or 1
    local mx, my = x + r, y + r
    local rim = r - icon * 0.35
    for _, item in ipairs(MapDraw.items(getElementDimension(localPlayer), getElementInterior(localPlayer))) do
        local dx, dy = item.x - px, item.y - py
        if not item.range or dx * dx + dy * dy <= (item.range * near) ^ 2 then
            local ox, oy = rotate(dx, dy, sin, cos, k)
            local dist = math.sqrt(ox * ox + oy * oy)
            local inside = dist <= rim
            if inside or not item.range then
                if not inside then ox, oy = ox / dist * rim, oy / dist * rim end
                if item.tex then
                    dxDrawImage(mx + ox - icon / 2, my + oy - icon / 2, icon, icon, item.tex)
                else
                    MapDraw.square(mx + ox, my + oy, math.max(3, icon * 0.35 * (1 + item.size) / 3), item, (item.z or pz) - pz, false)
                end
            end
        end
    end

    -- North on the rim, then you.
    local north = MapDraw.sprite("radar_north")
    if north then
        local nx, ny = rotate(0, 1, sin, cos, r - icon * 0.1)
        dxDrawImage(mx + nx - icon / 2, my + ny - icon / 2, icon, icon, north)
    end
    local arrow = MapDraw.sprite("radar_centre")
    if arrow then
        local _, _, rz = getElementRotation(vehicle or localPlayer)
        dxDrawImage(mx - icon * 0.6, my - icon * 0.6, icon * 1.2, icon * 1.2, arrow, -rz - math.deg(heading))
    end
end)
