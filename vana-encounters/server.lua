-- Encounters: each `encounter` element ([data]/vana-data-encounters) is one single instance of its
-- kind (config/encounters.lua) at its place. Every game day it appears at startHour and is cleaned up
-- at endHour; killed, it stays dead until the next startHour. Damage players do to it is kept, and
-- its reward is shared by it when it dies. While it's out it has a map icon (its blip category).
-- Each instance is tracked by its element id, so there's never a second one of it, in a fight or not.
local R = EncounterRules
local states = {} -- encounter id -> { e, ped, killed, attacker, damage = { player -> loss }, bodyAt, blipAt, lastHour }

-- An element's value, else its kind's.
local function value(e, key)
    if e[key] ~= nil then return e[key] end
    local kind = EncounterKinds[e.kind]
    return kind and kind[key]
end

local function nameOf(e) return value(e, "name") or e.kind end

local function blipOf(e)
    local blip = value(e, "blip")
    return blip ~= "none" and blip or nil
end

local function nearestPlayer(x, y, z)
    local best, who = math.huge, nil
    for _, player in ipairs(getElementsByType("player")) do
        if getElementInterior(player) == 0 and getElementDimension(player) == 0 and not isPedDead(player) then
            local px, py, pz = getElementPosition(player)
            local d = getDistanceBetweenPoints3D(x, y, z, px, py, pz)
            if d < best then best, who = d, player end
        end
    end
    return best, who
end

local function debugLog(text) if Debug.on("encounters") then Debug.log("encounters", text) end end

-- Scripts: what each kind does. "creature": stands (its idle animation) or walks to the element's
-- target, and goes for whoever hurts it until they're dead, gone or far.
EncounterScripts = {}
EncounterScripts.creature = {
    idle = function(st, owner)
        local e = st.e
        if e.ex then
            triggerClientEvent(owner, "vana-encounters:walk", resourceRoot, st.ped, e.ex, e.ey, e.ez)
        elseif e.anim then
            local block, anim = e.anim:match("^([^/]+)/(.+)$")
            if block then setPedAnimation(st.ped, block, anim, -1, true, false, false, true) end
        end
    end,
    attack = function(st, target)
        setPedAnimation(st.ped)
        triggerClientEvent(target, "vana-encounters:attack", resourceRoot, st.ped, target)
    end,
}

local function scriptOf(st) return EncounterScripts[value(st.e, "script") or "creature"] or EncounterScripts.creature end

local function removePed(st)
    MapPoints.remove("encounter:" .. st.e.id)
    if isElement(st.ped) then destroyElement(st.ped) end
    st.ped, st.attacker, st.bodyAt, st.damage = nil, nil, nil, {}
end

-- Simulated by the nearest player (the one it's going for, during a fight), told what to do again.
local function setOwner(st, player)
    if not isElement(player) or getElementSyncer(st.ped) == player then return end
    setElementSyncer(st.ped, player, true, true)
    if st.attacker then scriptOf(st).attack(st, st.attacker) else scriptOf(st).idle(st, player) end
end

local function spawn(st)
    local e = st.e
    if isElement(st.ped) then return end -- one of it, ever
    local ped = createPed(value(e, "model") or 7, e.x, e.y, e.z + 1, e.heading or 0)
    if not ped then return end
    st.ped, st.damage, st.attacker, st.bodyAt = ped, {}, nil, nil
    setElementData(ped, "vana:encounter", e.id)
    setElementData(ped, "vana:creature", e.kind)
    setElementData(ped, "vana:creatureHealth", value(e, "health") or 100)
    setElementData(ped, "vana:fairGame", true) -- no crime for it, no ambulance
    if value(e, "fightingStyle") then setPedFightingStyle(ped, value(e, "fightingStyle")) end
    if value(e, "walkingStyle") then setPedWalkingStyle(ped, value(e, "walkingStyle")) end
    if e.weapon then giveWeapon(ped, e.weapon, 9999, true) end
    local _, owner = nearestPlayer(e.x, e.y, e.z)
    if owner then setOwner(st, owner) elseif e.anim and not e.ex then scriptOf(st).idle(st) end
    debugLog(("%s (%s) appeared at %.0f, %.0f, %.0f"):format(nameOf(e), e.id, e.x, e.y, e.z))
end

-- Its reward, shared by the damage each player did (of all the damage players did).
local function payOut(st)
    local e = st.e
    local reward, total = value(e, "reward") or 0, 0
    for _, loss in pairs(st.damage) do total = total + loss end
    if reward <= 0 or total <= 0 then return end
    for player, loss in pairs(st.damage) do
        if isElement(player) then
            local amount = math.floor(reward * loss / total)
            if amount > 0 then
                givePlayerMoney(player, amount)
                outputChatBox(("%s is down. Your share: $%d (%d%% of the damage)."):format(nameOf(e), amount, math.floor(loss / total * 100 + 0.5)),
                    player, 120, 255, 120)
            end
        end
    end
end

local function think(st, hour, now)
    local e = st.e
    -- A new day starts at startHour: what was out is cleaned up (the same hour ends the last day),
    -- and a kill no longer holds it back.
    if st.lastHour and st.lastHour ~= hour and hour == e.startHour then
        if st.ped then removePed(st) end
        st.killed = false
    end
    st.lastHour = hour
    local open = encounterOpen(e, hour)
    if not open then
        if st.ped then
            debugLog(("%s (%s) cleaned up at %02d:00"):format(nameOf(e), e.id, hour))
            removePed(st)
        end
        return
    end
    if not isElement(st.ped) then
        st.ped = nil
        if not st.killed then spawn(st) end
        return
    end
    local ped = st.ped
    if isPedDead(ped) then
        st.bodyAt = st.bodyAt or now
        if now - st.bodyAt > R.bodyMs then removePed(st) end
        return
    end
    local x, y, z = getElementPosition(ped)
    if now >= (st.blipAt or 0) then
        st.blipAt = now + R.blipMs
        local blip = blipOf(e)
        if blip then MapPoints.set("encounter:" .. e.id, { category = blip, x = x, y = y, z = z, label = nameOf(e) }) end
    end
    -- The one it's going for: dead, gone or far, and it goes back to what it was doing.
    local a = st.attacker
    if a and (not isElement(a) or isPedDead(a) or getElementDimension(a) ~= 0
        or getDistanceBetweenPoints3D(x, y, z, getElementPosition(a)) > R.chaseGiveUp) then
        debugLog(("%s (%s) gives up the chase"):format(nameOf(e), e.id))
        st.attacker = nil
        local _, owner = nearestPlayer(x, y, z)
        if owner then setElementSyncer(ped, owner, true, true); scriptOf(st).idle(st, owner) end
        return
    end
    if not st.attacker then
        local d, owner = nearestPlayer(x, y, z)
        if owner and d < 250 then setOwner(st, owner) end
    end
end

-- Damage a player did to it (reported by them, in its own health units): kept for the reward; it
-- goes for them.
addEvent("vana-encounters:hurt", true)
addEventHandler("vana-encounters:hurt", resourceRoot, function(ped, loss)
    local st = isElement(ped) and states[getElementData(ped, "vana:encounter")]
    if not st or st.ped ~= ped or isPedDead(ped) then return end
    loss = math.max(0, math.min(tonumber(loss) or 0, R.maxHitLoss))
    st.damage[client] = (st.damage[client] or 0) + loss
    if st.attacker ~= client and not (isElement(st.attacker) and not isPedDead(st.attacker)) then
        debugLog(("%s (%s) goes for %s"):format(nameOf(st.e), st.e.id, getPlayerName(client)))
        st.attacker = client
        setElementSyncer(ped, client, true, true)
        scriptOf(st).attack(st, client)
    end
end)

-- Killed where it's simulated (its toughness is applied there): only its syncer says so.
addEvent("vana-encounters:killed", true)
addEventHandler("vana-encounters:killed", resourceRoot, function(ped, attacker)
    local st = isElement(ped) and states[getElementData(ped, "vana:encounter")]
    if not st or st.ped ~= ped or isPedDead(ped) or getElementSyncer(ped) ~= client then return end
    killPed(ped, isElement(attacker) and attacker or nil)
end)

addEventHandler("onPedWasted", root, function()
    local st = states[getElementData(source, "vana:encounter")]
    if not st or st.ped ~= source or st.killed then return end
    st.killed, st.attacker = true, nil
    MapPoints.remove("encounter:" .. st.e.id)
    debugLog(("%s (%s) killed"):format(nameOf(st.e), st.e.id))
    payOut(st)
end)

addEventHandler("onPlayerQuit", root, function()
    for _, st in pairs(states) do
        st.damage[source] = nil
        if st.attacker == source then st.attacker = nil end
    end
end)

addEventHandler("onResourceStart", resourceRoot, function()
    for _, e in ipairs(Encounters) do
        if not EncounterKinds[e.kind] then
            outputDebugString(("[vana-encounters] %s: unknown kind %s"):format(e.id, tostring(e.kind)), 2)
        elseif states[e.id] then
            outputDebugString(("[vana-encounters] two encounters named %s: the second is ignored"):format(e.id), 2)
        else
            states[e.id] = { e = e, damage = {} }
        end
    end
end)

setTimer(function()
    local hour, now = getTime(), getTickCount()
    for _, st in pairs(states) do think(st, hour, now) end
end, R.tick, 0)

addEventHandler("onResourceStop", resourceRoot, function()
    for _, st in pairs(states) do removePed(st) end
end)

-- Console-only: every encounter has a known kind, a unique id and its files.
addCommandHandler("encountertest", function(source)
    if getElementType(source) ~= "console" then return end
    local ok, count, out, problems = true, 0, 0, {}
    local seen = {}
    for _, e in ipairs(Encounters) do
        count = count + 1
        local kind = EncounterKinds[e.kind]
        if not kind then problems[#problems + 1] = e.id .. ": unknown kind " .. tostring(e.kind) end
        if seen[e.id] then problems[#problems + 1] = "duplicate id " .. e.id end
        seen[e.id] = true
        if kind and kind.dff and not (fileExists(kind.dff) and fileExists(kind.txd)) then problems[#problems + 1] = e.kind .. ": model files missing" end
        local st = states[e.id]
        if st and isElement(st.ped) and not isPedDead(st.ped) then out = out + 1 end
    end
    if #problems > 0 then ok = false end
    local lines = {}
    for id, st in pairs(states) do
        lines[#lines + 1] = ("%s %02d-%02d %s"):format(id, st.e.startHour, st.e.endHour, st.killed and "killed today" or isElement(st.ped) and "out" or "waiting")
    end
    table.sort(lines)
    outputServerLog(("[encountertest] %d encounters, %d out now: %s"):format(count, out, table.concat(lines, "; ")))
    if #problems > 0 then outputServerLog("[encountertest] " .. table.concat(problems, "; ")) end
    outputServerLog("[encountertest] " .. (ok and "PASS" or "FAIL"))
end)
