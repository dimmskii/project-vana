-- What the map (F11, mapview_client.lua) and the radar (radar_client.lua) draw: GTA's radar tiles and blip
-- sprites (data/, copied at setup), our categories' own images, the player's preferences for them, and
-- the list of things on the map: vana-map's points (client.lua: no MTA blips of their own) and every MTA
-- blip other scripts make.
MapDraw = { WORLD = 6000, TILES = 12, TILE = 500 }
local tiles, sprites
local images, imageTried = {}, {} -- category -> texture; when it was last tried (owners start later)

function MapDraw.load()
    if tiles then return end
    tiles, sprites = {}, SATxd.load("data/hud.txd") or {}
    for i = 0, MapDraw.TILES * MapDraw.TILES - 1 do
        local name = ("radar%02d"):format(i)
        local t = SATxd.load("data/radar/" .. name .. ".txd")
        tiles[i] = t and t[name] or false
    end
end

-- The tile at (row, col), row 0 the north edge, col 0 the west.
function MapDraw.tile(row, col) return tiles and tiles[row * MapDraw.TILES + col] or nil end
function MapDraw.sprite(name) return sprites and sprites[name] end
function MapDraw.icon(id) return sprites and BlipSprites[id] and sprites[BlipSprites[id]] end

-- A category's icon: its own image (an owner's file, e.g. vana-vehicles' gas station), else vanilla's.
function MapDraw.categoryImage(category)
    local c = MapCategories[category]
    if not c then return end
    if c.image then
        if images[category] == nil and getTickCount() - (imageTried[category] or -10000) > 5000 then
            imageTried[category] = getTickCount()
            images[category] = dxCreateTexture(c.image, "argb", true, "clamp") or nil
        end
        if images[category] then return images[category] end
    end
    return c.icon and MapDraw.icon(c.icon)
end

-- The player's preferences (vana-controls), kept up to date.
local prefs = {}
local function readPreferences()
    local res = getResourceFromName("vana-controls")
    if not res or getResourceState(res) ~= "running" then return end
    for _, key in ipairs({ "map.blipSize", "minimap.rotation", "minimap.blipSize", "minimap.blipRange" }) do
        prefs[key] = exports["vana-controls"]:getPreference(key)
    end
end
function MapDraw.pref(key, default)
    local v = prefs[key]
    if v == nil then return default end
    return v
end
addEvent("onClientPreferenceChange", false)
addEventHandler("onClientPreferenceChange", root, function(key, value) prefs[key] = value end)
addEventHandler("onClientResourceStart", root, function(res)
    if res == resource or getResourceName(res) == "vana-controls" then readPreferences() end
end)

-- Everything to draw in this dimension and interior, lowest ordering first:
-- { x, y, z, tex (nil: a square of colour, size), range (nil: anywhere), label, blip }
function MapDraw.items(dim, int)
    local out = {}
    if dim == 0 then
        for _, p in pairs(Map.points) do
            local c = MapCategories[p.category]
            if c and not Map.hidden[p.category] and (p.interior or 0) == int then
                out[#out + 1] = { x = p.x, y = p.y, z = p.z, tex = MapDraw.categoryImage(p.category), order = 0,
                                  range = c.short and MapShortRange or nil, label = p.label or c.name }
            end
        end
    end
    for _, blip in ipairs(getElementsByType("blip")) do
        if getElementDimension(blip) == dim and getElementInterior(blip) == int then
            local x, y, z = getElementPosition(blip)
            local id = getBlipIcon(blip)
            local item = { x = x, y = y, z = z, order = getBlipOrdering(blip), blip = blip,
                           tex = id > 1 and id ~= 3 and MapDraw.icon(id) or nil }
            local range = getBlipVisibleDistance(blip)
            if range < 16000 then item.range = range end
            if not item.tex then
                local r, g, b, a = getBlipColor(blip)
                item.colour, item.alpha, item.size = tocolor(r, g, b, a), a, getBlipSize(blip)
            end
            out[#out + 1] = item
        end
    end
    table.sort(out, function(a, b) return a.order < b.order end)
    return out
end

-- A square blip (icon 0/1): its colour with a dark edge; a triangle for one well above or below you.
function MapDraw.square(px, py, size, item, dz, postGUI)
    if dz and math.abs(dz) > 4 then
        local up = dz > 0
        local h = size * 1.3
        local edge = tocolor(0, 0, 0, item.alpha or 255)
        local function tri(scale, colour)
            local w2, h2 = size * scale * 0.75, h * scale / 2
            local tip, base = up and py - h2 or py + h2, up and py + h2 or py - h2
            dxDrawPrimitive("trianglelist", postGUI, { px, tip, colour }, { px - w2, base, colour }, { px + w2, base, colour })
        end
        tri(1.35, edge)
        tri(1, item.colour)
        return
    end
    dxDrawRectangle(px - size / 2 - 1, py - size / 2 - 1, size + 2, size + 2, tocolor(0, 0, 0, item.alpha or 255), postGUI)
    dxDrawRectangle(px - size / 2, py - size / 2, size, size, item.colour, postGUI)
end
