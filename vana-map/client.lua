-- Map points as radar blips on this client: vanilla's icons, short-range ones only nearby, and only for
-- the interior you're in (most are street doors, interior 0). Map.hidden is where per-player category
-- filters go (legend, settings); hidden categories get no blips.
Map = { points = {}, blips = {}, hidden = {} }

local function draw(id)
    local old = Map.blips[id]
    if old and isElement(old) then destroyElement(old) end
    Map.blips[id] = nil
    local p = Map.points[id]
    if not p or Map.hidden[p.category] then return end
    local c = MapCategories[p.category]
    local blip = createBlip(p.x, p.y, p.z, c.icon, 2, 255, 255, 255, 255, 0, c.short and MapShortRange or 16383)
    setElementInterior(blip, p.interior)
    Map.blips[id] = blip
end

addEvent("vana-map:points", true)
addEventHandler("vana-map:points", resourceRoot, function(changes, full)
    if full then
        for id, blip in pairs(Map.blips) do
            if isElement(blip) then destroyElement(blip) end
        end
        Map.points, Map.blips = {}, {}
    end
    for id, p in pairs(changes) do
        Map.points[id] = p or nil
        draw(id)
    end
end)

function Map.setHidden(category, hidden)
    Map.hidden[category] = hidden or nil
    for id, p in pairs(Map.points) do if p.category == category then draw(id) end end
end

-- Our icons on the radar: each category with an image of ours replaces the sprite of the vanilla icon
-- it borrows (config/categories.lua) with that image, for this client (the map draws the image itself).
Map.images = {} -- icon -> texture
local swaps = {}

local function swapIcons()
    for icon, shader in pairs(swaps) do
        if isElement(shader) then destroyElement(shader) end
        swaps[icon] = nil
    end
    for _, c in pairs(MapCategories) do
        local sprite = c.image and BlipSprites[c.icon]
        if sprite and not swaps[c.icon] then
            local texture = Map.images[c.icon] or dxCreateTexture(c.image, "argb", true, "clamp")
            local shader = texture and dxCreateShader("texreplace.fx")
            if shader then
                Map.images[c.icon] = texture
                dxSetShaderValue(shader, "gTexture", texture)
                engineApplyShaderToWorldTexture(shader, sprite)
                swaps[c.icon] = shader
            else
                outputDebugString(("[vana-map] couldn't put %s in place of %s"):format(c.image, sprite), 2)
            end
        end
    end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    triggerServerEvent("vana-map:hello", resourceRoot)
    swapIcons()
end)
-- The images live in their owners (vana-vehicles' gas station icon): try again when one starts.
addEventHandler("onClientResourceStart", root, function(res) if res ~= resource then swapIcons() end end)
