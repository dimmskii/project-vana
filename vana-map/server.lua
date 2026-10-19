-- The map: permanent points other resources publish (shops, schools, races ...), drawn as radar blips
-- on each client (client.lua), so per-player legends, filters and GPS can live here later. Providers call
-- setPoint / removePoint; their points go when they stop. Clients get the whole set on join and changes
-- as they happen. Point: { category | tag, x, y, z, interior (0), label }.
local points = {} -- id -> point (with .owner)
local ready = {} -- players whose client has said hello

local function send(changes)
    local to = {}
    for player in pairs(ready) do to[#to + 1] = player end
    if #to > 0 then triggerClientEvent(to, "vana-map:points", resourceRoot, changes) end
end

local function resolve(p)
    if p.category and MapCategories[p.category] then return p.category end
    if p.tag then
        for _, rule in ipairs(MapEntranceCategories) do
            if p.tag:match(rule[1]) then return rule[2] end
        end
    end
end

function setPoint(id, p)
    if type(id) ~= "string" or type(p) ~= "table" or not tonumber(p.x) then return false end
    local category = resolve(p)
    if not category then return false end
    local point = { category = category, x = p.x, y = p.y, z = p.z or 0, interior = p.interior or 0, label = p.label,
                    owner = sourceResource and getResourceName(sourceResource) or "vana-map" }
    points[id] = point
    send({ [id] = point })
    return true
end

function removePoint(id)
    if not points[id] then return false end
    points[id] = nil
    send({ [id] = false })
    return true
end

addEvent("vana-map:hello", true)
addEventHandler("vana-map:hello", resourceRoot, function()
    ready[client] = true
    triggerClientEvent(client, "vana-map:points", resourceRoot, points, true)
end)

addEventHandler("onPlayerQuit", root, function() ready[source] = nil end)

-- A provider stopping takes its points with it.
addEventHandler("onResourceStop", root, function(resource)
    local name = getResourceName(resource)
    local gone = {}
    for id, p in pairs(points) do
        if p.owner == name then points[id], gone[id] = nil, false end
    end
    if next(gone) then send(gone) end
end)

-- Providers that started first publish again when the map starts.
addEventHandler("onResourceStart", resourceRoot, function()
    triggerEvent("vana-map:ready", root)
end)

addCommandHandler("maptest", function(source)
    if getElementType(source) ~= "console" then return end
    local counts, total = {}, 0
    for _, p in pairs(points) do counts[p.category] = (counts[p.category] or 0) + 1 total = total + 1 end
    local list = {}
    for c, n in pairs(counts) do list[#list + 1] = c .. " " .. n end
    table.sort(list)
    outputServerLog(("[maptest] %d points: %s"):format(total, table.concat(list, ", ")))
    outputServerLog("[maptest] " .. (total > 0 and "PASS" or "FAIL"))
end)

-- GPS for the map (mapview_client.lua): a route from the player to the road nearest a spot on the map,
-- along the vehicle paths (vana-paths' findRoute). One request a second per player.
local lastRoute = {}
addEvent("vana-map:route", true)
addEventHandler("vana-map:route", resourceRoot, function(tx, ty)
    if type(tx) ~= "number" or type(ty) ~= "number" or math.abs(tx) > 3000 or math.abs(ty) > 3000 then return end
    local now = getTickCount()
    if lastRoute[client] and now - lastRoute[client] < 1000 then return end
    lastRoute[client] = now
    local paths = getResourceFromName("vana-paths")
    if not paths or getResourceState(paths) ~= "running" then return triggerClientEvent(client, "vana-map:route", resourceRoot, false) end
    local x, y, z = getElementPosition(client)
    local ok, route, length = pcall(function() return exports["vana-paths"]:findRoute(x, y, z, tx, ty) end)
    triggerClientEvent(client, "vana-map:route", resourceRoot, ok and route or false, ok and route and length or nil)
end)
addEventHandler("onPlayerQuit", root, function() lastRoute[source] = nil end)
