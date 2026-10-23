addEventHandler("onResourceStart", resourceRoot, function()
    outputServerLog("[vana-core] started on " .. getServerName() .. " (MTA " .. getVersion().sortable .. ")")
end)

-- Players' script errors and warnings (client.lua), at most 30 a minute from each.
local counts = {} -- player -> { n, since }
addEvent("vana-core:clientError", true)
addEventHandler("vana-core:clientError", resourceRoot, function(kind, text)
    if type(kind) ~= "string" or type(text) ~= "string" then return end
    local now = getTickCount()
    local c = counts[client]
    if not c or now - c.since > 60000 then c = { n = 0, since = now } counts[client] = c end
    c.n = c.n + 1
    if c.n > 30 then return end
    outputServerLog(("[client %s] %s: %s"):format(getPlayerName(client):gsub("#%x%x%x%x%x%x", ""), kind == "ERROR" and "ERROR" or "WARNING", text:sub(1, 300)))
end)
addEventHandler("onPlayerQuit", root, function() counts[source] = nil end)

-- Debug switches (docs/debug.md): which resources run their debug checks, all of them or by topic.
-- Kept in this resource's "debug" setting (settings.xml), e.g. "vana-core:stuck vana-peds", and put on
-- each resource's root element as "vana:debug" ("all" or "topic,topic") whenever it starts.
local TOPICS = { -- resource -> { topic = what it checks }
    ["vana-core"] = { stuck = "peds near a player that stop moving or hang in the air, with what their owner last told them" },
    ["vana-peds"] = { orders = "every walk or encounter order a client couldn't give, with the ped's state" },
    ["vana-controls"] = { targets = "how each action found its target, or why it found none" },
    ["vana-traffic"] = { telemetry = "slow traffic units and their native autopilot state (as /traffic debug)" },
    ["vana-air"] = { sync = "aircraft made and removed, who flies them, taken or come down (as /air debug)" },
    ["vana-trains"] = { sync = "trains made and removed, who simulates them, taken trains, and where a train's game disagrees with the timetable (as /trains debug)" },
    ["vana-encounters"] = { encounters = "each encounter appearing, cleaned up, going for someone, giving up, killed" },
    ["vana-wildlife"] = { brains = "what animals do (spawning, fleeing, hurt, chases, deaths, despawns) and orders a client couldn't give" },
}
local switches = {} -- resource name -> "all" | "topic,topic"

local function apply(res)
    local root = getResourceRootElement(res)
    if not root then return end
    local value = switches[getResourceName(res)]
    if value then setElementData(root, "vana:debug", value)
    elseif getElementData(root, "vana:debug") then removeElementData(root, "vana:debug") end
end

local function save()
    local parts = {}
    for name, value in pairs(switches) do parts[#parts + 1] = value == "all" and name or (name .. ":" .. value) end
    table.sort(parts)
    set("debug", table.concat(parts, " "))
end

-- Turns a resource's debug on ("all", or a list of topics) or off (nil), at once and for good.
function setDebug(name, value)
    if type(name) ~= "string" then return false end
    switches[name] = value
    save()
    local res = getResourceFromName(name)
    if res and getResourceState(res) == "running" then apply(res) end
    return true
end

function isDebugOn(name, topic)
    local v = switches[name]
    return v == "all" or (v ~= nil and ("," .. v .. ","):find("," .. topic .. ",", 1, true) ~= nil)
end

addEventHandler("onResourceStart", root, function(res)
    if res == resource then
        for word in tostring(get("debug") or ""):gmatch("%S+") do
            local name, topics = word:match("^([^:]+):?(.*)$")
            if name then switches[name] = topics ~= "" and topics or "all" end
        end
        for _, r in ipairs(getResources()) do
            if getResourceState(r) == "running" then apply(r) end
        end
    else
        apply(res)
    end
end)

-- /vanadebug [resource|all] [on|off|topic,topic]. Restricted: command.vanadebug.
addCommandHandler("vanadebug", function(source, _, target, value)
    local function reply(msg)
        if getElementType(source) == "console" then outputServerLog("[vanadebug] " .. msg) else outputChatBox(msg, source, 200, 200, 255) end
    end
    if not target then
        local names = {}
        for name in pairs(TOPICS) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do
            local topics = {}
            for topic, what in pairs(TOPICS[name]) do topics[#topics + 1] = topic .. " (" .. what .. ")" end
            reply(("%s: %s  -  %s"):format(name, switches[name] or "off", table.concat(topics, "; ")))
        end
        return reply("Usage: /vanadebug <resource|all> on|off|<topic,topic>")
    end
    if not target:find("^vana%-") and target ~= "all" then target = "vana-" .. target end
    if not value then return reply(("%s: %s"):format(target, switches[target] or "off")) end
    value = value:lower()
    local setTo = (value == "off") and nil or (value == "on" or value == "all") and "all" or value
    if target == "all" then
        for name in pairs(TOPICS) do setDebug(name, setTo) end
        return reply("Debug " .. (setTo and "on" or "off") .. " for every resource with checks.")
    end
    if setTo and setTo ~= "all" and TOPICS[target] then
        for topic in setTo:gmatch("[^,]+") do
            if not TOPICS[target][topic] then return reply(("%s has no topic %s."):format(target, topic)) end
        end
    end
    setDebug(target, setTo)
    reply(("%s debug: %s"):format(target, setTo or "off"))
end, true)

-- /vanaset [resource] [name value]: our resources' levers (their meta.xml settings, through
-- vana-lib's settings: the ones exporting getSettings), kept in settings.xml. Restricted: command.vanaset.
local function settingsOf(res)
    if getResourceState(res) ~= "running" then return end
    for _, fn in ipairs(getResourceExportedFunctions(res)) do
        if fn == "getSettings" then
            local ok, list = pcall(call, res, "getSettings")
            return ok and type(list) == "table" and list or nil
        end
    end
end

addCommandHandler("vanaset", function(source, _, target, name, value)
    local function reply(msg)
        if getElementType(source) == "console" then outputServerLog("[vanaset] " .. msg) else outputChatBox(msg, source, 200, 200, 255) end
    end
    if not target then
        local names = {}
        for _, res in ipairs(getResources()) do
            if getResourceName(res):find("^vana%-") and settingsOf(res) then names[#names + 1] = getResourceName(res) end
        end
        table.sort(names)
        reply("With settings: " .. (#names > 0 and table.concat(names, ", ") or "none running"))
        return reply("Usage: /vanaset <resource> [<name> <value>]")
    end
    if not target:find("^vana%-") then target = "vana-" .. target end
    local res = getResourceFromName(target)
    local list = res and settingsOf(res)
    if not list then return reply(target .. " isn't running, or has no settings.") end
    if not name then
        local keys = {}
        for k in pairs(list) do keys[#keys + 1] = k end
        table.sort(keys)
        for i, k in ipairs(keys) do keys[i] = k .. " = " .. tostring(list[k]) end
        return reply(target .. ": " .. table.concat(keys, ", "))
    end
    if list[name] == nil then return reply(("%s has no setting %s."):format(target, name)) end
    if not value then return reply(("%s %s = %s"):format(target, name, tostring(list[name]))) end
    local ok, saved, now = pcall(call, res, "setSetting", name, value)
    if not ok or not saved then return reply(("Couldn't set %s %s."):format(target, name)) end
    reply(("%s %s = %s (saved)"):format(target, name, tostring(now)))
end, true)

-- Debug lines from clients (vana-lib's debug, Debug.log), while their switch is on: 60 a minute each.
local debugCounts = {}
addEvent("vana-core:debug", true)
addEventHandler("vana-core:debug", root, function(name, topic, text)
    if type(name) ~= "string" or type(topic) ~= "string" or type(text) ~= "string" or not isDebugOn(name, topic) then return end
    local now = getTickCount()
    local c = debugCounts[client]
    if not c or now - c.since > 60000 then c = { n = 0, since = now } debugCounts[client] = c end
    c.n = c.n + 1
    if c.n > 60 then return end
    outputServerLog(("[debug %s:%s] %s: %s"):format(name, topic, (getPlayerName(client):gsub("#%x%x%x%x%x%x", "")), text:sub(1, 400)))
end)
addEventHandler("onPlayerQuit", root, function() debugCounts[source] = nil end)

-- Stuck peds (client.lua, topic vana-core:stuck): what the client sees, then what the resources that
-- run the ped last told it (their describePed export).
local DESCRIBERS = { "vana-peds", "vana-services" }
addEvent("vana-core:stuck", true)
addEventHandler("vana-core:stuck", resourceRoot, function(ped, seen)
    if not isDebugOn("vana-core", "stuck") or not isElement(ped) or getElementType(ped) ~= "ped" or type(seen) ~= "string" then return end
    local syncer = getElementSyncer(ped)
    local parts = { ("syncer %s"):format(isElement(syncer) and (getPlayerName(syncer):gsub("#%x%x%x%x%x%x", "")) or "none") }
    for _, name in ipairs(DESCRIBERS) do
        local res = getResourceFromName(name)
        if res and getResourceState(res) == "running" then
            local ok, text = pcall(call, res, "describePed", ped)
            if ok and type(text) == "string" then parts[#parts + 1] = name .. ": " .. text end
        end
    end
    local x, y, z = getElementPosition(ped)
    outputServerLog(("[debug vana-core:stuck] ped %s model %d at %.1f, %.1f, %.1f int %d: %s | %s"):format(tostring(ped):sub(-8), getElementModel(ped),
        x, y, z, getElementInterior(ped), seen:sub(1, 300), table.concat(parts, "; ")))
end)
