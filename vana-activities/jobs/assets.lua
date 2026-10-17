-- Assets (vanilla properties that earn revenue): a cash pickup that fills up to a cap at a rate per game
-- day once the player owns it, collected by walking into it. Owned and last collection are progress.
Assets = {}
local defs = {}

function Assets.define(name, def) -- def: { pickup = { x, y, z }, perDay, cap }
    defs[name] = def
end

function Assets.grant(player, name)
    if Activity.progress(player, "asset." .. name) then return false end
    Activity.setProgress(player, "asset." .. name, true)
    Activity.setProgress(player, "asset." .. name .. ".since", getRealTime().timestamp)
    return true
end

-- A game day is 24 * 60 game minutes of getMinuteDuration() ms.
local function dayMs() return 1440 * getMinuteDuration() end

setTimer(function()
    for _, player in ipairs(getElementsByType("player")) do
        if not isPedDead(player) then
            local x, y, z = getElementPosition(player)
            for name, def in pairs(defs) do
                local p = def.pickup
                if getDistanceBetweenPoints3D(x, y, z, p[1], p[2], p[3] + 1) < 2 and Activity.progress(player, "asset." .. name) then
                    local since = Activity.progress(player, "asset." .. name .. ".since") or getRealTime().timestamp
                    local now = getRealTime().timestamp
                    local amount = math.min(def.cap, math.floor((now - since) * 1000 / dayMs() * def.perDay))
                    if amount > 0 then
                        givePlayerMoney(player, amount)
                        Activity.setProgress(player, "asset." .. name .. ".since", now)
                        triggerClientEvent(player, "vana-activities:say", resourceRoot, "$" .. amount, 2000)
                    end
                end
            end
        end
    end
end, 1000, 0)

-- Reward vehicles (vanilla car generators switched on by an achievement): parked at their spot for each
-- player who earned them (progress "car.<key>"), only they can drive them, gone when they're far away.
OwnedCars = {}
local carDefs, spawned = {}, {} -- key -> def; player -> { key -> vehicle }

function OwnedCars.define(key, def) -- def: { model, x, y, z, rz, plate }
    carDefs[key] = def
end

function OwnedCars.grant(player, key)
    if Activity.progress(player, "car." .. key) then return false end
    Activity.setProgress(player, "car." .. key, true)
    return true
end

setTimer(function()
    for _, player in ipairs(getElementsByType("player")) do
        spawned[player] = spawned[player] or {}
        local x, y = getElementPosition(player)
        for key, def in pairs(carDefs) do
            local car = spawned[player][key]
            local d = getDistanceBetweenPoints2D(x, y, def.x, def.y)
            if Activity.progress(player, "car." .. key) then
                if (not car or not isElement(car) or isVehicleBlown(car)) and d < 200 then
                    car = createVehicle(def.model, def.x, def.y, def.z + 0.5, 0, 0, def.rz or 0, def.plate)
                    setElementData(car, "vana:owner", player, false)
                    spawned[player][key] = car
                elseif car and isElement(car) and d > 400 and not getVehicleOccupant(car) then
                    destroyElement(car)
                    spawned[player][key] = nil
                end
            end
        end
    end
end, 2000, 0)

addEventHandler("onPlayerQuit", root, function()
    for _, car in pairs(spawned[source] or {}) do
        if isElement(car) and not getVehicleOccupant(car) then destroyElement(car) end
    end
    spawned[source] = nil
end)
