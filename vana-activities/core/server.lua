-- Activities: one session per player at a time (burglary, side jobs, schools, races, minigames). A
-- session owns what it spawns (vehicles, peds, objects, blips and markers only its player sees) and
-- cleans it all up when it ends. Activities register a definition; see docs/activities.md.
Activity = {}
local defs = {}      -- name -> definition
local sessions = {}  -- player -> session
local Session = {}
Session.__index = Session

local function call(resource, fn, ...)
    local res = getResourceFromName(resource)
    if not res or getResourceState(res) ~= "running" then return nil end
    local args = { ... }
    local results = { pcall(function() return exports[resource][fn](exports[resource], unpack(args)) end) }
    if not results[1] then return nil end
    return unpack(results, 2)
end
Activity.call = call

-- def: { title = GXT key or text, gxt = mission GXT table, start = fn(session, ...), stop = fn(session, reason),
--        launch = { vehicles = { model = true }, help = key, check = fn(player, vehicle) -> ok, reasonKey } }
function Activity.register(name, def)
    def.name = name
    defs[name] = def
end

function Activity.of(player)
    return sessions[player]
end

-- Text by GXT key (this activity's table, then MAIN) with ~1~ numbers filled in; plain text passes through.
function Activity.text(key, tableName, ...)
    local s = Gxt.raw(key, tableName)
    return Gxt.format(s or key, ...)
end

function Activity.start(player, name, ...)
    local def = defs[name]
    if not def or sessions[player] or not isElement(player) or isPedDead(player) then return false end
    local session = setmetatable({ player = player, name = name, def = def, owned = {}, timers = {}, data = {},
        counters = {}, started = getTickCount() }, Session)
    sessions[player] = session
    triggerClientEvent(player, "vana-activities:session", resourceRoot, name)
    local ok, err = pcall(def.start, session, ...)
    if not ok then
        outputDebugString(("[vana-activities] %s failed to start: %s"):format(name, tostring(err)), 1)
        session:stop("error")
        return false
    end
    return true
end

function Session:active()
    return sessions[self.player] == self
end

function Session:text(key, ...)
    return Activity.text(key, self.def.gxt, ...)
end

-- Ends the session: the definition's stop hook runs first, then everything it owns goes.
function Session:stop(reason)
    if sessions[self.player] ~= self then return end
    sessions[self.player] = nil
    if self.def.stop then
        local ok, err = pcall(self.def.stop, self, reason)
        if not ok then outputDebugString(("[vana-activities] %s stop: %s"):format(self.name, tostring(err)), 1) end
    end
    for _, t in ipairs(self.timers) do if isTimer(t) then killTimer(t) end end
    for i = #self.owned, 1, -1 do
        if isElement(self.owned[i]) then destroyElement(self.owned[i]) end
    end
    if isElement(self.player) then triggerClientEvent(self.player, "vana-activities:session", resourceRoot, nil) end
end

-- Vanilla's "MISSION PASSED" / "MISSION FAILED" style endings. money is paid out with the message.
function Session:pass(textKey, money, ...)
    if money and money > 0 then givePlayerMoney(self.player, money) end
    self:big(textKey and self:text(textKey, ...) or "~y~MISSION PASSED!", 5000, "passed", money)
    self:stop("passed")
end

function Session:fail(textKey, ...)
    self:big(textKey and self:text(textKey, ...) or "~r~MISSION FAILED!", 5000, "failed")
    self:stop("failed")
end

-- Owned elements (destroyed with the session).
function Session:own(element)
    if element then self.owned[#self.owned + 1] = element end
    return element
end

function Session:disown(element)
    for i, e in ipairs(self.owned) do
        if e == element then table.remove(self.owned, i) return element end
    end
    return element
end

function Session:vehicle(model, x, y, z, rz)
    return self:own(createVehicle(model, x, y, z, 0, 0, rz or 0))
end

function Session:ped(model, x, y, z, rz)
    return self:own(createPed(model, x, y, z, rz or 0))
end

function Session:object(model, x, y, z, rx, ry, rz)
    return self:own(createObject(model, x, y, z, rx or 0, ry or 0, rz or 0))
end

-- A radar blip only this session's player sees: on an element, or at a position (x, y, z).
function Session:blip(target, icon, r, g, b, size)
    local blip
    if isElement(target) then
        blip = createBlipAttachedTo(target, icon or 0, size or 2, r or 255, g or 255, b or 0, 255, 0, 16383, self.player)
    else
        blip = createBlip(target[1], target[2], target[3], icon or 0, size or 2, r or 255, g or 255, b or 0, 255, 0, 16383, self.player)
    end
    return self:own(blip)
end

-- A marker only this session's player sees.
function Session:marker(kind, x, y, z, size, r, g, b, a)
    return self:own(createMarker(x, y, z, kind, size or 1.5, r or 255, g or 255, b or 0, a or 150, self.player))
end

-- Timers die with the session; fn gets the session.
function Session:after(ms, fn)
    local t = setTimer(function() if self:active() then fn(self) end end, math.max(50, ms), 1)
    self.timers[#self.timers + 1] = t
    return t
end

function Session:every(ms, fn)
    local t = setTimer(function() if self:active() then fn(self) end end, ms, 0)
    self.timers[#self.timers + 1] = t
    return t
end

-- HUD (core/client.lua draws it). styles: "title", "passed", "failed", "small".
function Session:big(text, ms, style, money)
    triggerClientEvent(self.player, "vana-activities:big", resourceRoot, text, ms or 4000, style or "title", money)
end

-- A subtitle-style objective (vanilla print / print_now).
function Session:say(text, ms)
    triggerClientEvent(self.player, "vana-activities:say", resourceRoot, text, ms or 5000)
end

-- The help box; forever keeps it until replaced or cleared (nil text).
function Session:help(text, forever)
    triggerClientEvent(self.player, "vana-activities:help", resourceRoot, text, forever)
end

-- On-screen counters (vanilla display_onscreen_counter / timer). kind: "number", "bar" (0-100),
-- "money" or "timer" (value = ms left; counts down on the client unless `up`).
function Session:counter(id, label, value, kind, up)
    self.counters[id] = true
    triggerClientEvent(self.player, "vana-activities:counter", resourceRoot, id, label, value, kind or "number", up)
end

function Session:clearCounter(id)
    self.counters[id] = nil
    triggerClientEvent(self.player, "vana-activities:counter", resourceRoot, id, nil)
end

-- Saved progress (vana-player): levels, totals, records and perks per player.
function Activity.progress(player, key)
    return call("vana-player", "getProgress", player, key)
end

function Activity.setProgress(player, key, value)
    return call("vana-player", "setProgress", player, key, value)
end

function Activity.save(player)
    return call("vana-player", "savePlayer", player)
end

-- Perks (vanilla's permanent rewards): name -> fn(player) applied on every spawn once earned.
local perks = {}
function Activity.perk(name, apply)
    perks[name] = apply
end

function Activity.hasPerk(player, name)
    return Activity.progress(player, "perk." .. name) == true
end

-- The client knows its player's perks (some act there, e.g. fireproof).
local function sendPerks(player)
    local held = {}
    for name in pairs(perks) do held[name] = Activity.hasPerk(player, name) or nil end
    triggerClientEvent(player, "vana-activities:perks", resourceRoot, held)
end

function Activity.grantPerk(player, name)
    if Activity.hasPerk(player, name) then return false end
    Activity.setProgress(player, "perk." .. name, true)
    if perks[name] then perks[name](player) end
    sendPerks(player)
    return true
end

addEventHandler("onPlayerSpawn", root, function()
    local player = source
    -- After vana-player has applied the saved record.
    setTimer(function()
        if not isElement(player) then return end
        for name, apply in pairs(perks) do
            if Activity.hasPerk(player, name) then apply(player) end
        end
        sendPerks(player)
    end, 500, 1)
end)

-- A private dimension per player for instanced places (burglary houses, and so on).
local dimensionOf, nextDimension = {}, 0
function Activity.dimension(player)
    if not dimensionOf[player] then
        nextDimension = nextDimension + 1
        dimensionOf[player] = ActivityConfig.privateDimensionBase + nextDimension
    end
    return dimensionOf[player]
end

-- Launching from a vehicle: the sub-mission key (vanilla R3 / PC "2") in the right vehicle starts the
-- job; pressed again during it, it ends the job.
local helped = {} -- player -> { [name] = true } (vehicle help shown once per spawn)

local function launcherFor(vehicle)
    local model = getElementModel(vehicle)
    for name, def in pairs(defs) do
        if def.launch and def.launch.vehicles and def.launch.vehicles[model] then return name, def end
    end
end

addEvent("vana-activities:submission", true)
addEventHandler("vana-activities:submission", resourceRoot, function()
    local player = client
    local session = sessions[player]
    if session then
        if session.def.launch then session:fail(session.def.cancelText) end
        return
    end
    local vehicle = getPedOccupiedVehicle(player)
    if not vehicle or getVehicleController(vehicle) ~= player then return end
    local name, def = launcherFor(vehicle)
    if not name then return end
    if def.launch.check then
        local ok, why = def.launch.check(player, vehicle)
        if not ok then
            if why then triggerClientEvent(player, "vana-activities:say", resourceRoot, Activity.text(why, def.gxt), 3000) end
            return
        end
    end
    Activity.start(player, name, vehicle)
end)

addEventHandler("onPlayerVehicleEnter", root, function(vehicle, seat)
    if seat ~= 0 or sessions[source] then return end
    local name, def = launcherFor(vehicle)
    if not name or not def.launch.help then return end
    helped[source] = helped[source] or {}
    if helped[source][name] then return end
    helped[source][name] = true
    triggerClientEvent(source, "vana-activities:help", resourceRoot, Activity.text(def.launch.help, def.gxt), false)
end)

addEventHandler("onPlayerWasted", root, function()
    local session = sessions[source]
    if session then session:fail(session.def.wastedText) end
end)

addEventHandler("onPlayerQuit", root, function()
    local session = sessions[source]
    if session then session:stop("quit") end
    helped[source], dimensionOf[source] = nil, nil
end)

addEventHandler("onResourceStart", resourceRoot, function()
    if not Gxt.load() then
        outputServerLog("[vana-activities] data/american.gxt missing: activity text falls back to keys (see docs/setup.md)")
    end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for _, session in pairs(sessions) do session:stop("stopped") end
end)

-- Street spots from the retail path network (vana-paths): a node of `kind` ("vehicle" or "ped") near a
-- random point minD..maxD from (x, y), on the same connected road network (flood fill) as `from`'s
-- nearest car node when given. Returns x, y, z or nil.
function Activity.streetSpot(x, y, z, minD, maxD, kind, sameNetworkAs)
    local flood
    if sameNetworkAs then
        local fa, fi = call("vana-paths", "findNearestNode", sameNetworkAs[1], sameNetworkAs[2], sameNetworkAs[3], "vehicle", 80)
        local node = fa and call("vana-paths", "getNode", fa, fi)
        flood = node and node.floodFill
    end
    for _ = 1, 16 do
        local a, d = math.random() * math.pi * 2, minD + math.random() * (maxD - minD)
        local px, py = x + math.cos(a) * d, y + math.sin(a) * d
        local area, id = call("vana-paths", "findNearestNode", px, py, z, kind or "vehicle", 120)
        if not area then
            area, id = call("vana-paths", "findNearestNode", px, py, 0, kind or "vehicle", 200)
        end
        local node = area and call("vana-paths", "getNode", area, id)
        if node then
            local ok = true
            if flood and kind ~= "ped" then ok = node.floodFill == flood end
            local nd = getDistanceBetweenPoints2D(x, y, node.x, node.y)
            if ok and nd >= minD * 0.7 and nd <= maxD * 1.3 then return node.x, node.y, node.z end
        end
    end
end

-- Pick lists (core/client.lua): Activity.menu(player, title, items, onChoose(player, index), hint).
local menus = {} -- player -> { id, onChoose }
local menuId = 0
function Activity.menu(player, title, items, onChoose, hint)
    menuId = menuId + 1
    menus[player] = { id = menuId, onChoose = onChoose, count = #items }
    triggerClientEvent(player, "vana-activities:menu", resourceRoot, menuId, title, items, hint)
end

addEvent("vana-activities:menuChoice", true)
addEventHandler("vana-activities:menuChoice", resourceRoot, function(id, index)
    local m = menus[client]
    if not m or m.id ~= id or type(index) ~= "number" or index < 1 or index > m.count then return end
    menus[client] = nil
    m.onChoose(client, index)
end)

addEventHandler("onPlayerQuit", root, function() menus[source] = nil end)
