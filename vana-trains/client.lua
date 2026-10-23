-- Runs the server's orders for the people at the stations with native tasks, once this client syncs
-- them: getting on a train (to a given seat) and off it. Reports one of them hurt by a player.
local function owns(element)
    return isElement(element) and isElementStreamedIn(element) and isElementSyncer(element)
end

-- Orders that arrive before ownership or streaming are tried again for a while.
local function retry(fn)
    local started = getTickCount()
    local function attempt()
        if fn() or getTickCount() - started > 8000 then return end
        setTimer(attempt, 250, 1)
    end
    attempt()
end

addEvent("vana-trains:board", true)
addEventHandler("vana-trains:board", resourceRoot, function(ped, car, seat)
    retry(function()
        if not owns(ped) or not isElement(car) or not isElementStreamedIn(car) then return false end
        if getPedOccupiedVehicle(ped) then return true end
        return setPedEnterVehicle(ped, car, seat)
    end)
end)

addEvent("vana-trains:alight", true)
addEventHandler("vana-trains:alight", resourceRoot, function(peds)
    for _, ped in ipairs(peds) do
        retry(function()
            if not owns(ped) then return false end
            if getPedOccupiedVehicle(ped) then setPedExitVehicle(ped) end
            return true
        end)
    end
end)

addEvent("vana-trains:stop", true)
addEventHandler("vana-trains:stop", resourceRoot, function(ped)
    if owns(ped) and not getPedOccupiedVehicle(ped) then killPedTask(ped, "primary", 3, false) end
end)

local reported = {}
addEventHandler("onClientPedDamage", root, function(attacker)
    local role = getElementData(source, "vana:train")
    if (role ~= "waiting" and role ~= "rider") or not isElementSyncer(source) then return end
    if not isElement(attacker) then return end
    if getElementType(attacker) == "vehicle" then attacker = getVehicleController(attacker) end
    if not isElement(attacker) or getElementType(attacker) ~= "player" then return end
    local now = getTickCount()
    if reported[source] and now - reported[source] < 1000 then return end
    reported[source] = now
    triggerServerEvent("vana-trains:hurt", resourceRoot, source, attacker)
end)
