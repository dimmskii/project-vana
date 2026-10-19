-- Copy this file into a resource that publishes map points (vana-map). MapPoints.set(id, point) and
-- MapPoints.remove(id) work whether or not vana-map is running: points are kept here and published
-- whenever vana-map (re)starts. Keep the copies identical to this one.
MapPoints = {}
local mine = {}

local function publish(id, point)
    local map = getResourceFromName("vana-map")
    if not map or getResourceState(map) ~= "running" then return end
    pcall(function() exports["vana-map"]:setPoint(id, point) end)
end

function MapPoints.set(id, point)
    mine[id] = point
    publish(id, point)
end

function MapPoints.remove(id)
    mine[id] = nil
    local map = getResourceFromName("vana-map")
    if map and getResourceState(map) == "running" then pcall(function() exports["vana-map"]:removePoint(id) end) end
end

addEvent("vana-map:ready")
addEventHandler("vana-map:ready", root, function()
    for id, point in pairs(mine) do publish(id, point) end
end)
