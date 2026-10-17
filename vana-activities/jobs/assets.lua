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
