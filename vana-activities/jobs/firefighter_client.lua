-- Firefighter, the player's side: watches the reported fires (once they're streamed in and burning) and
-- tells the server when one goes out. The water cannon puts them out natively.
local targets, seen, reported = nil, {}, {}

addEvent("vana-firefighter:targets", true)
addEventHandler("vana-firefighter:targets", resourceRoot, function(list)
    targets, seen, reported = list, {}, {}
end)

setTimer(function()
    if not targets then return end
    for _, t in ipairs(targets) do
        if isElement(t) and not reported[t] and isElementStreamedIn(t) then
            local burning = isElementOnFire(t)
            if burning then
                seen[t] = true
            elseif seen[t] or (getElementType(t) == "ped" and isPedDead(t)) then
                reported[t] = true
                triggerServerEvent("vana-firefighter:out", resourceRoot, t)
            end
        end
    end
end, 500, 0)
