-- Gym equipment: get on a bike, treadmill, bench press or dumbbells and tap the sprint key to work out.
-- Each rep (checked here: pace, hourly cap) raises stamina or muscle and burns fat; vana-player saves it.
-- Every client is told who uses which machine, so props.lua can move the barbell, dumbbells and pedals.
local sessions = {}   -- player -> { machine, index, kind, started, lastRep, leaving }
local inUse = {}      -- machine -> player
local gains = {}      -- serial -> { [stat] = { hourStart, gained } }

local function savePlayer(player)
    local res = getResourceFromName("vana-player")
    if res and getResourceState(res) == "running" then pcall(function() exports["vana-player"]:savePlayer(player) end) end
end

local function broadcast(index, player, phase)
    triggerClientEvent(root, "vana-gym:use", resourceRoot, index, player, phase)
end

-- Drops a session at once (death, quit): the machine is free and its props go back.
local function forget(player)
    local s = sessions[player]
    if not s then return end
    sessions[player], inUse[s.machine] = nil, nil
    broadcast(s.index, nil, "free")
end

-- Getting off plays the whole get-off animation; the machine stays taken until it ends.
local function stop(player)
    local s = sessions[player]
    if not s or s.leaving then return end
    s.leaving = true
    local m = Gym.machines[s.kind]
    setPedAnimation(player, m.lib, m.getoff, -1, false, false, false, true)
    triggerClientEvent(player, "vana-gym:stop", resourceRoot)
    broadcast(s.index, player, "off")
    setTimer(function()
        if sessions[player] ~= s then return end
        forget(player)
        setPedAnimation(player)
        setElementFrozen(player, false)
        savePlayer(player)
    end, m.getoffMs, 1)
end

-- Where the player stands to get on (Gym.placement, turned by the machine's heading); the marker sits here too.
local function standPoint(machine)
    local p = Gym.placement[machine.kind]
    local h = math.rad(machine.heading)
    local x = machine.x + p[1] * math.cos(h) - p[2] * math.sin(h)
    local y = machine.y + p[1] * math.sin(h) + p[2] * math.cos(h)
    return x, y, machine.z + p[3], machine.heading + p[4]
end

local function start(player, index)
    local machine = GymEquipment[index]
    if sessions[player] or inUse[machine] then return end
    local m = Gym.machines[machine.kind]
    sessions[player] = { machine = machine, index = index, kind = machine.kind, started = getTickCount(), lastRep = 0 }
    inUse[machine] = player
    setElementFrozen(player, true)
    local sx, sy, sz, heading = standPoint(machine)
    setElementPosition(player, sx, sy, sz)
    setElementRotation(player, 0, 0, heading, "default", true)
    setPedAnimation(player, m.lib, m.geton, -1, false, false, false, true)
    broadcast(index, player, "on")
    local s = sessions[player]
    setTimer(function()
        if sessions[player] == s and not s.leaving then setPedAnimation(player, m.lib, m.loop, -1, true, false, false, true) end
    end, m.getonMs, 1)
    triggerClientEvent(player, "vana-gym:start", resourceRoot, m.name, m.statName, Gym.tapsPerRep, getPedStat(player, m.stat), getPedStat(player, 21))
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
    if not s or s.leaving then return end
    local m = Gym.machines[s.kind]
    local now = getTickCount()
    if now - s.started < m.getonMs or now - s.lastRep < Gym.minRepMs then return end
    s.lastRep = now
    local gain = allowance(getPlayerSerial(client), m.stat, m.gain)
    setPedStat(client, m.stat, math.min(1000, getPedStat(client, m.stat) + gain))
    setPedStat(client, 21, math.max(0, getPedStat(client, 21) + m.fat))
    setPedAnimation(client, m.lib, m.fast, -1, false, false, false, true)
    local player = client
    setTimer(function()
        if sessions[player] == s and not s.leaving and getTickCount() - s.lastRep >= m.repMs then
            setPedAnimation(player, m.lib, m.loop, -1, true, false, false, true)
        end
    end, m.repMs, 1)
    triggerClientEvent(client, "vana-gym:progress", resourceRoot, getPedStat(client, m.stat), getPedStat(client, 21), gain == 0)
end)

addEvent("vana-gym:stop", true)
addEventHandler("vana-gym:stop", resourceRoot, function() stop(client) end)


addEventHandler("onResourceStart", resourceRoot, function()
    for index, machine in ipairs(GymEquipment) do
        if Gym.machines[machine.kind] then
            local x, y = standPoint(machine)
            local marker = createMarker(x, y, machine.z - 0.1, "cylinder", 1.0, 255, 120, 0, 90)
            setElementInterior(marker, machine.interior)
            -- Press enter/exit on the marker to get on (vana-lib's prompts).
            Prompts.add(marker, { text = "use the " .. Gym.machines[machine.kind].name:lower(), use = function(player) start(player, index) end })
        end
    end
end)

addEventHandler("onPlayerQuit", root, function() forget(source) end)
addEventHandler("onPlayerWasted", root, function() forget(source) end)

-- A client that just started gets everyone currently on a machine.
addEvent("vana-gym:hello", true)
addEventHandler("vana-gym:hello", resourceRoot, function()
    for player, s in pairs(sessions) do
        triggerClientEvent(client, "vana-gym:use", resourceRoot, s.index, player, s.leaving and "off" or "on", getTickCount() - s.started)
    end
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
    local ok = (counts.bike or 0) >= 3 and (counts.treadmill or 0) >= 3 and (counts.bench or 0) >= 3 and (counts.mat or 0) >= 3
        and first == 40 and second == Gym.maxGainPerHour - 40 and third == 0
    for kind in pairs(counts) do
        local m = Gym.machines[kind]
        if not m or not Gym.placement[kind] or not m.statName or not m.getonMs then ok = false; outputServerLog("[gymtest] FAIL incomplete config for " .. kind) end
    end
    outputServerLog(("[gymtest] bikes %d, treadmills %d, benches %d, dumbbell mats %d; hourly cap gives %d, %d, %d")
        :format(counts.bike or 0, counts.treadmill or 0, counts.bench or 0, counts.mat or 0, first, second, third))
    outputServerLog("[gymtest] " .. (ok and "PASS" or "FAIL"))
end)
