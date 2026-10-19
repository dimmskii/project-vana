-- Mod garages (vanilla CARMOD; config/garages.lua): stop in a doorway in a vehicle and it's taken into
-- the garage, alone (its own dimension), for upgrades, colours and paintjobs. Highlighted items are
-- tried on the car; leaving puts back what wasn't bought. Every purchase is checked and applied here;
-- the car's new parts are kept by vana-vehicles' persistence like the rest of it.
local G = GarageConfig
local prices = {}   -- shopping.dat CarMods: lowercase name -> { nametag, price }
local stock = {}    -- garage shop ("carmod1") -> { names }
local sessions = {} -- player -> { garage, index, vehicle, dimension, base, lock, occupants }
local busy = {}     -- doorway index -> player inside
local cleared = {}  -- player -> doorway index they just left (no way back in until they drive off it)
local nameOf = {}   -- upgrade ID -> name
for name, id in pairs(CarModIds) do nameOf[id] = name end

local function loadStock()
    local text = SA.readFile("data/shopping.dat")
    if not text then return end
    local root = SADat.sections(text)
    local section = root.sections.prices and root.sections.prices.sections.carmods
    for _, words in ipairs(section and section.rows or {}) do
        prices[words[1]:lower()] = { words[2], tonumber(words[#words]) }
    end
    for name, s in pairs(root.sections.shops and root.sections.shops.sections or {}) do
        if name:find("^carmod") then
            stock[name] = {}
            for _, words in ipairs(s.rows) do
                if words[1] == "item" then table.insert(stock[name], words[2]:lower()) end
            end
        end
    end
end

local function paintjobsOf(model)
    local res = getResourceFromName("vana-vehicles")
    if not res or getResourceState(res) ~= "running" then return 0 end
    local ok, n = pcall(function() return exports["vana-vehicles"]:getPaintjobCount(model) end)
    return ok and n or 0
end

-- What vana-vehicles keeps of a car in here: the doorway it leaves from, what it has bought.
local function markKept(s)
    local g, base, list = s.garage, s.base, {}
    for id in pairs(base.upgrades) do list[#list + 1] = id end
    setElementData(s.vehicle, "vana:garage", { pos = { g.x, g.y, g.z + 0.5 }, heading = g.exit, upgrades = list,
        paintjob = base.paintjob, colors = base.colours, locked = s.lock }, false)
end

local function say(player, text, ok)
    triggerClientEvent(player, "vana-garage:result", resourceRoot, ok, text)
end

-- What the car has: upgrades (ID -> true), paintjob, colours (12 RGB values).
local function stateOf(vehicle)
    local upgrades = {}
    for _, id in ipairs(getVehicleUpgrades(vehicle)) do upgrades[id] = true end
    return { upgrades = upgrades, paintjob = getVehiclePaintjob(vehicle), colours = { getVehicleColor(vehicle, true) } }
end

-- Back to the state it had (before the item tried on).
local function restore(vehicle, base)
    for _, id in ipairs(getVehicleUpgrades(vehicle)) do
        if not base.upgrades[id] then removeVehicleUpgrade(vehicle, id) end
    end
    for id in pairs(base.upgrades) do addVehicleUpgrade(vehicle, id) end
    if getVehiclePaintjob(vehicle) ~= base.paintjob then setVehiclePaintjob(vehicle, base.paintjob) end
    setVehicleColor(vehicle, unpack(base.colours))
end

-- The garage's menu for this vehicle: categories (upgrade slots, in slot order) of items, each
-- { key = ID, label, price, fits, owned }, then colours and paintjobs.
local function menuFor(s)
    local fits, seen, bySlot = {}, {}, {}
    for _, id in ipairs(getVehicleCompatibleUpgrades(s.vehicle)) do fits[id] = true end
    local names = {}
    for _, n in ipairs(stock[s.garage.shop] or {}) do names[#names + 1] = n end
    for _, n in ipairs(G.everywhere) do names[#names + 1] = n end
    for _, name in ipairs(names) do
        local id, price = CarModIds[name], prices[name]
        if id and price and not seen[id] then
            seen[id] = true
            local slot = getVehicleUpgradeSlotName(id)
            bySlot[slot] = bySlot[slot] or {}
            table.insert(bySlot[slot], { key = id, label = Gxt.get(price[1]) or name, price = price[2], fits = fits[id] == true,
                                         owned = s.base.upgrades[id] == true })
        end
    end
    local categories = {}
    for slot = 0, 16 do
        local name = getVehicleUpgradeSlotName(slot)
        if bySlot[name] then
            table.sort(bySlot[name], function(a, b) return a.price < b.price end)
            categories[#categories + 1] = { name = name, items = bySlot[name] }
        end
    end
    return { title = s.garage.name, categories = categories, palette = CarPalette, paintPrice = G.paintPrice,
             paintjobs = paintjobsOf(getElementModel(s.vehicle)), paintjob = s.base.paintjob,
             colours = s.base.colours }
end

local function freeDimension()
    local used = {}
    for _, s in pairs(sessions) do used[s.dimension] = true end
    local d = G.dimensionBase
    while used[d] do d = d + 1 end
    return d
end

local function moveVehicle(vehicle, occupants, interior, dimension, x, y, z, heading)
    setElementInterior(vehicle, interior)
    setElementDimension(vehicle, dimension)
    for _, occupant in pairs(occupants) do
        if isElement(occupant) then
            setElementInterior(occupant, interior)
            setElementDimension(occupant, dimension)
        end
    end
    setElementPosition(vehicle, x, y, z)
    setElementRotation(vehicle, 0, 0, heading)
    setElementVelocity(vehicle, 0, 0, 0)
    setElementAngularVelocity(vehicle, 0, 0, 0)
end

local function enter(player, vehicle, index)
    local garage = G.garages[index]
    if not G.vehicleTypes[getVehicleType(vehicle)] then return say(player, Gxt.get("MODNO2") or "You cannot mod this vehicle.") end
    if G.exclusive and busy[index] and busy[index] ~= player then return say(player, G.busyText) end
    local s = { garage = garage, index = index, vehicle = vehicle, dimension = freeDimension(), lock = isVehicleLocked(vehicle),
                occupants = getVehicleOccupants(vehicle), entering = true }
    sessions[player], busy[index] = s, player
    fadeCamera(player, false, 1)
    setTimer(function()
        if sessions[player] ~= s or not isElement(vehicle) then return end
        local i = garage.inside
        moveVehicle(vehicle, s.occupants, garage.interior, s.dimension, i[1], i[2], i[3], i[4])
        setElementFrozen(vehicle, true)
        setVehicleLocked(vehicle, true)
        s.base, s.entering = stateOf(vehicle), nil
        markKept(s)
        triggerClientEvent(player, "vana-garage:open", resourceRoot, menuFor(s))
        fadeCamera(player, true, 1)
    end, 1000, 1)
end

-- Out of the garage: what wasn't bought comes off, and the car is back in the doorway facing out.
-- `now`: at once (quitting, the resource stopping), no fade.
local function leave(player, now)
    local s = sessions[player]
    if not s then return end
    sessions[player], busy[s.index], cleared[player] = nil, nil, s.index
    local function out()
        local v, g = s.vehicle, s.garage
        if not isElement(v) then return end
        if s.base then restore(v, s.base) end
        removeElementData(v, "vana:garage")
        moveVehicle(v, s.occupants, 0, 0, g.x, g.y, g.z + 0.5, g.exit)
        setElementFrozen(v, false)
        setVehicleLocked(v, s.lock)
        if isElement(player) then
            triggerClientEvent(player, "vana-garage:close", resourceRoot)
            fadeCamera(player, true, 1)
        end
    end
    if now or not isElement(player) then return out() end
    fadeCamera(player, false, 1)
    setTimer(out, 1000, 1)
end

-- Trying an item on: kind "part" (ID), "colour" ({ slot 1 or 2, palette index }), "paintjob" (0-2);
-- nil: back to what the car has.
addEvent("vana-garage:preview", true)
addEventHandler("vana-garage:preview", resourceRoot, function(kind, value)
    local s = sessions[client]
    if not s or not s.base then return end
    restore(s.vehicle, s.base)
    if kind == "part" and type(value) == "number" then
        addVehicleUpgrade(s.vehicle, value)
    elseif kind == "colour" and type(value) == "table" then
        local c = CarPalette[(tonumber(value[2]) or -1) + 1]
        local slot = tonumber(value[1])
        if c and (slot == 1 or slot == 2) then
            local cols = { unpack(s.base.colours) }
            cols[slot * 3 - 2], cols[slot * 3 - 1], cols[slot * 3] = c[1], c[2], c[3]
            setVehicleColor(s.vehicle, unpack(cols))
        end
    elseif kind == "paintjob" and type(value) == "number" then
        setVehiclePaintjob(s.vehicle, value)
    end
end)

addEvent("vana-garage:buy", true)
addEventHandler("vana-garage:buy", resourceRoot, function(kind, value)
    local s = sessions[client]
    if not s or not s.base then return end
    local v, base = s.vehicle, s.base
    local price
    if kind == "part" then
        local name = nameOf[value]
        local p = name and prices[name]
        if not p then return end
        local fits = false
        for _, id in ipairs(getVehicleCompatibleUpgrades(v)) do fits = fits or id == value end
        if not fits then return say(client, Gxt.get("MODNO2") or "You cannot mod this vehicle.") end
        if base.upgrades[value] then return say(client, Gxt.get("CLTHNO2") or "You have already bought this item!") end
        price = p[2]
    elseif kind == "colour" or kind == "paintjob" then
        price = G.paintPrice
    else
        return
    end
    if getPlayerMoney(client) < price then return say(client, Gxt.get("SHOPNO") or "You don't have enough money to buy this item.") end
    restore(v, base)
    if kind == "part" then
        if not addVehicleUpgrade(v, value) then return say(client, Gxt.get("MODNO2") or "You cannot mod this vehicle.") end
        -- A part in a slot replaces the one there.
        base.upgrades = stateOf(v).upgrades
    elseif kind == "colour" then
        local c = type(value) == "table" and CarPalette[(tonumber(value[2]) or -1) + 1]
        local slot = type(value) == "table" and tonumber(value[1])
        if not c or (slot ~= 1 and slot ~= 2) then return end
        local i = slot * 3 - 2
        if base.colours[i] == c[1] and base.colours[i + 1] == c[2] and base.colours[i + 2] == c[3] then
            return say(client, Gxt.get("COLORNO") or "Your vehicle is already this color.")
        end
        base.colours[i], base.colours[i + 1], base.colours[i + 2] = c[1], c[2], c[3]
        setVehicleColor(v, unpack(base.colours))
    else
        local n = paintjobsOf(getElementModel(v))
        if type(value) ~= "number" or value < 0 or value >= n then return end
        if base.paintjob == value then return say(client, Gxt.get("CLTHNO2") or "You have already bought this item!") end
        setVehiclePaintjob(v, value)
        base.paintjob = value
    end
    takePlayerMoney(client, price)
    markKept(s)
    say(client, ("Bought for $%d."):format(price), true)
    triggerClientEvent(client, "vana-garage:open", resourceRoot, menuFor(s), true)
end)

addEvent("vana-garage:leave", true)
addEventHandler("vana-garage:leave", resourceRoot, function() leave(client) end)

-- Doorways: a driver stopped in one is taken in.
setTimer(function()
    for _, player in ipairs(getElementsByType("player")) do
        local v = getPedOccupiedVehicle(player)
        local inDoorway
        if v and getVehicleOccupant(v, 0) == player and getElementDimension(v) == 0 and getElementInterior(v) == 0 then
            local x, y, z = getElementPosition(v)
            for i, g in ipairs(G.garages) do
                if getDistanceBetweenPoints2D(x, y, g.x, g.y) < G.radius and math.abs(z - g.z) < 3 then inDoorway = i end
            end
            if inDoorway and cleared[player] ~= inDoorway and not sessions[player] then
                local vx, vy, vz = getElementVelocity(v)
                if (vx * vx + vy * vy + vz * vz) ^ 0.5 < G.stoppedSpeed then enter(player, v, inDoorway) end
            end
        end
        if cleared[player] and cleared[player] ~= inDoorway then cleared[player] = nil end
    end
end, 250, 0)

addEventHandler("onPlayerQuit", root, function() leave(source, true) cleared[source] = nil end)
addEventHandler("onPlayerWasted", root, function() leave(source, true) end)
addEventHandler("onVehicleExplode", root, function()
    for player, s in pairs(sessions) do if s.vehicle == source then leave(player, true) end end
end)
addEventHandler("onElementDestroy", root, function()
    if getElementType(source) ~= "vehicle" then return end
    for player, s in pairs(sessions) do if s.vehicle == source then leave(player, true) end end
end)
addEventHandler("onResourceStop", resourceRoot, function()
    for player in pairs(sessions) do leave(player, true) end
end)

addEventHandler("onResourceStart", resourceRoot, function()
    loadStock()
    local m = G.marker
    for i, g in ipairs(G.garages) do
        MapPoints.set("modgarage:" .. i, { category = "modgarage", x = g.x, y = g.y, z = g.z })
        -- The door stays up, and the spot to stop on is marked.
        if g.door then setGarageOpen(g.door, true) end
        createMarker(g.x, g.y, g.z - 0.6, "cylinder", m.size, m.colour[1], m.colour[2], m.colour[3], m.colour[4])
    end
end)

-- Console-only: stock and prices load, every part resolves to an ID, and a test car's menu builds.
addCommandHandler("garagetest", function(source)
    if getElementType(source) ~= "console" then return end
    local missing, counts = {}, {}
    for shop, names in pairs(stock) do
        counts[#counts + 1] = shop .. " " .. #names
        for _, n in ipairs(names) do if not CarModIds[n] or not prices[n] then missing[#missing + 1] = n end end
    end
    table.sort(counts)
    local car = createVehicle(536, 0, 0, -50) -- Blade (a lowrider)
    local cop = createVehicle(596, 5, 0, -50) -- police car
    local s = { garage = G.garages[4], vehicle = car, base = stateOf(car) }
    local m = menuFor(s)
    local fit, total = 0, 0
    for _, c in ipairs(m.categories) do for _, item in ipairs(c.items) do total = total + 1 if item.fits then fit = fit + 1 end end end
    local copFits = 0
    for _, id in ipairs(getVehicleCompatibleUpgrades(cop)) do if id == 1087 or id == 1010 or id == 1025 then copFits = copFits + 1 end end
    destroyElement(car)
    destroyElement(cop)
    outputServerLog(("[garagetest] stock: %s; unresolved: %s"):format(table.concat(counts, ", "), #missing == 0 and "none" or table.concat(missing, " ")))
    outputServerLog(("[garagetest] Blade at Loco Low Co.: %d categories, %d of %d items fit, %d paintjobs; police car takes hydraulics, nitro, wheels: %s")
        :format(#m.categories, fit, total, m.paintjobs, copFits == 3 and "yes" or "no"))
    outputServerLog("[garagetest] " .. ((#missing == 0 and fit > 0 and copFits == 3) and "PASS" or "FAIL"))
end)
