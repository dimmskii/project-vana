-- Arriving through an entrance: an interior's floor streams in only once you're in it, so the server
-- holds the player frozen (faded out) until we find the floor under the exit point, or give up.
addEvent("vana-interiors:arrived", true)
addEventHandler("vana-interiors:arrived", resourceRoot, function(token, x, y, z)
    local started = getTickCount()
    local timer
    timer = setTimer(function()
        local floor = processLineOfSight(x, y, z + 1.5, x, y, z - 2.5, true, false, false, true, false)
        if floor or getTickCount() - started > 4000 then
            killTimer(timer)
            triggerServerEvent("vana-interiors:ready", resourceRoot, token)
        end
    end, 100, 0)
end)
