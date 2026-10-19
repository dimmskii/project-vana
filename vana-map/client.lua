-- Map points on this client: kept here for the map (F11) and the radar, both ours, which draw them
-- with their categories' icons (draw_client.lua): no MTA blips, so a category can show an image of its
-- own. Map.hidden is where per-player category filters go (legend, settings); hidden categories aren't
-- drawn.
Map = { points = {}, hidden = {} }

addEvent("vana-map:points", true)
addEventHandler("vana-map:points", resourceRoot, function(changes, full)
    if full then Map.points = {} end
    for id, p in pairs(changes) do Map.points[id] = p or nil end
end)

function Map.setHidden(category, hidden)
    Map.hidden[category] = hidden or nil
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    triggerServerEvent("vana-map:hello", resourceRoot)
end)
