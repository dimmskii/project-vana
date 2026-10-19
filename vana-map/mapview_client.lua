-- The map (F11): ours in place of MTA's, which is switched off (its radar_* commands are MTA "mod
-- commands": disabled, they reach script handlers instead, so the player's own binds open and drive ours).
-- Full screen and opaque: GTA's radar tiles (data/radar, copied at setup), every blip in this dimension
-- and interior, radar areas, the GPS route, you, and a legend on the right.
--   radar (F11)                     open / close (Escape closes too)
--   radar_move_* (numpad 8/2/4/6)   pan while held, the cursor back in the middle of the screen
--   radar_zoom_in/out (numpad +/-)  zoom on the cursor while held;  the mouse wheel zooms there too
--   radar_attach (numpad 0)         follow yourself
--   radar_help (numpad 1)           the help line
--   mouse                           moving it takes the cursor off the middle; left drag pans
--   right click / Space             GPS to the road nearest the cursor (again on the destination: off)
MapView = {}
local WORLD, TILES, TILE = 6000, 12, 500 -- the map's 6000 m, as 12 x 12 radar tiles of 500 m
local ZOOM_STEP, MAX_PPM = 1.25, 1.2     -- per wheel notch or key repeat; the most pixels per metre
local PAN_PX = 900                        -- pixels a second the move keys pan at
local COLOURS = { back = tocolor(18, 24, 34), panel = tocolor(12, 12, 14), title = tocolor(172, 203, 241),
                  text = tocolor(225, 225, 225), dim = tocolor(150, 150, 150), route = tocolor(220, 60, 200, 230) }
local COMMANDS = { "radar", "radar_zoom_in", "radar_zoom_out", "radar_move_north", "radar_move_south",
                   "radar_move_east", "radar_move_west", "radar_attach", "radar_help" }

local open, tiles, sprites
local view = { x = 0, y = 0, ppm = 0.1 } -- world centre, pixels per metre
local cursor = { free = false, x = 0, y = 0 }
local drag, following, showHelp = nil, false, true
local route, destination, destinationBlip
local lastTick

local function screen() return guiGetScreenSize() end
local function sx(v) return v * select(2, guiGetScreenSize()) / 720 end

local function toScreen(wx, wy)
    local w, h = screen()
    return w / 2 + (wx - view.x) * view.ppm, h / 2 - (wy - view.y) * view.ppm
end

local function toWorld(px, py)
    local w, h = screen()
    return view.x + (px - w / 2) / view.ppm, view.y - (py - h / 2) / view.ppm
end

local function minPpm() return select(2, screen()) / WORLD * 0.85 end

local function clampView()
    view.ppm = math.max(minPpm(), math.min(MAX_PPM, view.ppm))
    view.x = math.max(-WORLD / 2, math.min(WORLD / 2, view.x))
    view.y = math.max(-WORLD / 2, math.min(WORLD / 2, view.y))
end

local function cursorPos()
    if cursor.free then return cursor.x, cursor.y end
    local w, h = screen()
    return w / 2, h / 2
end

-- Zoom by `factor` keeping the world point under the cursor where it is.
local function zoomAt(factor)
    local px, py = cursorPos()
    local wx, wy = toWorld(px, py)
    view.ppm = math.max(minPpm(), math.min(MAX_PPM, view.ppm * factor))
    local w, h = screen()
    view.x, view.y = wx - (px - w / 2) / view.ppm, wy + (py - h / 2) / view.ppm
    clampView()
end

-- The keys take the cursor back to the middle, the view moving so it stays over the same spot.
local function recentre()
    if cursor.free then
        view.x, view.y = toWorld(cursor.x, cursor.y)
        cursor.free = false
        clampView()
        local w, h = screen()
        setCursorPosition(w / 2, h / 2)
    end
    following = false
end

local function loadImages()
    if tiles then return end
    tiles, sprites = {}, SATxd.load("data/hud.txd") or {}
    for i = 0, TILES * TILES - 1 do
        local name = ("radar%02d"):format(i)
        local t = SATxd.load("data/radar/" .. name .. ".txd")
        tiles[i] = t and t[name] or false
    end
end

local function setOpen(on)
    if on == (open == true) then return end
    open = on
    if on then
        loadImages()
        local px, py = getElementPosition(localPlayer)
        view.x, view.y, view.ppm = px, py, minPpm() * 2
        clampView()
        cursor.free, drag, following = false, nil, false
        showCursor(true, false)
        setCursorAlpha(0)
        local w, h = screen()
        setCursorPosition(w / 2, h / 2)
        toggleAllControls(false, true, false)
    else
        drag = nil
        setCursorAlpha(255)
        showCursor(false)
        toggleAllControls(true, true, false)
    end
end
function MapView.isOpen() return open == true end

-- GPS: the server routes to the road nearest the spot (vana-paths); the destination gets a waypoint
-- blip of this player's own, so the radar points there too.
local function clearRoute()
    route, destination = nil, nil
    if isElement(destinationBlip) then destroyElement(destinationBlip) end
    destinationBlip = nil
end

local function routeTo(wx, wy)
    if destination then
        local dx, dy = toScreen(destination[1], destination[2])
        local px, py = toScreen(wx, wy)
        if (dx - px) ^ 2 + (dy - py) ^ 2 < sx(12) ^ 2 then return clearRoute() end
    end
    triggerServerEvent("vana-map:route", resourceRoot, wx, wy)
end

addEvent("vana-map:route", true)
addEventHandler("vana-map:route", resourceRoot, function(points, length)
    if not points then
        return exports["vana-controls"]:status("There's no road there to plan a route to.")
    end
    clearRoute()
    route = points
    destination = { points[#points - 1], points[#points] }
    destinationBlip = createBlip(destination[1], destination[2], 0, 41, 2, 255, 255, 255, 255, 1, 16383)
    exports["vana-controls"]:status(("Route set: %.1f km"):format(length / 1000))
end)

-- Arrived (within 30 m of the destination): the route goes.
setTimer(function()
    if not destination then return end
    local x, y = getElementPosition(localPlayer)
    if getDistanceBetweenPoints2D(x, y, destination[1], destination[2]) < 30 then
        clearRoute()
        exports["vana-controls"]:status("You have arrived.")
    end
end, 1000, 0)

-- Commands: ours while MTA's are off.
local held = {} -- command -> true while its bound key is down (checked each frame)
local function boundDown(command)
    for key in pairs(getBoundKeys(command) or {}) do
        if getKeyState(key) then return true end
    end
    return false
end

local handlers = {
    radar = function() setOpen(not open) end,
    radar_zoom_in = function() if open then zoomAt(ZOOM_STEP) end end,
    radar_zoom_out = function() if open then zoomAt(1 / ZOOM_STEP) end end,
    radar_attach = function() if open then following = not following end end,
    radar_help = function() if open then showHelp = not showHelp end end,
}
for _, dir in ipairs({ "north", "south", "east", "west" }) do
    handlers["radar_move_" .. dir] = function() if open then recentre() end end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    for _, command in ipairs(COMMANDS) do
        toggleControl(command, false)
        addCommandHandler(command, handlers[command])
    end
end)
addEventHandler("onClientResourceStop", resourceRoot, function()
    if open then setOpen(false) end
    for _, command in ipairs(COMMANDS) do toggleControl(command, true) end
end)

addEventHandler("onClientPlayerWasted", localPlayer, function() setOpen(false) end)

addEventHandler("onClientKey", root, function(key, pressed)
    if not open or not pressed then return end
    if key == "escape" then
        setOpen(false)
    elseif key == "mouse_wheel_up" then
        zoomAt(ZOOM_STEP)
    elseif key == "mouse_wheel_down" then
        zoomAt(1 / ZOOM_STEP)
    elseif key == "space" then
        routeTo(toWorld(cursorPos()))
    else
        return
    end
    cancelEvent()
end)

addEventHandler("onClientCursorMove", root, function(_, _, ax, ay)
    if not open then return end
    local w, h = screen()
    if not cursor.free and (math.abs(ax - w / 2) > 2 or math.abs(ay - h / 2) > 2) then cursor.free = true end
    if cursor.free then cursor.x, cursor.y = ax, ay end
    if drag then
        view.x, view.y = drag.wx - (ax - w / 2) / view.ppm, drag.wy + (ay - h / 2) / view.ppm
        clampView()
    end
end)

addEventHandler("onClientClick", root, function(button, state, ax, ay)
    if not open then return end
    if button == "left" then
        if state == "down" then
            -- The spot grabbed stays under the hand while dragging (onClientCursorMove).
            local wx, wy = toWorld(ax, ay)
            drag = { wx = wx, wy = wy }
            following = false
        else
            drag = nil
        end
    elseif button == "right" and state == "up" then
        routeTo(toWorld(ax, ay))
    end
end)

-- Drawing ------------------------------------------------------------------------------------------
local function blipSprite(icon)
    return Map.images[icon] or (sprites and BlipSprites[icon] and sprites[BlipSprites[icon]])
end

-- Who is in the legend: the categories with points, and anything else shown with a sprite.
local function legendEntries()
    local seen, list = {}, {}
    for _, p in pairs(Map.points) do
        local c = MapCategories[p.category]
        if c and not seen[c.name] then
            seen[c.name] = true
            list[#list + 1] = { icon = c.icon, name = c.name }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    table.insert(list, 1, { player = true, name = "You" })
    if destination then table.insert(list, 2, { icon = 41, name = "Destination" }) end
    return list
end

local function drawBlips(icon, dim, int)
    local all = {}
    for _, blip in ipairs(getElementsByType("blip")) do
        if getElementDimension(blip) == dim and getElementInterior(blip) == int then all[#all + 1] = blip end
    end
    table.sort(all, function(a, b) return getBlipOrdering(a) < getBlipOrdering(b) end)
    local w, h = screen()
    local hover
    local cx, cy = cursorPos()
    for _, blip in ipairs(all) do
        local bx, by = getElementPosition(blip)
        local px, py = toScreen(bx, by)
        if px > -icon and px < w + icon and py > -icon and py < h + icon then
            local id = getBlipIcon(blip)
            local sprite = id > 1 and id ~= 3 and blipSprite(id)
            if sprite then
                dxDrawImage(px - icon / 2, py - icon / 2, icon, icon, sprite, 0, 0, 0, tocolor(255, 255, 255), true)
            else
                local r, g, b, a = getBlipColor(blip)
                local size = sx(2 + getBlipSize(blip))
                dxDrawRectangle(px - size / 2 - 1, py - size / 2 - 1, size + 2, size + 2, tocolor(0, 0, 0, a), true)
                dxDrawRectangle(px - size / 2, py - size / 2, size, size, tocolor(r, g, b, a), true)
            end
            if (px - cx) ^ 2 + (py - cy) ^ 2 < (icon / 2) ^ 2 then hover = blip end
        end
    end
    return hover
end

local function hoverLabel(blip)
    for id, b in pairs(Map.blips) do
        if b == blip then
            local p = Map.points[id]
            return p and (p.label or (MapCategories[p.category] and MapCategories[p.category].name))
        end
    end
    if blip == destinationBlip then return "Destination" end
end

addEventHandler("onClientRender", root, function()
    if not open then return end
    local now = getTickCount()
    local dt = math.min(0.1, (now - (lastTick or now)) / 1000)
    lastTick = now
    -- Held keys: pan and zoom.
    local pan = PAN_PX * dt / view.ppm
    local moved = false
    if boundDown("radar_move_north") then view.y, moved = view.y + pan, true end
    if boundDown("radar_move_south") then view.y, moved = view.y - pan, true end
    if boundDown("radar_move_east") then view.x, moved = view.x + pan, true end
    if boundDown("radar_move_west") then view.x, moved = view.x - pan, true end
    if moved then recentre() end
    if boundDown("radar_zoom_in") then held.zoom = (held.zoom or 0) + dt else held.zoom = nil end
    if boundDown("radar_zoom_out") then held.unzoom = (held.unzoom or 0) + dt else held.unzoom = nil end
    if held.zoom and held.zoom > 0.25 then zoomAt(1 + 1.5 * dt) end
    if held.unzoom and held.unzoom > 0.25 then zoomAt(1 / (1 + 1.5 * dt)) end
    local px, py = getElementPosition(localPlayer)
    if following then view.x, view.y = px, py end
    clampView()

    local w, h = screen()
    dxDrawRectangle(0, 0, w, h, COLOURS.back, true)
    -- Tiles.
    local size = TILE * view.ppm
    for row = 0, TILES - 1 do
        for col = 0, TILES - 1 do
            local x, y = toScreen(-WORLD / 2 + col * TILE, WORLD / 2 - row * TILE)
            if x + size > 0 and x < w and y + size > 0 and y < h then
                local tex = tiles[row * TILES + col]
                if tex then dxDrawImage(x, y, size + 1, size + 1, tex, 0, 0, 0, tocolor(255, 255, 255), true) end
            end
        end
    end
    -- Radar areas.
    for _, area in ipairs(getElementsByType("radararea")) do
        local ax, ay = getElementPosition(area)
        local aw, ah = getRadarAreaSize(area)
        local r, g, b, a = getRadarAreaColor(area)
        local x1, y1 = toScreen(math.min(ax, ax + aw), math.max(ay, ay + ah))
        local x2, y2 = toScreen(math.max(ax, ax + aw), math.min(ay, ay + ah))
        dxDrawRectangle(x1, y1, x2 - x1, y2 - y1, tocolor(r, g, b, a), true)
    end
    -- The route.
    if route then
        local lx, ly = toScreen(route[1], route[2])
        for i = 3, #route - 1, 2 do
            local x, y = toScreen(route[i], route[i + 1])
            dxDrawLine(lx, ly, x, y, COLOURS.route, sx(3), true)
            lx, ly = x, y
        end
    end
    -- Blips (smaller than MTA's), then you.
    local icon = sx(11)
    local hover = drawBlips(icon, getElementDimension(localPlayer), getElementInterior(localPlayer))
    local mx, my = toScreen(px, py)
    local _, _, rz = getElementRotation(localPlayer)
    if sprites and sprites.radar_centre then
        dxDrawImage(mx - icon * 0.7, my - icon * 0.7, icon * 1.4, icon * 1.4, sprites.radar_centre, -rz, 0, 0, tocolor(255, 255, 255), true)
    end
    -- North, top left of the map.
    if sprites and sprites.radar_north then
        local nx, ny = toScreen(-WORLD / 2, WORLD / 2)
        dxDrawImage(math.max(sx(16), nx + sx(8)), math.max(sx(16), ny + sx(8)), icon * 1.4, icon * 1.4, sprites.radar_north, 0, 0, 0, tocolor(255, 255, 255), true)
    end

    -- The legend, on the right.
    local lw = sx(170)
    local lx = w - lw - sx(16)
    local entries = legendEntries()
    local row = sx(17)
    local lh = row * (#entries + 1.8)
    local ly = sx(16)
    dxDrawRectangle(lx, ly, lw, lh, COLOURS.panel, true)
    dxDrawText("Legend", lx + sx(10), ly + sx(4), lx + lw, ly + row * 1.3, COLOURS.title, sx(0.9), "bankgothic", "left", "center", false, false, true)
    for i, e in ipairs(entries) do
        local ey = ly + row * (i + 0.5)
        local tex = e.player and sprites and sprites.radar_centre or (e.icon and blipSprite(e.icon))
        if tex then dxDrawImage(lx + sx(10), ey + (row - icon) / 2, icon, icon, tex, 0, 0, 0, tocolor(255, 255, 255), true) end
        dxDrawText(e.name, lx + sx(10) + icon + sx(8), ey, lx + lw - sx(6), ey + row, COLOURS.text, sx(0.85), "default-bold", "left", "center", true, false, true)
    end

    -- The cursor: a crosshair, and what's under it.
    local cx, cy = cursorPos()
    local arm = sx(9)
    dxDrawLine(cx - arm, cy, cx + arm, cy, tocolor(255, 255, 255, 230), sx(1.5), true)
    dxDrawLine(cx, cy - arm, cx, cy + arm, tocolor(255, 255, 255, 230), sx(1.5), true)
    local label = hover and hoverLabel(hover)
    if label then
        dxDrawText(label, cx + sx(13) + 1, cy - sx(18) + 1, cx + sx(400), cy, tocolor(0, 0, 0, 220), sx(0.95), "default-bold", "left", "bottom", false, false, true)
        dxDrawText(label, cx + sx(13), cy - sx(18), cx + sx(400), cy, COLOURS.text, sx(0.95), "default-bold", "left", "bottom", false, false, true)
    end
    -- Where the cursor is, and the help line.
    local wx, wy = toWorld(cx, cy)
    local zone = getZoneName(wx, wy, 0)
    dxDrawText(zone .. (following and "   (following you)" or ""), sx(16), h - sx(44), w, h - sx(26), COLOURS.text, sx(1), "default-bold", "left", "center", false, false, true)
    if showHelp then
        local function key(command) local k = next(getBoundKeys(command) or {}) return k and k:upper() or "?" end
        dxDrawText(("Mouse: drag to move, wheel to zoom   Right click / Space: route there   %s/%s/%s/%s: move   %s/%s: zoom   %s: follow you   %s: hide this")
            :format(key("radar_move_north"), key("radar_move_west"), key("radar_move_south"), key("radar_move_east"),
                key("radar_zoom_in"), key("radar_zoom_out"), key("radar_attach"), key("radar_help")),
            sx(16), h - sx(24), w, h - sx(8), COLOURS.dim, sx(0.85), "default", "left", "center", false, false, true)
    end
end)
