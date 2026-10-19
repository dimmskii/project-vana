-- Actions (docs/controls.md): every running resource's actions (vana-lib's actions module), made
-- commands on every client, run here. A command names its target (a player's name or a #id), or
-- the client says what was clicked and what the player can see, nearest the middle of the view
-- first; the first of those the action takes is the target. Every action passes the same gate:
-- same dimension and interior, within its reach, in view, alive.
local actions = {}  -- name or alias -> { def, res }
local listed = {}   -- the defs, in load order (sent to clients)
local tids, byTid, lastTid = {}, {}, 0 -- element <-> the short number typed as #id
local lastRun = {}  -- player -> tick

local function plainName(player) return (getPlayerName(player):gsub("#%x%x%x%x%x%x", "")) end

local function rebuild()
    actions, listed = {}, {}
    for _, res in ipairs(getResources()) do
        if getResourceState(res) == "running" then
            local exported = false
            for _, fn in ipairs(getResourceExportedFunctions(res) or {}) do exported = exported or fn == "getActions" end
            local ok, defs = exported, nil
            if exported then ok, defs = pcall(call, res, "getActions") end
            if ok and type(defs) == "table" then
                for _, def in ipairs(defs) do
                    if type(def.name) == "string" and not actions[def.name] then
                        local entry = { def = def, res = res }
                        actions[def.name] = entry
                        for _, a in ipairs(def.aliases or {}) do actions[a] = actions[a] or entry end
                        listed[#listed + 1] = def
                    end
                end
            end
        end
    end
end

local function send(to)
    triggerClientEvent(to, "vana-controls:actions", resourceRoot, listed)
end

addEventHandler("onResourceStart", root, function(res)
    if res ~= resource then
        local exported = false
        for _, fn in ipairs(getResourceExportedFunctions(res) or {}) do exported = exported or fn == "getActions" end
        if not exported then return end
    end
    rebuild()
    -- Starting ourselves, clients aren't ready yet: each asks when it is (vana-controls:hello).
    if res ~= resource then send(root) end
end)
addEventHandler("onResourceStop", root, function(res)
    if res == resource then return end
    for _, entry in pairs(actions) do
        if entry.res == res then
            setTimer(function() rebuild() send(root) end, 50, 1)
            return
        end
    end
end)

addEvent("vana-controls:hello", true)
addEventHandler("vana-controls:hello", resourceRoot, function() send(client) end)

-- A message on the player's screen (the status line, vanilla's help box) and in their console.
function status(player, text)
    if isElement(player) and getElementType(player) == "player" and type(text) == "string" then
        triggerClientEvent(player, "vana-controls:status", resourceRoot, text)
    end
end

local function tidOf(element)
    if not tids[element] then
        lastTid = lastTid + 1
        tids[element], byTid[lastTid] = lastTid, element
        setElementData(element, "vana:tid", lastTid)
        local n = lastTid
        addEventHandler("onElementDestroy", element, function() tids[element], byTid[n] = nil, nil end, false)
    end
    return tids[element]
end

-- A player by name: an exact match, else the only one whose name contains it (colour codes ignored).
local function playerByName(name)
    name = name:lower()
    local found
    for _, p in ipairs(getElementsByType("player")) do
        local n = plainName(p):lower()
        if n == name then return p end
        if n:find(name, 1, true) then
            if found then return nil, "More than one player is called that." end
            found = p
        end
    end
    return found
end

local function allowed(player, def)
    return not def.right or hasObjectPermissionTo(player, def.right, false)
end

local function takes(entry, player, target)
    local ok, yes = pcall(call, entry.res, "checkActionTarget", entry.def.name, player, target)
    return ok and yes == true
end

-- The fixed gate every target passes. `seen`: the elements the player's client can see.
local function gate(player, def, target, seen)
    if not isElement(target) or target == player then return false, "There's nothing there." end
    if def.inside and getPedOccupiedVehicle(player) == target then return true end
    if getElementDimension(target) ~= getElementDimension(player) or getElementInterior(target) ~= getElementInterior(player) then
        return false, "That's too far away."
    end
    local x, y, z = getElementPosition(player)
    local tx, ty, tz = getElementPosition(target)
    if getDistanceBetweenPoints3D(x, y, z, tx, ty, tz) > def.reach then return false, "That's too far away." end
    if not seen[target] then return false, "You can't see that from here." end
    local kind = getElementType(target)
    if (kind == "ped" or kind == "player") and isPedDead(target) then return false, "There's nothing there." end
    return true
end

-- Arguments: #ids anywhere name the target; the rest fill the action's params in order.
local function parse(def, words)
    local args, target, rest = {}, nil, {}
    for _, w in ipairs(words) do
        local n = tonumber(w:match("^#(%d+)$"))
        if n then
            target = byTid[n]
            if not target then return nil, nil, "Nothing has the number #" .. n .. "." end
        else
            rest[#rest + 1] = w
        end
    end
    local i = 1
    for _, p in ipairs(def.params or {}) do
        local w = rest[i]
        if p[2] == "target" then
            if w and not target then
                local found, why = playerByName(w)
                if not found then return nil, nil, why or ("Nobody called " .. w .. " is here.") end
                target = found
                i = i + 1
            end
        else
            if w then
                if p[2] == "number" then
                    if not tonumber(w) then return nil, nil, "Usage: /" .. def.name .. " " .. (def.usage or "") end
                    args[p[1]] = tonumber(w)
                else
                    args[p[1]] = w
                end
                i = i + 1
            elseif p[3] then
                return nil, nil, "Usage: /" .. def.name .. " " .. (def.usage or "")
            end
        end
    end
    return args, target
end

local function asElements(t, limit)
    local out, set = {}, {}
    if type(t) ~= "table" then return out, set end
    for i = 1, math.min(#t, limit) do
        if isElement(t[i]) then out[#out + 1] = t[i]; set[t[i]] = true end
    end
    return out, set
end

local function run(player, name, words, picked, seenList)
    local entry = actions[name]
    if not entry then return end
    local def = entry.def
    if not allowed(player, def) then return status(player, "You can't use that.") end
    local args, target, why = parse(def, words)
    if not args then return status(player, why) end
    local seenOrder, seen = asElements(seenList, 24)
    if isElement(picked) then seen[picked] = true end
    if def.targets then
        if target then
            if not takes(entry, player, target) then return status(player, "You can't do that to " .. (getElementType(target) == "player" and plainName(target) or "that") .. ".") end
        else
            local vehicle = def.inside and getPedOccupiedVehicle(player)
            local candidates = {}
            if vehicle then candidates[1] = vehicle end
            if isElement(picked) then candidates[#candidates + 1] = picked end
            for _, e in ipairs(seenOrder) do candidates[#candidates + 1] = e end
            local firstWhy
            for _, e in ipairs(candidates) do
                if takes(entry, player, e) then
                    local ok, reason = gate(player, def, e, seen)
                    if ok then target = e break end
                    firstWhy = firstWhy or reason
                end
            end
            if not target then return status(player, firstWhy or "There's nothing here for that.") end
        end
        local ok, reason = gate(player, def, target, seen)
        if not ok then return status(player, reason) end
    end
    local pok, _, message = pcall(call, entry.res, "runAction", def.name, player, target, args)
    if not pok then return end
    if message then status(player, message) end
end

addEvent("vana-controls:run", true)
addEventHandler("vana-controls:run", resourceRoot, function(name, words, picked, seen)
    if type(name) ~= "string" or type(words) ~= "table" or #words > 8 then return end
    local now = getTickCount()
    if lastRun[client] and now - lastRun[client] < 150 then return end
    lastRun[client] = now
    local clean = {}
    for i, w in ipairs(words) do
        if type(w) ~= "string" then return end
        clean[i] = w:sub(1, 64)
    end
    run(client, name:lower(), clean, picked, seen)
end)

-- The context menu for a clicked element: every action that takes it now, past the gate.
addEvent("vana-controls:menu", true)
addEventHandler("vana-controls:menu", resourceRoot, function(target)
    if not isElement(target) then return end
    local items, done = {}, {}
    for _, def in ipairs(listed) do
        local entry = actions[def.name]
        if not done[entry.res] then
            done[entry.res] = true
            local ok, list = pcall(call, entry.res, "getTargetActions", client, target)
            for _, item in ipairs(ok and type(list) == "table" and list or {}) do
                local own = actions[item.name]
                if own and allowed(client, own.def) and gate(client, own.def, target, { [target] = true }) then
                    items[#items + 1] = item
                end
            end
        end
    end
    triggerClientEvent(client, "vana-controls:menu", resourceRoot, target, tidOf(target), items)
end)

-- Anything else typed in /interact's box: run as the command it is, with the player's ACL rights.
addEvent("vana-controls:command", true)
addEventHandler("vana-controls:command", resourceRoot, function(name, line)
    if type(name) ~= "string" or (line ~= nil and type(line) ~= "string") or actions[name:lower()] then return end
    local now = getTickCount()
    if lastRun[client] and now - lastRun[client] < 150 then return end
    lastRun[client] = now
    executeCommandHandler(name, client, line and line:sub(1, 200) or nil)
end)

addEventHandler("onPlayerQuit", root, function() lastRun[source] = nil end)

-- Console-only: the actions load, parse and pass the gate as they should.
addCommandHandler("controlstest", function(source)
    if getElementType(source) ~= "console" then return end
    local ok = true
    local function check(what, cond)
        if not cond then ok = false end
        outputServerLog(("[controlstest] %s %s"):format(cond and "ok  " or "FAIL", what))
    end
    local names = {}
    for _, def in ipairs(listed) do names[#names + 1] = def.name end
    outputServerLog("[controlstest] actions: " .. table.concat(names, ", "))
    for _, need in ipairs({ "givemoney", "engine", "lights", "lock", "doorfrontleft", "trunk", "buyfood", "buyweapons" }) do
        check("has /" .. need, actions[need] ~= nil)
    end
    if actions.givemoney then
        local def = actions.givemoney.def
        local args = parse(def, { "250" })
        check("parse givemoney 250", args and args.amount == 250)
        local bad, _, why = parse(def, { "lots" })
        check("parse givemoney lots refused", bad == nil and why ~= nil)
        local none, _, why2 = parse(def, {})
        check("parse givemoney (nothing) refused", none == nil and why2 ~= nil)
    end
    -- The gate, on a vehicle made for it here.
    local fake = { reach = 5 }
    local v = createVehicle(400, 0, 0, 3)
    local v2 = createVehicle(400, 30, 0, 3)
    local ped = createPed(0, 1, 1, 3)
    if v and v2 and ped then
        local px = getElementPosition(ped)
        check("ped placed", px ~= nil)
        check("#id assigned", tidOf(v) > 0 and byTid[tidOf(v)] == v and getElementData(v, "vana:tid") == tidOf(v))
        local oneArg, target = parse({ params = {} }, { "#" .. tidOf(v) })
        check("parse #id", oneArg ~= nil and target == v)
        -- gate() needs a player; the console has none, so check its parts the same way.
        check("in reach", getDistanceBetweenPoints3D(0, 0, 3, getElementPosition(v)) <= fake.reach)
        check("out of reach", getDistanceBetweenPoints3D(0, 0, 3, getElementPosition(v2)) > fake.reach)
        if actions.engine then check("engine takes a car", takes(actions.engine, ped, v)) end
        if actions.givemoney then check("givemoney doesn't take a car", not takes(actions.givemoney, ped, v)) end
        -- Sitting in a car, only that car: the one alongside is never the target.
        if actions.hood and warpPedIntoVehicle(ped, v, 1) then
            check("from inside, the hood of your own car", takes(actions.hood, ped, v))
            check("from inside, not another car's hood", not takes(actions.hood, ped, v2))
            local pok, _, why = pcall(call, actions.hood.res, "runAction", "hood", ped, v, {})
            check("a passenger can't open the hood", pok and why == "Only the driver can do that.")
        end
    end
    for _, e in ipairs({ v, v2, ped }) do if isElement(e) then destroyElement(e) end end
    outputServerLog("[controlstest] " .. (ok and "PASS" or "FAIL"))
end)
