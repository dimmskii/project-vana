-- Players' script errors and warnings, sent to the server log (server.lua): client errors otherwise
-- only show in that player's own debug view, so nobody running the server sees them.
local sent, windowStart = 0, 0
local last = {} -- message -> tick it was last sent

addEventHandler("onClientDebugMessage", root, function(message, level, file, line)
    if level ~= 1 and level ~= 2 then return end
    local now = getTickCount()
    if now - windowStart > 10000 then sent, windowStart = 0, now end
    local text = ("%s%s: %s"):format(file or "?", line and (":" .. line) or "", message)
    if sent >= 20 or (last[text] and now - last[text] < 5000) then return end
    sent, last[text] = sent + 1, now
    triggerServerEvent("vana-core:clientError", resourceRoot, level == 1 and "ERROR" or "WARNING", text:sub(1, 300))
end)

-- Debug (topic vana-core:stuck, docs/debug.md): every 2 s, peds near the player that haven't moved
-- 0.3 m in 6 s, or hang in the air without falling, are reported once each (until they move again):
-- who simulates them, frozen, ground, task, animation. The server adds what their owner last told them.
local CHECK_MS, STILL_MS, RANGE = 2000, 6000, 80
local watched = {} -- ped -> { x, y, z, since, reported }

local function describe(ped)
    local x, y, z = getElementPosition(ped)
    local vx, vy, vz = getElementVelocity(ped)
    local ground = getGroundPosition(x, y, z + 1)
    local block, anim = getPedAnimation(ped)
    local tags = {}
    for _, key in ipairs({ "vana:ambient", "vana:service", "vana:keeper" }) do
        local v = getElementData(ped, key)
        if v then tags[#tags + 1] = key:sub(6) .. "=" .. tostring(v) end
    end
    return ("mine %s, frozen %s, on ground %s, ground %s, speed %.2f, task %s / %s, anim %s, health %d%s"):format(
        tostring(isElementSyncer(ped)), tostring(isElementFrozen(ped)), tostring(isPedOnGround(ped)),
        ground and ground ~= 0 and ("%.1f below"):format(z - ground) or "not loaded",
        math.sqrt(vx * vx + vy * vy + vz * vz) * 50,
        tostring(getPedTask(ped, "primary", 3)), tostring(getPedSimplestTask(ped)),
        block and (block .. "/" .. tostring(anim)) or "none", getElementHealth(ped),
        #tags > 0 and (", " .. table.concat(tags, " ")) or "")
end

setTimer(function()
    if not Debug.on("stuck") then
        watched = {}
        return
    end
    local now = getTickCount()
    local px, py, pz = getElementPosition(localPlayer)
    local seen = {}
    for _, ped in ipairs(getElementsByType("ped", root, true)) do
        if not isPedDead(ped) and not getPedOccupiedVehicle(ped) then
            local x, y, z = getElementPosition(ped)
            if getDistanceBetweenPoints3D(x, y, z, px, py, pz) < RANGE then
                seen[ped] = true
                local w = watched[ped]
                if not w or getDistanceBetweenPoints3D(x, y, z, w.x, w.y, w.z) > 0.3 then
                    watched[ped] = { x = x, y = y, z = z, since = now }
                else
                    local _, _, vz = getElementVelocity(ped)
                    local hanging = not isPedOnGround(ped) and math.abs(vz) < 0.01
                    if not w.reported and (now - w.since >= STILL_MS or (hanging and now - w.since >= CHECK_MS)) then
                        w.reported = true
                        triggerServerEvent("vana-core:stuck", resourceRoot, ped, (hanging and "HANGING, " or "still, ") .. describe(ped))
                    end
                end
            end
        end
    end
    for ped in pairs(watched) do if not seen[ped] then watched[ped] = nil end end
end, CHECK_MS, 0)
