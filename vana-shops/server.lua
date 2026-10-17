-- Shops: Ammu-Nation, fast food, clothes (prices and stock from the retail shopping.dat) and our
-- 24/7 misc counters (config/shops.lua). Walk into a shop's marker to open its menu; every
-- purchase is checked and applied here, then saved (vana-player).
local prices = {}   -- section ("weapons", "food", "clothes") -> lowercase item name -> fields
local stock = {}    -- lowercase shop section -> { type, items = { names } }
local markers = {}  -- marker -> shop name
local open = {}     -- player -> shop name

local function readLines(path)
    local f = fileOpen(path, true)
    if not f then error("vana-shops: missing " .. path .. " (see docs/setup.md)") end
    local s = fileRead(f, fileGetSize(f))
    fileClose(f)
    return s:gmatch("[^\r\n]+")
end

local function loadShoppingDat()
    local path = {}
    for line in readLines("data/shopping.dat") do
        local l = line:gsub("#.*", "")
        local words = {}
        for w in l:gmatch("%S+") do words[#words + 1] = w end
        if words[1] == "section" then
            path[#path + 1] = words[2]:lower()
        elseif words[1] == "end" then
            path[#path] = nil
        elseif #words > 0 then
            if path[1] == "prices" and path[2] then
                prices[path[2]] = prices[path[2]] or {}
                prices[path[2]][words[1]:lower()] = words
            elseif path[1] == "shops" and path[2] then
                local shop = stock[path[2]] or { items = {} }
                stock[path[2]] = shop
                if words[1] == "type" then shop.type = words[2] elseif words[1] == "item" then shop.items[#shop.items + 1] = words[2]:lower() end
            end
        end
    end
end

local function prettify(name)
    return (name:gsub("_", " "):gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end))
end

local function playerCall(fn, ...)
    local res = getResourceFromName("vana-player")
    if not res or getResourceState(res) ~= "running" then return nil end
    local args = { ... }
    local ok, result = pcall(function() return exports["vana-player"][fn](exports["vana-player"], unpack(args)) end)
    return ok and result or nil
end

-- The menu for one shop and player: { key, label, price, category, owned } per item. Clothes carry
-- their apparel category (shopping.dat's clothes type) and whether the player already owns them,
-- plus a "take off" entry per category.
local function catalogue(shopName, player)
    local point = ShopPoints[shopName]
    local items = {}
    if point.kind == "misc" then
        for i, item in ipairs(ShopConfig.misc) do items[#items + 1] = { key = "misc" .. i, label = item.name, price = item.price } end
        return items
    end
    local shop = stock[shopName:lower()]
    if not shop then return items end
    for _, name in ipairs(shop.items) do
        local f
        if point.kind == "weapons" then f = prices.weapons[name]
        elseif point.kind == "food" then f = prices.food[name]
        else f = prices.clothes[name] end
        if f then
            -- Vanilla names: shopping.dat's nametag is a GXT key (field 2), e.g. VESTA -> "Black Tank".
            local label = Gxt.get(f[2])
            if not label and point.kind == "weapons" then label = getWeaponNameFromID(ShopConfig.weapons[name] or 0) end
            label = label or ShopConfig.foodNames[name] or prettify(name)
            local item = { key = name, label = label, price = ShopConfig.prices[name] or tonumber(f[#f]) or 0 }
            if point.kind == "clothes" then
                item.category = tonumber(f[4])
                item.owned = player and playerCall("isOwned", player, "clothes", name) or false
            end
            items[#items + 1] = item
        end
    end
    if point.kind == "clothes" then
        local categories = {}
        for _, item in ipairs(items) do categories[item.category] = true end
        for category in pairs(categories) do
            items[#items + 1] = { key = "takeoff:" .. category, label = "Take off", price = 0, category = category, owned = true, takeOff = true }
        end
    end
    return items
end

local function nearPoint(player, point)
    if getElementInterior(player) ~= point.interior then return false end
    local x, y, z = getElementPosition(player)
    return getDistanceBetweenPoints3D(x, y, z, point.x, point.y, point.z + 1) < ShopConfig.radius + 1.5
end

local function maxHealth(player)
    return 100 + (getPedStat(player, 24) - 569) * 76 / 431
end

-- Applies one purchase; returns false and a reason if it can't be done.
local function deliver(player, kind, key)
    if kind == "misc" then
        local item = ShopConfig.misc[tonumber(key:match("%d+"))]
        if not item then return false, "Not sold here." end
        giveWeapon(player, item.weapon, item.ammo, true)
    elseif kind == "weapons" then
        local f = prices.weapons[key]
        if key == "armour" then
            setPedArmor(player, 100)
        else
            local id = ShopConfig.weapons[key]
            if not id then return false, "Not sold here." end
            giveWeapon(player, id, tonumber(f[3]) or 1, true)
        end
    elseif kind == "food" then
        local f = prices.food[key]
        local stat, value = f[3], tonumber(f[4]) or 0
        local health = math.min(maxHealth(player), getElementHealth(player) + value)
        setElementHealth(player, health)
        if stat == "calories" then
            setPedStat(player, 21, math.min(1000, getPedStat(player, 21) + value * ShopConfig.fatPerCalorie))
        end
    elseif kind == "clothes" then
        if getElementModel(player) ~= 0 then return false, "Clothes only fit CJ." end
        local takeOff = tonumber(key:match("^takeoff:(%d+)$"))
        if takeOff then
            removePedClothes(player, takeOff)
        else
            local f = prices.clothes[key]
            addPedClothes(player, f[1], f[3], tonumber(f[4]))
        end
    end
    return true
end

local function savePlayer(player)
    local res = getResourceFromName("vana-player")
    if res and getResourceState(res) == "running" then pcall(function() exports["vana-player"]:savePlayer(player) end) end
end

addEvent("vana-shops:buy", true)
addEventHandler("vana-shops:buy", resourceRoot, function(key)
    local shopName = open[client]
    local point = shopName and ShopPoints[shopName]
    if not point or type(key) ~= "string" or not nearPoint(client, point) then return end
    local item
    for _, entry in ipairs(catalogue(shopName, client)) do
        if entry.key == key then item = entry break end
    end
    if not item then return end
    -- Owned clothes (and taking things off) are free: you're just putting them on.
    local price = item.owned and 0 or item.price
    if getPlayerMoney(client) < price then
        return triggerClientEvent(client, "vana-shops:result", resourceRoot, false, "Not enough money.")
    end
    local ok, reason = deliver(client, point.kind, key)
    if not ok then return triggerClientEvent(client, "vana-shops:result", resourceRoot, false, reason) end
    if price > 0 then takePlayerMoney(client, price) end
    if point.kind == "clothes" and not item.owned then playerCall("grantOwned", client, "clothes", key) end
    savePlayer(client)
    local verb = item.takeOff and "Took off" or item.owned and "Wearing" or "Bought"
    triggerClientEvent(client, "vana-shops:result", resourceRoot, true, verb .. ": " .. item.label, key, point.kind == "clothes")
end)

addEvent("vana-shops:close", true)
addEventHandler("vana-shops:close", resourceRoot, function() open[client] = nil end)

local function onMarkerHit(player, matching)
    if not matching or getElementType(player) ~= "player" or getPedOccupiedVehicle(player) or open[player] then return end
    local shopName = markers[source]
    local point = ShopPoints[shopName]
    if not point or getElementInterior(player) ~= point.interior then return end
    open[player] = shopName
    triggerClientEvent(player, "vana-shops:open", resourceRoot, shopName, point.kind, catalogue(shopName, player), ShopConfig.clothesCategories)
end

local pointMarkers = {}

local function placeMarker(shopName, point)
    if pointMarkers[shopName] then
        markers[pointMarkers[shopName]] = nil
        destroyElement(pointMarkers[shopName])
    end
    local marker = createMarker(point.x, point.y, point.z - 0.1, "cylinder", ShopConfig.radius, 255, 120, 0, 90)
    setElementInterior(marker, point.interior)
    markers[marker] = shopName
    pointMarkers[shopName] = marker
    addEventHandler("onMarkerHit", marker, onMarkerHit)
end

addEventHandler("onResourceStart", resourceRoot, function()
    loadShoppingDat()
    if not Gxt.load("data/american.gxt") then
        outputServerLog("[vana-shops] data/american.gxt missing or unreadable: menus fall back to internal names (see docs/setup.md)")
    end
    for shopName, point in pairs(ShopPoints) do placeMarker(shopName, point) end
end)

addEventHandler("onPlayerQuit", root, function() open[source] = nil end)

-- Admin: put a shop's point where you stand, and print the config line to keep it.
-- Restricted: needs command.shoppoint in the ACL.
addCommandHandler("shoppoint", function(player, _, name)
    if getElementType(player) ~= "player" then return end
    name = name and name:upper()
    local point = name and ShopPoints[name]
    if not point then return outputChatBox("Usage: /shoppoint <shop name, e.g. AMMUN1>", player, 255, 200, 50) end
    local x, y, z = getElementPosition(player)
    point.x, point.y, point.z, point.interior = x, y, z - 1, getElementInterior(player)
    placeMarker(name, point)
    local line = ('    %-10s = { kind = "%s", interior = %d, x = %.2f, y = %.2f, z = %.2f },'):format(name, point.kind, point.interior, point.x, point.y, point.z)
    outputServerLog("[vana-shops] new point (paste into config/points.lua): " .. line)
    outputChatBox("Shop point moved here. The config line is in the server log.", player, 120, 255, 120)
end, true)

-- Console-only: every shop point has a stock, every item a price.
addCommandHandler("shoptest", function(source)
    if getElementType(source) ~= "console" then return end
    local ok, total = true, 0
    for shopName, point in pairs(ShopPoints) do
        local items = catalogue(shopName)
        total = total + #items
        if #items == 0 then ok = false; outputServerLog("[shoptest] FAIL no stock for " .. shopName) end
        for _, item in ipairs(items) do
            if point.kind == "weapons" and item.key ~= "armour" and not ShopConfig.weapons[item.key] then
                ok = false; outputServerLog("[shoptest] FAIL unknown weapon " .. item.key)
            end
        end
    end
    local ammu = catalogue("AMMUN1")
    local binco = catalogue("CSCHP")
    local named = 0
    for _, item in ipairs(binco) do if item.label:find(" ") or item.label:match("^%u%l") then named = named + 1 end end
    outputServerLog(("[shoptest] GXT names: Binco sells %d, e.g. %s, %s, %s"):format(#binco, binco[1] and binco[1].label or "?",
        binco[5] and binco[5].label or "?", binco[14] and binco[14].label or "?"))
    ok = ok and Gxt.get("VESTA") == "Black Tank"
    -- Each clothes chain sells its own range, every item in a known apparel category.
    local known = {}
    for _, c in ipairs(ShopConfig.clothesCategories) do known[c.type] = true end
    local chains, sellers = {}, {}
    for shopName, point in pairs(ShopPoints) do
        if point.kind == "clothes" then
            local count = 0
            for _, item in ipairs(catalogue(shopName)) do
                if not item.takeOff then
                    count = count + 1
                    sellers[item.key] = (sellers[item.key] or 0) + 1
                    if not known[item.category] then ok = false; outputServerLog("[shoptest] FAIL unknown clothes category " .. tostring(item.category) .. " for " .. item.key) end
                end
            end
            chains[#chains + 1] = shopName .. " " .. count
        end
    end
    local exclusive = 0
    for _, n in pairs(sellers) do if n == 1 then exclusive = exclusive + 1 end end
    table.sort(chains)
    outputServerLog(("[shoptest] clothes chains: %s; %d items sold by only one chain"):format(table.concat(chains, ", "), exclusive))

    -- Every shopping.dat item should have a vanilla name.
    local missing = {}
    for _, section in ipairs({ "weapons", "food", "clothes" }) do
        for name, f in pairs(prices[section] or {}) do
            if not Gxt.get(f[2]) then missing[#missing + 1] = name .. "/" .. tostring(f[2]) end
        end
    end
    outputServerLog(("[shoptest] items without a GXT name: %d %s"):format(#missing, table.concat(missing, ", ")))
    outputServerLog(("[shoptest] %d shops, %d menu items; Ammu-Nation 1 sells %d (first: %s $%d)")
        :format(#(function() local t = {} for k in pairs(ShopPoints) do t[#t + 1] = k end return t end)(), total, #ammu, ammu[1] and ammu[1].label or "?", ammu[1] and ammu[1].price or 0))
    outputServerLog("[shoptest] " .. (ok and "PASS" or "FAIL"))
end)
