-- Bigfoot (Bigfoot.cs v1.2 by Tysman, see docs/credits.md): while a player is in the south-west
-- countryside, he may appear at one of the mod's spots (`encounter` elements, creature "bigfoot") out
-- of their sight: in fog, a spot with fog in its weather (walking to a point); otherwise one without
-- (standing); and at the spot's hours. He fades away once he's far from where he appeared or from
-- everyone. Hurt him and he goes for you. One at a time, server-wide.
local B = EncounterRules.bigfoot
local current     -- { ped, spawn, attacking }
local nextChance = 0

local function inArea(x, y)
    local a = B.area
    return x >= math.min(a[1], a[3]) and x <= math.max(a[1], a[3]) and y >= math.min(a[2], a[4]) and y <= math.max(a[2], a[4])
end

local function outdoorPlayers()
    local list = {}
    for _, player in ipairs(getElementsByType("player")) do
        if getElementInterior(player) == 0 and getElementDimension(player) == 0 and not isPedDead(player) then list[#list + 1] = player end
    end
    return list
end

local function nearestDistance(x, y, z, players)
    local best, who = math.huge, nil
    for _, player in ipairs(players) do
        local px, py, pz = getElementPosition(player)
        local d = getDistanceBetweenPoints3D(x, y, z, px, py, pz)
        if d < best then best, who = d, player end
    end
    return best, who
end

local function remove(fade)
    local ped = current and current.ped
    current, nextChance = nil, getTickCount() + B.respawnMs
    if not isElement(ped) then return end
    if not fade then destroyElement(ped) return end
    -- Vanilla destroy-with-fade.
    local alpha = 255
    setTimer(function()
        alpha = alpha - 51
        if not isElement(ped) then return end
        if alpha <= 0 then destroyElement(ped) else setElementAlpha(ped, alpha) end
    end, 200, 5)
end

local function spawn(spot, owner)
    local ped = createPed(B.baseModel, spot[1], spot[2], spot[3] + 1, math.random(0, 359))
    if not ped then return end
    setElementData(ped, "vana:creature", "bigfoot")
    setPedFightingStyle(ped, B.fightingStyle)
    setPedWalkingStyle(ped, B.walkingStyle)
    setElementSyncer(ped, owner, true, true)
    current = { ped = ped, spawn = spot }
    if spot.ex then triggerClientEvent(owner, "vana-encounters:walk", resourceRoot, ped, spot.ex, spot.ey, spot.ez) end
end

-- His spots: the `encounter` elements for him.
local function bigfootSpots()
    local list = {}
    for _, s in ipairs(Encounters) do if s.creature == "bigfoot" then list[#list + 1] = s end end
    return list
end

local function trySpawn(players)
    local weather = getWeather()
    local fog = B.fogWeathers[weather] or false
    local hour = getTime()
    for _, player in ipairs(players) do
        local px, py = getElementPosition(player)
        if inArea(px, py) and math.random() < B.chance then
            local spots = {}
            for _, s in ipairs(bigfootSpots()) do
                local weatherFits = (s.weathers and fog and s.weathers[weather]) or (not s.weathers and not fog)
                if weatherFits and encounterOpen(s, hour) and nearestDistance(s[1], s[2], s[3], players) > B.spawnAway then spots[#spots + 1] = s end
            end
            if #spots > 0 then
                local spot = spots[math.random(#spots)]
                local _, owner = nearestDistance(spot[1], spot[2], spot[3], players)
                return spawn(spot, owner)
            end
        end
    end
end

setTimer(function()
    local players = outdoorPlayers()
    local now = getTickCount()
    if current then
        local ped = current.ped
        if not isElement(ped) then return remove(false) end
        if isPedDead(ped) then
            -- The body stays a while, then goes.
            current.deadSince = current.deadSince or now
            if now - current.deadSince > 30000 then remove(false) end
            return
        end
        local x, y, z = getElementPosition(ped)
        local s = current.spawn
        local fromPlayers, nearest = nearestDistance(x, y, z, players)
        if getDistanceBetweenPoints3D(x, y, z, s[1], s[2], s[3]) > B.despawnFromSpawn or fromPlayers > B.despawnFromPlayer then
            return remove(true)
        end
        -- Keep him simulated by someone near, unless he's busy going for the one who hurt him.
        if not current.attacking and nearest and getElementSyncer(ped) ~= nearest then setElementSyncer(ped, nearest, true, true) end
    elseif now >= nextChance then
        trySpawn(players)
    end
end, B.checkMs, 0)

-- A player hurt him (reported by that player): he goes for them, as the mod's kill task.
addEvent("vana-encounters:hurt", true)
addEventHandler("vana-encounters:hurt", resourceRoot, function(ped)
    if not current or current.ped ~= ped or current.attacking == client or isPedDead(ped) then return end
    current.attacking = client
    setElementSyncer(ped, client, true, true)
    triggerClientEvent(client, "vana-encounters:attack", resourceRoot, ped, client)
end)

-- Killed where he's simulated (his toughness is applied there): only his syncer says so.
addEvent("vana-encounters:killed", true)
addEventHandler("vana-encounters:killed", resourceRoot, function(ped, attacker)
    if not current or current.ped ~= ped or isPedDead(ped) or getElementSyncer(ped) ~= client then return end
    killPed(ped, isElement(attacker) and attacker or nil)
end)

addEventHandler("onPlayerQuit", root, function()
    if current and current.attacking == source then current.attacking = nil end
end)

addEventHandler("onResourceStop", resourceRoot, function() if current then remove(false) end end)

-- Admin: Bigfoot 20 m in front of you, now (replacing the current one). Restricted: command.bigfoot.
addCommandHandler("bigfoot", function(player)
    if getElementType(player) ~= "player" then return end
    if current then remove(false) end
    local x, y, z = getElementPosition(player)
    local _, _, rz = getElementRotation(player)
    local h = math.rad(rz)
    spawn({ x - math.sin(h) * 20, y + math.cos(h) * 20, z }, player)
    outputChatBox("Bigfoot is 20 m ahead of you. Hurt him and he'll come for you.", player, 200, 200, 255)
end, true)

-- Console-only: the spots, the area and the model files are in place.
addCommandHandler("encountertest", function(source)
    if getElementType(source) ~= "console" then return end
    local fog, clear, targets, inside = 0, 0, 0, 0
    local spots = bigfootSpots()
    for _, s in ipairs(spots) do
        if s.weathers and s.weathers[9] then fog = fog + 1 else clear = clear + 1 end
        if s.ex then targets = targets + 1 end
        if inArea(s[1], s[2]) then inside = inside + 1 end
    end
    local files = fileExists("mods/bigfoot/bigfoot.dff") and fileExists("mods/bigfoot/bigfoot.txd")
    local ok = fog == 28 and clear == 10 and targets == 28 and inside == #spots and files
    outputServerLog(("[encountertest] Bigfoot: %d fog spots (%d walk somewhere), %d any-weather spots, %d of %d in his area; model files %s")
        :format(fog, targets, clear, inside, #spots, files and "present" or "missing"))
    outputServerLog("[encountertest] " .. (ok and "PASS" or "FAIL"))
end)
