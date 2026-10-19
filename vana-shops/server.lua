-- Shops: Ammu-Nation, fast food, clothes (prices and stock from the retail shopping.dat) and our
-- 24/7 misc counters (config/shops.lua). Walk into a shop's marker to open its menu; every
-- purchase is checked and applied here, then saved (vana-player).
local prices = {}   -- section ("weapons", "food", "clothes") -> lowercase item name -> fields
local stock = {}    -- lowercase shop section -> { type, items = { names } }
local markers = {}  -- marker -> shop name
local open = {}     -- player -> shop name

-- shopping.dat: "section prices" > one section per kind (weapons, food, clothes...) of item rows,
-- and "section shops" > one section per shop with its type and items. Read with sa_dat.lua.
local function loadShoppingDat()
    local text = SA.readFile("data/shopping.dat")
    if not text then error("vana-shops: missing data/shopping.dat (see docs/setup.md)") end
    local root = SADat.sections(text)
    for name, section in pairs(root.sections.prices and root.sections.prices.sections or {}) do
        for _, words in ipairs(section.rows) do
            prices[name] = prices[name] or {}
            prices[name][words[1]:lower()] = words
        end
    end
    for name, section in pairs(root.sections.shops and root.sections.shops.sections or {}) do
        for _, words in ipairs(section.rows) do
            local shop = stock[name] or { items = {} }
            stock[name] = shop
            if words[1] == "type" then shop.type = words[2] elseif words[1] == "item" then shop.items[#shop.items + 1] = words[2]:lower() end
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
local closetPoint = { kind = "closet" }

local function catalogue(shopName, player)
    local point = shopName == "CLOSET" and closetPoint or ShopPoints[shopName]
    local items = {}
    if point.kind == "closet" then
        -- Every clothing item the player owns, all chains combined, by category.
        for _, name in ipairs(player and playerCall("getOwned", player, "clothes") or {}) do
            local f = prices.clothes[name]
            if f then
                items[#items + 1] = { key = name, label = Gxt.get(f[2]) or prettify(name), price = 0, category = tonumber(f[4]), owned = true }
            end
        end
        for _, name in ipairs(player and playerCall("getOwned", player, "special") or {}) do
            local s = ShopConfig.specialClothes[name]
            if s then items[#items + 1] = { key = "special:" .. name, label = s.name, price = 0, category = 17, owned = true } end
        end
        table.sort(items, function(a, b) return a.label < b.label end)
        local categories = {}
        for _, item in ipairs(items) do categories[item.category] = true end
        for _, c in ipairs(ShopConfig.clothesCategories) do
            items[#items + 1] = { key = "takeoff:" .. c.type, label = "Take off", price = 0, category = c.type, owned = true, takeOff = true }
        end
        return items
    end
    if point.kind == "fighting" then
        -- This gym's style, any other style the player has learned, and the default.
        local learned = {}
        for _, name in ipairs(player and playerCall("getOwned", player, "styles") or {}) do learned[name] = true end
        for _, style in ipairs(ShopConfig.fightingStyles) do
            if style.style == point.style or learned[tostring(style.style)] or style.default then
                local owned = style.default or learned[tostring(style.style)] or false
                items[#items + 1] = { key = "style" .. style.style, label = style.name, price = 0, owned = owned }
            end
        end
        return items
    end
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
        elseif point.kind == "hair" then f = prices.haircuts[name]
        elseif point.kind == "tattoo" then f = prices.tattoos[name]
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
            elseif point.kind == "tattoo" then
                item.category = tonumber(f[3]) -- body part
            end
            items[#items + 1] = item
        end
    end
    if point.kind == "tattoo" then
        -- Tattoos are paid for each time, as in vanilla; each body part can have its tattoo removed.
        local parts = {}
        for _, item in ipairs(items) do parts[item.category] = true end
        for part in pairs(parts) do
            items[#items + 1] = { key = "takeoff:" .. part, label = "Remove tattoo", price = 0, category = part, owned = true, takeOff = true }
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
    elseif kind == "hair" then
        if getElementModel(player) ~= 0 then return false, "Only CJ can get a haircut here." end
        local f = prices.haircuts[key]
        addPedClothes(player, f[1], f[3], tonumber(f[4]))
    elseif kind == "tattoo" then
        if getElementModel(player) ~= 0 then return false, "Only CJ can get a tattoo here." end
        local part = tonumber(key:match("^takeoff:(%d+)$"))
        if part then
            removePedClothes(player, part)
        else
            -- A tattoo's model is its texture name; its clothes slot is the body part.
            local f = prices.tattoos[key]
            addPedClothes(player, f[1], f[1], tonumber(f[3]))
        end
    elseif kind == "fighting" then
        local id = tonumber(key:match("^style(%d+)$"))
        local style
        for _, s in ipairs(ShopConfig.fightingStyles) do if s.style == id then style = s end end
        if not style then return false, "Not taught here." end
        local learned = style.default or playerCall("isOwned", player, "styles", tostring(id))
        if not learned and getPedStat(player, 23) < ShopConfig.fightingMinMuscle then
            return false, ("You need more muscle (%d%%) to learn this."):format(ShopConfig.fightingMinMuscle / 10)
        end
        setPedFightingStyle(player, id)
        if not learned then playerCall("grantOwned", player, "styles", tostring(id)) end
    elseif kind == "clothes" or kind == "closet" then
        if getElementModel(player) ~= 0 then return false, "Clothes only fit CJ." end
        local special = key:match("^special:(.+)$")
        if special then
            local s = ShopConfig.specialClothes[special]
            if kind ~= "closet" or not s or not playerCall("isOwned", player, "special", special) then return false, "You don't own that." end
            addPedClothes(player, s.texture, s.model, 17)
            return true
        end
        if kind == "closet" and not key:match("^takeoff:") and not playerCall("isOwned", player, "clothes", key) then
            return false, "You don't own that."
        end
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

-- Sex appeal (0-1000) from what the player wears: shopping.dat's "sexy" value of each worn item
-- (clothes, haircut, tattoos), times sexAppealPerPoint. Vanilla keeps a stat fed by its shops; MTA
-- doesn't, so we work it out. Used by dating.
local function sexyOf(words)
    for i, w in ipairs(words or {}) do
        if w == "sexy" then return tonumber(words[i + 1]) or 0 end
    end
    return 0
end

function getSexAppeal(player)
    if not isElement(player) or getElementModel(player) ~= 0 then return 0 end
    local points = 0
    for slot = 0, 17 do
        local texture = getPedClothes(player, slot)
        if texture then
            texture = texture:lower()
            local f = prices.clothes and prices.clothes[texture]
            if slot == 1 then
                for _, h in pairs(prices.haircuts or {}) do if h[1]:lower() == texture then f = h break end end
            elseif slot >= 4 and slot <= 12 then
                f = prices.tattoos and prices.tattoos[texture] or f
            end
            points = points + sexyOf(f)
        end
    end
    return math.min(1000, points * ShopConfig.sexAppealPerPoint)
end

local function savePlayer(player)
    local res = getResourceFromName("vana-player")
    if res and getResourceState(res) == "running" then pcall(function() exports["vana-player"]:savePlayer(player) end) end
end

-- Closets: the changing room safehouse closet doors lead into. Arriving there opens the closet.
local closets = {} -- player -> point where they arrived

-- Trying things on: wearable menus snapshot the player's clothes when they open, previews are
-- applied on top of it, and closing puts the snapshot back. A purchase becomes the new snapshot.
local WEARABLE = { clothes = true, closet = true, hair = true, tattoo = true }
local outfits = {} -- player -> { [slot] = { texture, model } }

local function snapshotClothes(player)
    local outfit = {}
    for slot = 0, 17 do
        local texture, model = getPedClothes(player, slot)
        if texture then outfit[slot] = { texture, model } end
    end
    outfits[player] = outfit
end

local function restoreClothes(player)
    local outfit = outfits[player]
    if not outfit or getElementModel(player) ~= 0 then return end
    for slot = 0, 17 do
        local texture, model = getPedClothes(player, slot)
        local want = outfit[slot]
        if not want then
            if texture then removePedClothes(player, slot) end
        elseif texture ~= want[1] or model ~= want[2] then
            addPedClothes(player, want[1], want[2], slot)
        end
    end
end

local function openMenu(player, shopName, kind, categories)
    local seated, why = keeperSeat(player, shopName)
    if not seated then return outputChatBox(why, player, 255, 200, 120) end
    open[player] = shopName
    if WEARABLE[kind] and getElementModel(player) == 0 then snapshotClothes(player) else outfits[player] = nil end
    triggerClientEvent(player, "vana-shops:open", resourceRoot, shopName, kind, catalogue(shopName, player), categories)
end

local function closeMenu(player, instant)
    restoreClothes(player)
    open[player], outfits[player] = nil, nil
    keeperLeave(player, instant)
end

-- A customer whose shop is being robbed: out of the menu at once (keepers.lua).
function interruptCustomer(player)
    if open[player] then
        closeMenu(player, true)
        triggerClientEvent(player, "vana-shops:closeMenu", resourceRoot)
    end
end

addEvent("vana-shops:preview", true)
addEventHandler("vana-shops:preview", resourceRoot, function(key)
    local shopName = open[client]
    local point = shopName == "CLOSET" and closets[client] or shopName and ShopPoints[shopName]
    if not point then return end
    local item
    for _, entry in ipairs(type(key) == "string" and catalogue(shopName, client) or {}) do
        if entry.key == key then item = entry break end
    end
    keeperBrowse(client, item)
    if not outfits[client] then return end
    restoreClothes(client)
    if item then deliver(client, point.kind, key) end
end)

addEventHandler("onPlayerUseEntrance", root, function(name, _, toInterior, atHub)
    if name ~= ShopConfig.closetEntrance or not atHub then return end
    local player = source
    local x, y, z = getElementPosition(player)
    closets[player] = { kind = "closet", interior = toInterior, x = x, y = y, z = z - 1 }
    openMenu(player, "CLOSET", "closet", ShopConfig.clothesCategories)
end)

addEvent("vana-shops:buy", true)
addEventHandler("vana-shops:buy", resourceRoot, function(key)
    local shopName = open[client]
    local point = shopName == "CLOSET" and closets[client] or shopName and ShopPoints[shopName]
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
    if outfits[client] then snapshotClothes(client) end
    keeperBought(client, item)
    savePlayer(client)
    local verb = item.takeOff and point.kind == "tattoo" and "Removed" or point.kind == "fighting" and (item.owned and "Fighting style" or "Learned") or item.takeOff and "Took off" or item.owned and "Wearing" or "Bought"
    triggerClientEvent(client, "vana-shops:result", resourceRoot, true, verb .. ": " .. item.label, key, point.kind == "clothes" or point.kind == "fighting")
end)

-- Vending machines and food carts ([data]/vana-data-shops/shops.map, config/vendorkinds.lua).
local lastVend = {}
addEvent("vana-shops:vend", true)
addEventHandler("vana-shops:vend", resourceRoot, function(index)
    local v = type(index) == "number" and Vendors[index]
    local kind = v and VendorKinds[v.kind]
    if not kind or getPedOccupiedVehicle(client) or isPedDead(client) or getElementInterior(client) ~= v.interior then return end
    local x, y, z = getElementPosition(client)
    if getDistanceBetweenPoints3D(x, y, z, v.x, v.y, v.z) > VendorReach + 2 then return end
    local now = getTickCount()
    if lastVend[client] and now - lastVend[client] < 3000 then return end
    lastVend[client] = now
    if getPlayerMoney(client) < kind.price then return outputChatBox("You can't afford that.", client, 255, 120, 120) end
    takePlayerMoney(client, kind.price)
    setElementHealth(client, math.min(maxHealth(client), getElementHealth(client) + kind.health))
    if kind.fat ~= 0 then setPedStat(client, 21, math.min(1000, math.max(0, getPedStat(client, 21) + kind.fat))) end
    setPedAnimation(client, kind.anim[1], kind.anim[2], 2500, false, false, false, false)
    savePlayer(client)
end)

addEvent("vana-shops:close", true)
addEventHandler("vana-shops:close", resourceRoot, function() closeMenu(client) end)

local function onMarkerHit(player, matching)
    if not matching or getElementType(player) ~= "player" or getPedOccupiedVehicle(player) or open[player] then return end
    local shopName = markers[source]
    local point = ShopPoints[shopName]
    if not point or getElementInterior(player) ~= point.interior then return end
    local categories = point.kind == "tattoo" and ShopConfig.tattooCategories or ShopConfig.clothesCategories
    openMenu(player, shopName, point.kind, categories)
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

addEventHandler("onPlayerQuit", root, function()
    keeperLeave(source, true)
    open[source], closets[source], lastVend[source], outfits[source] = nil, nil, nil, nil
end)
addEventHandler("onPlayerWasted", root, function() if open[source] then closeMenu(source, true) end end)

-- Admin: put a shop's point where you stand, and print the map element to keep it (or move it in
-- the Map Editor: vana-data-shops).
-- Restricted: needs command.shoppoint in the ACL.
addCommandHandler("shoppoint", function(player, _, name)
    if getElementType(player) ~= "player" then return end
    name = name and name:upper()
    local point = name and ShopPoints[name]
    if not point then return outputChatBox("Usage: /shoppoint <shop name, e.g. AMMUN1>", player, 255, 200, 50) end
    local x, y, z = getElementPosition(player)
    point.x, point.y, point.z, point.interior = x, y, z - 1, getElementInterior(player)
    placeMarker(name, point)
    local attrs = {}
    for _, a in ipairs(MapData.toAttributes(MapDatasets.shops.types[1], { name = name, kind = point.kind, style = point.style,
        note = point.note, interior = point.interior, x = point.x, y = point.y, z = point.z })) do
        attrs[#attrs + 1] = ('%s="%s"'):format(a[1], a[2])
    end
    outputServerLog("[vana-shops] new point (replace it in [data]/vana-data-shops/shops.map): <shoppoint " .. table.concat(attrs, " ") .. " />")
    outputChatBox("Shop point moved here. The map element is in the server log.", player, 120, 255, 120)
end, true)

-- Console-only: every shop point has a stock, every item a price.
addCommandHandler("shoptest", function(source)
    if getElementType(source) ~= "console" then return end
    local ok, total = true, 0
    for shopName, point in pairs(ShopPoints) do
        local items = catalogue(shopName)
        total = total + #items
        if #items == 0 and point.kind ~= "fighting" then ok = false; outputServerLog("[shoptest] FAIL no stock for " .. shopName) end
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

    local barber, tattoo = catalogue("BARBERS"), catalogue("TATTOO")
    outputServerLog(("[shoptest] barber sells %d (e.g. %s $%d), tattoo parlour %d (e.g. %s $%d)"):format(#barber,
        barber[2] and barber[2].label or "?", barber[2] and barber[2].price or 0, #tattoo, tattoo[1] and tattoo[1].label or "?", tattoo[1] and tattoo[1].price or 0))
    ok = ok and #barber > 0 and #tattoo > 0
    local vendorKinds = {}
    for _, v in ipairs(Vendors) do
        if not VendorKinds[v.kind] then ok = false; outputServerLog("[shoptest] FAIL unknown vendor kind " .. v.kind) end
        vendorKinds[v.kind] = (vendorKinds[v.kind] or 0) + 1
    end
    local summary = {}
    for kind, n in pairs(vendorKinds) do summary[#summary + 1] = kind .. " " .. n end
    table.sort(summary)
    outputServerLog(("[shoptest] vendors: %d (%s)"):format(#Vendors, table.concat(summary, ", ")))
    local alive, staffed = keeperStatus()
    if alive ~= staffed then ok = false end
    outputServerLog(("[shoptest] keepers: %d of %d in place"):format(alive, staffed))
    -- Every shopping.dat item should have a vanilla name.
    local missing = {}
    for _, section in ipairs({ "weapons", "food", "clothes", "haircuts", "tattoos" }) do
        for name, f in pairs(prices[section] or {}) do
            if not Gxt.get(f[2]) then missing[#missing + 1] = name .. "/" .. tostring(f[2]) end
        end
    end
    outputServerLog(("[shoptest] items without a GXT name: %d %s"):format(#missing, table.concat(missing, ", ")))
    outputServerLog(("[shoptest] %d shops, %d menu items; Ammu-Nation 1 sells %d (first: %s $%d)")
        :format(#(function() local t = {} for k in pairs(ShopPoints) do t[#t + 1] = k end return t end)(), total, #ammu, ammu[1] and ammu[1].label or "?", ammu[1] and ammu[1].price or 0))
    outputServerLog("[shoptest] " .. (ok and "PASS" or "FAIL"))
end)
