-- Vanilla entry/exit markers (ENEX): step into a yellow arrow and, after a fade, you're at the
-- same-named marker in the other area. MTA disables GTA's own entry/exit manager, so this
-- reproduces it server-side from [data]/vana-data-interiors/entrances.map.
local CONFIG = {
    fadeMs = 500,
    cooldownMs = 1500,      -- no re-trigger right after arriving
    holdMs = 5000,          -- the longest a player is held after arriving, waiting for the floor to load
    minTrigger = 1.2,       -- trigger boxes are at least this wide (some IPL sizes are tiny)
    respectOpeningHours = true,
}

local byName = {}       -- NAME -> list of entries
local triggers = {}     -- colshape -> entry
local lastUsed = {}     -- player -> { [NAME] = exterior entry they came in through }
local busy = {}         -- player -> tick of the last transition

local function isOpen(e)
    if not CONFIG.respectOpeningHours or (e.open == 0 and e.close >= 24) then return true end
    local hour = getTime()
    if e.open <= e.close then return hour >= e.open and hour < e.close end
    return hour >= e.open or hour < e.close -- open across midnight
end

-- Where an entrance is: its interior and dimension (an interior copied elsewhere has an instance).
local function sameArea(a, b) return a.interior == b.interior and (a.instance or 0) == (b.instance or 0) end

local function isDoor(e)
    return bitAnd(e.flags or 0, 4) ~= 0
end

-- The marker on the other side. Vanilla pairs by name and flags: a door (flag 4, "create linked
-- pair") leads to the same-named hub (no flag 4), and a hub leads back to the door the player came
-- through. That covers street doors, interiors shared by several doors (pizza shops) and safehouse
-- closets that all open into one changing room. Names without that split pair by area instead.
local function partnerOf(player, e)
    local list = byName[e.name]
    local doors, hubs, otherArea = {}, {}, {}
    for _, other in ipairs(list) do
        if other ~= e then
            if isDoor(other) then doors[#doors + 1] = other else hubs[#hubs + 1] = other end
            if not sameArea(other, e) then otherArea[#otherArea + 1] = other end
        end
    end
    local used = lastUsed[player] and lastUsed[player][e.name]
    if isDoor(e) and hubs[1] then return hubs[1] end
    if not isDoor(e) and #doors > 0 then
        if used and used ~= e then return used end
        return doors[1]
    end
    -- No door/hub split: outside goes in, inside goes back out the way the player came.
    if used and used ~= e and not sameArea(used, e) then return used end
    if e.interior == 0 then
        for _, other in ipairs(otherArea) do if other.interior ~= 0 then return other end end
    end
    for _, other in ipairs(otherArea) do if other.interior == 0 then return other end end
    return otherArea[1]
end

-- Held after arriving until their client has the floor (client.lua), at most holdMs.
local holding = {} -- player -> token (a number: it goes to the client and back)
local tokens = 0

local function release(player, token)
    if holding[player] ~= token then return end
    holding[player] = nil
    if not isElement(player) then return end
    setCameraTarget(player, player)
    fadeCamera(player, true, CONFIG.fadeMs / 1000)
    setElementFrozen(player, false)
    busy[player] = getTickCount()
end

addEvent("vana-interiors:ready", true)
addEventHandler("vana-interiors:ready", resourceRoot, function(token) release(client, token) end)

local function transition(player, from, to)
    busy[player] = getTickCount()
    -- Remember the way in, to come back out the same way.
    lastUsed[player] = lastUsed[player] or {}
    lastUsed[player][from.name] = from
    setElementFrozen(player, true)
    fadeCamera(player, false, CONFIG.fadeMs / 1000)
    setTimer(function()
        if not isElement(player) then return end
        -- GTA's entry-exit conversion puts the player 1 m above the IPL point.
        setElementInterior(player, to.interior, to.ex, to.ey, to.ez + 1)
        setElementDimension(player, to.instance or 0)
        setElementPosition(player, to.ex, to.ey, to.ez + 1)
        setElementRotation(player, 0, 0, to.heading, "default", true)
        -- Still frozen and faded until the floor there has loaded (or holdMs passes).
        tokens = tokens + 1
        local token = tokens
        holding[player] = token
        triggerClientEvent(player, "vana-interiors:arrived", resourceRoot, token, to.ex, to.ey, to.ez)
        setTimer(release, CONFIG.holdMs, 1, player, token)
        busy[player] = getTickCount()
        -- Other resources can react to arrivals.
        -- Arguments: entrance name, from interior, to interior, arrived at a hub (not a door).
        triggerEvent("onPlayerUseEntrance", player, to.name, from.interior, to.interior, not isDoor(to))
    end, CONFIG.fadeMs + 100, 1)
end

addEvent("onPlayerUseEntrance")

local function onHit(player, matching)
    if not matching or getElementType(player) ~= "player" or isPedDead(player) or getPedOccupiedVehicle(player) then return end
    local e = triggers[source]
    if not e or getElementInterior(player) ~= e.interior or getElementDimension(player) ~= (e.instance or 0) then return end
    if busy[player] and getTickCount() - busy[player] < CONFIG.cooldownMs then return end
    if not isOpen(e) then
        outputChatBox(("Closed. Opens at %02d:00."):format(e.open), player, 255, 200, 50)
        return
    end
    local to = partnerOf(player, e)
    if to then transition(player, e, to) end
end

addEventHandler("onResourceStart", resourceRoot, function()
    for _, e in ipairs(Entrances) do
        if e.enabled then
            byName[e.name] = byName[e.name] or {}
            table.insert(byName[e.name], e)
        end
    end
    for _, e in ipairs(Entrances) do
        -- Burglary-access doors (flag 0x1000) open only during a burglary; vana-activities owns them.
        if e.enabled and #byName[e.name] > 1 and bitAnd(e.flags or 0, 0x1000) == 0 then
            local w, d = math.max(CONFIG.minTrigger, e.size[1]), math.max(CONFIG.minTrigger, e.size[2])
            local col = createColCuboid(e.x - w / 2, e.y - d / 2, e.z, w, d, 3)
            setElementInterior(col, e.interior)
            setElementDimension(col, e.instance or 0)
            triggers[col] = e
            addEventHandler("onColShapeHit", col, onHit)
            -- The yellow arrow, hovering over the doorway.
            local marker = createMarker(e.x, e.y, e.z + 1.5, "arrow", 1.0, 255, 220, 0, 170)
            setElementInterior(marker, e.interior)
            setElementDimension(marker, e.instance or 0)
            e.marker = marker
            -- Street doors go on the map; vana-map knows which names to show and as what.
            if e.interior == 0 then MapPoints.set("enex:" .. e.name .. ":" .. math.floor(e.x) .. ":" .. math.floor(e.y), { tag = e.name, x = e.x, y = e.y, z = e.z }) end
        end
    end
end)

addEventHandler("onPlayerQuit", root, function() lastUsed[source], busy[source], holding[source] = nil, nil, nil end)

-- Console-only: every enabled entrance has somewhere to go.
addCommandHandler("interiortest", function(source)
    if getElementType(source) ~= "console" then return end
    local linked, lonely, names = 0, {}, 0
    for name, list in pairs(byName) do
        names = names + 1
        if #list > 1 then linked = linked + #list else lonely[#lonely + 1] = name end
    end
    local binco = byName.CSCHP and partnerOf(source, byName.CSCHP[1].interior == 0 and byName.CSCHP[1] or byName.CSCHP[2])
    local function find(name, x)
        for _, e in ipairs(byName[name] or {}) do if math.abs(e.x - x) < 1 then return e end end
    end
    local fake = {}
    local closetDoor, room = find("CHANGER", 2251.52), find("CHANGER", 254.137)
    lastUsed[fake] = { CHANGER = closetDoor }
    local into, back = partnerOf(fake, closetDoor), partnerOf(fake, room)
    lastUsed[fake] = nil
    local closets = into == room and back == closetDoor
    outputServerLog(("[interiortest] closet in a non-CJ house goes to the changing room and back to that house: %s"):format(tostring(closets)))
    local ok = linked > 300 and binco and binco.interior ~= 0 and closets
    outputServerLog(("[interiortest] %d names, %d linked entrances; unpaired names (no destination): %s")
        :format(names, linked, table.concat(lonely, ", ")))
    if binco then outputServerLog(("[interiortest] Binco leads to interior %d at %.1f, %.1f, %.1f"):format(binco.interior, binco.ex, binco.ey, binco.ez + 1)) end
    outputServerLog("[interiortest] " .. (ok and "PASS" or "FAIL"))
end)
