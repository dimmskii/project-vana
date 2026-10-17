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

addEventHandler("onClientResourceStart", resourceRoot, function()
    triggerServerEvent("vana-map:hello", resourceRoot)
end)
