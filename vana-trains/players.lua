-- The players trains and platforms are made for: in dimension 0, outside interiors.
function eligiblePlayers()
    local list = {}
    for _, player in ipairs(getElementsByType("player")) do
        if getElementDimension(player) == 0 and getElementInterior(player) == 0 then list[#list + 1] = player end
    end
    return list
end

function nearestPlayer(x, y, z, players, maxDist)
    local best, bestDist = false, maxDist or math.huge
    for _, player in ipairs(players) do
        local px, py, pz = getElementPosition(player)
        local d = getDistanceBetweenPoints3D(x, y, z, px, py, pz)
        if d < bestDist then best, bestDist = player, d end
    end
    return best, bestDist
end
