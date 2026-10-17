-- Gym equipment: get on a bike, treadmill or bench press and tap the sprint key to work out. Each
-- rep (checked here: pace, hourly cap) raises stamina or muscle and burns fat; vana-player saves it.
local sessions = {}   -- player -> { machine, kind, from = {x, y, z, rot}, lastRep }
local inUse = {}      -- machine -> player
local gains = {}      -- serial -> { [stat] = { hourStart, gained } }
local markers = {}    -- marker -> machine

local function savePlayer(player)
    local res = getResourceFromName("vana-player")
    if res and getResourceState(res) == "running" then pcall(function() exports["vana-player"]:savePlayer(player) end) end
end

local function stop(player)
    local s = sessions[player]
    if not s then return end
    sessions[player], inUse[s.machine] = nil, nil
    local m = Gym.machines[s.kind]
    setPedAnimation(player, m.lib, m.getoff, -1, false, false, false, false)
    triggerClientEvent(player, "vana-gym:stop", resourceRoot)
    setTimer(function()
        if not isElement(player) then return end
        setPedAnimation(player)
        setElementPosition(player, unpack(s.from, 1, 3))
        setElementRotation(player, 0, 0, s.from[4], "default", true)
        setElementFrozen(player, false)
        savePlayer(player)
    end, 1500, 1)
end

local function start(player, machine)
    if sessions[player] or inUse[machine] then return end
    local m = Gym.machines[machine.kind]
    local p = Gym.placement[machine.kind]
    local x, y, z = getElementPosition(player)
    local _, _, rz = getElementRotation(player)
    sessions[player] = { machine = machine, kind = machine.kind, from = { x, y, z, rz }, lastRep = 0 }
    inUse[machine] = player
    setElementFrozen(player, true)
    setElementPosition(player, machine.x + p[1], machine.y + p[2], machine.z + p[3])
    setElementRotation(player, 0, 0, machine.heading + p[4], "default", true)
    setPedAnimation(player, m.lib, m.geton, -1, false, false, false, true)
    setTimer(function()
        if sessions[player] and sessions[player].machine == machine then
            setPedAnimation(player, m.lib, m.loop, -1, true, false, false, true)
        end
    end, 1500, 1)
    triggerClientEvent(player, "vana-gym:start", resourceRoot, m.name, Gym.tapsPerRep, getPedStat(player, m.stat), getPedStat(player, 21))
end

-- The hourly cap: how much of `amount` the player with this serial may still gain in `stat`.
local function allowance(key, stat, amount)
    gains[key] = gains[key] or {}
    local g = gains[key][stat]
    local now = getTickCount()
    if not g or now - g.hourStart > 3600000 then g = { hourStart = now, gained = 0 }; gains[key][stat] = g end
    local allowed = math.max(0, math.min(amount, Gym.maxGainPerHour - g.gained))
    g.gained = g.gained + allowed
    return allowed
end

addEvent("vana-gym:rep", true)
addEventHandler("vana-gym:rep", resourceRoot, function()
    local s = sessions[client]
    if not s then return end
    local now = getTickCount()
    if now - s.lastRep < Gym.minRepMs then return end
    s.lastRep = now
    local m = Gym.machines[s.kind]
    local gain = allowance(getPlayerSerial(client), m.stat, m.gain)
    setPedStat(client, m.stat, math.min(1000, getPedStat(client, m.stat) + gain))
    setPedStat(client, 21, math.max(0, getPedStat(client, 21) + m.fat))
    setPedAnimation(client, m.lib, m.fast, -1, false, false, false, true)
    setTimer(function()
        if sessions[client] == s then setPedAnimation(client, m.lib, m.loop, -1, true, false, false, true) end
    end, 700, 1)
    triggerClientEvent(client, "vana-gym:progress", resourceRoot, getPedStat(client, m.stat), getPedStat(client, 21), gain == 0)
end)

addEvent("vana-gym:stop", true)
addEventHandler("vana-gym:stop", resourceRoot, function() stop(client) end)

local function onMarkerHit(player, matching)
    local machine = markers[source]
    if not matching or not machine or getElementType(player) ~= "player" or getPedOccupiedVehicle(player) then return end
    if getElementInterior(player) ~= machine.interior then return end
    start(player, machine)
end

addEventHandler("onResourceStart", resourceRoot, function()
    for _, machine in ipairs(GymEquipment) do
        if Gym.machines[machine.kind] then
            local marker = createMarker(machine.x, machine.y, machine.z - 0.1, "cylinder", 1.0, 255, 120, 0, 90)
            setElementInterior(marker, machine.interior)
            markers[marker] = machine
            addEventHandler("onMarkerHit", marker, onMarkerHit)
        end
    end
end)

addEventHandler("onPlayerQuit", root, function()
    local s = sessions[source]
    if s then inUse[s.machine], sessions[source] = nil, nil end
end)
addEventHandler("onPlayerWasted", root, function()
    local s = sessions[source]
    if s then inUse[s.machine], sessions[source] = nil, nil end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for player in pairs(sessions) do
        setPedAnimation(player)
        setElementFrozen(player, false)
    end
end)

-- Console-only: equipment data and the hourly cap.
addCommandHandler("gymtest", function(source)
    if getElementType(source) ~= "console" then return end
    local counts = {}
    for _, machine in ipairs(GymEquipment) do counts[machine.kind] = (counts[machine.kind] or 0) + 1 end
    local first, second, third = allowance("TEST", 23, 40), allowance("TEST", 23, 40), allowance("TEST", 23, 40)
    gains["TEST"] = nil
    local ok = (counts.bike or 0) >= 3 and (counts.treadmill or 0) >= 3 and (counts.bench or 0) >= 3
        and first == 40 and second == Gym.maxGainPerHour - 40 and third == 0
    outputServerLog(("[gymtest] bikes %d, treadmills %d, benches %d, mats %d; hourly cap gives %d, %d, %d")
        :format(counts.bike or 0, counts.treadmill or 0, counts.bench or 0, counts.mat or 0, first, second, third))
    outputServerLog("[gymtest] " .. (ok and "PASS" or "FAIL"))
end)
