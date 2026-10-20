-- Shopkeepers (config/keepers.lua): the vanilla shop scripts' staff, standing where vanilla puts them
-- and playing its animations while a customer is served. One customer per shop at a time. What a keeper
-- holds (a weapon, a meal) is the ped's "vana:holding" model; keepers_client.lua puts it in the hand.
local staff = {}    -- shopName -> ped
local props = {}    -- shopName -> object (tattoo kit, changing room door)
local serving = {}  -- shopName -> player
local customers = {} -- player -> { shop, layout, part, token }
local robberies = {} -- shopName -> robbery in progress (see Robbery, below)
local meals = {}     -- player -> ticks of food bought (the last game day's)

-- Vanilla junk food: CJ eats on the way out (EAT_Burger/Pizza/Chicken, 5 s), and from the 11th item
-- in a game day throws it all back up instead (EAT_Vomit_P, 8 s): that meal's health and fat are
-- undone, and 10 health more is lost.
local EAT_MS, VOMIT_MS, MEALS_PER_DAY = 5000, 8000, 10

local function mealsToday(player)
    local day = 24 * 60 * getMinuteDuration()
    local list, now = meals[player] or {}, getTickCount()
    for i = #list, 1, -1 do
        if now - list[i] > day then table.remove(list, i) end
    end
    meals[player] = list
    return list
end

local function spot(shopName, point)
    local o = Keepers[shopName].offset
    return point[1] + o[1], point[2] + o[2], point[3] + o[3], point[4]
end

local function play(ped, lib, name, loop)
    if isElement(ped) then setPedAnimation(ped, lib, name, -1, loop or false, false, false, true) end
end

local function stand(ped)
    if isElement(ped) then setPedAnimation(ped) end
end

local function hold(ped, model)
    if isElement(ped) then setElementData(ped, "vana:holding", model or false) end
end

local function camera(player, shopName, cam)
    local o = Keepers[shopName].offset
    triggerClientEvent(player, "vana-shops:camera", resourceRoot, { cam[1] + o[1], cam[2] + o[2], cam[3] + o[3], cam[4] + o[1], cam[5] + o[2], cam[6] + o[3] })
end

-- Fires fn after ms unless the shop has a new customer by then (their service owns the keeper).
local function afterLeaving(shopName, ms, fn)
    setTimer(function() if not serving[shopName] then fn() end end, ms, 1)
end

-- Runs fn after ms unless the customer's visit moved on since (a newer step or leaving).
local function later(player, ms, fn)
    local c = customers[player]
    local token = c and c.token
    setTimer(function()
        local now = customers[player]
        if now and now.token == token then fn(now) end
    end, ms, 1)
end

local function step(player)
    local c = customers[player]
    c.token = c.token + 1
    return c
end

-- What each layout's staff and customer do: idle, sit down, browse an item, buy, get up.
local Flows = {}

Flows.hair = {
    idle = function(ped) play(ped, "HAIRCUTS", "BRB_Loop", true) end,
    sit = function(player, ped)
        play(player, "HAIRCUTS", "BRB_Sit_In")
        later(player, 2070, function() play(player, "HAIRCUTS", "BRB_Sit_Loop", true) end)
    end,
    browse = function(player, ped, entry)
        step(player)
        if not entry then return end
        play(ped, "HAIRCUTS", "BRB_Cut_In")
        later(player, 830, function() play(ped, "HAIRCUTS", "BRB_Cut") end)
        later(player, 830 + 1700, function() play(ped, "HAIRCUTS", "BRB_Cut_Out") end)
        later(player, 830 + 1700 + 1330, function() Flows.hair.idle(ped) end)
    end,
    buy = function(player, ped, entry)
        step(player)
        local mirror = KeeperLayouts.hair.beards[entry.key] and "BRB_Beard_01" or (math.random(2) == 1 and "BRB_Hair_01" or "BRB_Hair_02")
        play(ped, "HAIRCUTS", "BRB_Buy")
        play(player, "HAIRCUTS", mirror)
        later(player, 4170, function() Flows.hair.idle(ped) end)
        later(player, mirror == "BRB_Hair_01" and 3830 or 4500, function() play(player, "HAIRCUTS", "BRB_Sit_Loop", true) end)
    end,
    leave = function(player, ped, done)
        play(player, "HAIRCUTS", "BRB_Sit_Out")
        play(ped, "HAIRCUTS", "BRB_Out")
        setTimer(function() Flows.hair.idle(ped) end, 670, 1)
        setTimer(done, 3000, 1)
    end,
}

-- Tattoos: each body part has In/Pose/Out animations for the customer (_P) and the artist (_T).
local function tattooPose(player, ped, c, part)
    local parts = KeeperLayouts.tattoo.parts
    local delay = 0
    if c.part and c.part ~= part then
        local old = parts[c.part]
        play(player, "TATTOOS", "TAT_" .. old[1] .. "_Out_P")
        play(ped, "TATTOOS", "TAT_" .. old[2] .. "_Out_T")
        delay = 1000
        later(player, 2500, function(now)
            if not now.part then
                play(player, "TATTOOS", "TAT_Sit_Loop_P", true)
                play(ped, "TATTOOS", "TAT_Sit_Loop_T", true)
            end
        end)
    end
    if part and part ~= c.part then
        local new = parts[part]
        later(player, delay, function()
            play(player, "TATTOOS", "TAT_" .. new[1] .. "_In_P")
            play(ped, "TATTOOS", "TAT_" .. new[2] .. "_In_T")
        end)
        later(player, delay + 830, function()
            play(player, "TATTOOS", "TAT_" .. new[1] .. "_Pose_P", true)
            play(ped, "TATTOOS", "TAT_" .. new[2] .. "_Pose_T", true)
        end)
    end
    c.part = part
end

Flows.tattoo = {
    idle = function(ped) play(ped, "TATTOOS", "TAT_Idle_Loop_T", true) end,
    sit = function(player, ped)
        play(player, "TATTOOS", "TAT_Sit_In_P")
        play(ped, "TATTOOS", "TAT_Sit_In_T")
        later(player, 2330, function()
            play(player, "TATTOOS", "TAT_Sit_Loop_P", true)
            play(ped, "TATTOOS", "TAT_Sit_Loop_T", true)
        end)
    end,
    browse = function(player, ped, entry)
        local c = step(player)
        local part = entry and tonumber(entry.category)
        if part and not KeeperLayouts.tattoo.parts[part] then part = nil end
        tattooPose(player, ped, c, part)
    end,
    buy = function() end,
    leave = function(player, ped, done)
        play(player, "TATTOOS", "TAT_Sit_Out_P")
        play(ped, "TATTOOS", "TAT_Sit_Out_T")
        setTimer(function() Flows.tattoo.idle(ped) end, 2830, 1)
        setTimer(done, 2170, 1)
    end,
}

-- Ammu-Nation: the clerk lifts the highlighted weapon (SHP_<group>_Lift) and puts it back to show another.
local function weaponModel(entry)
    local layout = KeeperLayouts.weapons
    if not entry then return nil end
    if entry.key == "armour" then return layout.models.armour end
    return layout.models[ShopConfig.weapons[entry.key] or -1]
end

local function liftGroup(model)
    return KeeperLayouts.weapons.lifts[model] or "1H"
end

Flows.weapons = {
    idle = function(ped) play(ped, "WEAPONS", "SHP_Tray_Pose", true) end,
    sit = function() end,
    browse = function(player, ped, entry)
        local c = step(player)
        local model = weaponModel(entry)
        if model == c.holding then return end
        local delay = 0
        if c.holding then
            local old = liftGroup(c.holding)
            play(ped, "WEAPONS", "SHP_" .. old .. "_Ret_S")
            later(player, 330, function() play(ped, "WEAPONS", "SHP_" .. old .. "_Ret") end)
            later(player, 1330, function() hold(ped, nil) end)
            delay = 1330
        end
        c.holding = model
        if not model then
            later(player, delay, function() play(ped, "WEAPONS", "SHP_G_Lift_Out") end)
            later(player, delay + 670, function() Flows.weapons.idle(ped) end)
            return
        end
        local group = liftGroup(model)
        later(player, delay, function() play(ped, "WEAPONS", "SHP_G_Lift_In") end)
        later(player, delay + 670, function()
            hold(ped, model)
            play(ped, "WEAPONS", "SHP_" .. group .. "_Lift")
        end)
        later(player, delay + 1670, function() play(ped, "WEAPONS", "SHP_" .. group .. "_Lift_End") end)
    end,
    buy = function() end,
    leave = function(player, ped, done, c, shopName)
        done()
        if not c.holding then return end
        local group = liftGroup(c.holding)
        play(ped, "WEAPONS", "SHP_" .. group .. "_Ret_S")
        afterLeaving(shopName, 330, function() play(ped, "WEAPONS", "SHP_" .. group .. "_Ret") end)
        afterLeaving(shopName, 1330, function() hold(ped, nil); play(ped, "WEAPONS", "SHP_G_Lift_Out") end)
        afterLeaving(shopName, 2000, function() Flows.weapons.idle(ped) end)
    end,
}

-- Fast food: the server lifts the highlighted meal on its tray; buying it, CJ eats at the counter.
Flows.food = {
    idle = function(ped) stand(ped) end,
    sit = function(player, ped, c)
        c.health0, c.fat0 = getElementHealth(player), getPedStat(player, 21)
        play(ped, "FOOD", "SHP_Tray_In")
        later(player, 670, function() play(ped, "FOOD", "SHP_Tray_Pose", true) end)
    end,
    browse = function(player, ped, entry)
        local c = step(player)
        local model = entry and KeeperLayouts.food.models[entry.key]
        if model == c.holding then return end
        local delay = 0
        if c.holding then
            play(ped, "FOOD", "SHP_Tray_Return")
            later(player, 1330, function() hold(ped, nil) end)
            delay = 1330
        end
        c.holding = model
        if not model then
            later(player, delay, function() play(ped, "FOOD", "SHP_Tray_Pose", true) end)
            return
        end
        later(player, delay, function() play(ped, "FOOD", "SHP_Tray_Lift_In") end)
        later(player, delay + 500, function()
            hold(ped, model)
            play(ped, "FOOD", "SHP_Tray_Lift")
        end)
        later(player, delay + 2170, function() play(ped, "FOOD", "SHP_Tray_Lift_Loop", true) end)
    end,
    buy = function(player, ped, entry, c)
        c.bought = (c.bought or 0) + 1
        table.insert(mealsToday(player), getTickCount())
    end,
    leave = function(player, ped, done, c, shopName)
        local delay = 0 -- the keeper puts things away after reacting to a customer being sick
        if c.bought and isElement(player) then
            local vomit = #mealsToday(player) > MEALS_PER_DAY
            if vomit then
                setElementHealth(player, math.max(10, (c.health0 or getElementHealth(player)) - 10))
                if c.fat0 then setPedStat(player, 21, c.fat0) end
                setPedAnimation(player, "FOOD", "EAT_Vomit_P", -1, false, false, false, false)
                play(ped, "FOOD", "EAT_Vomit_SK")
                local x, y, z = getElementPosition(player)
                triggerClientEvent(root, "vana-shops:puke", resourceRoot, player, x, y, z)
            else
                setPedAnimation(player, "FOOD", Keepers[shopName].eat, -1, false, false, false, false)
            end
            if vomit then delay = VOMIT_MS end
            setTimer(done, vomit and VOMIT_MS or EAT_MS, 1)
        else
            done()
        end
        if c.holding then
            afterLeaving(shopName, delay, function() play(ped, "FOOD", "SHP_Tray_Return") end)
            afterLeaving(shopName, delay + 1330, function() hold(ped, nil); play(ped, "FOOD", "SHP_Tray_Lift_Out") end)
            delay = delay + 1830
        end
        afterLeaving(shopName, delay, function() play(ped, "FOOD", "SHP_Thank") end)
        afterLeaving(shopName, delay + 1170, function() Flows.food.idle(ped) end)
    end,
}

-- 24/7s (ours: vanilla has nobody behind these counters): the clerk stands at the till and rings
-- up what you buy; you shop standing at the counter.
Flows.convenience = {
    idle = function(ped) stand(ped) end,
    sit = function() end,
    browse = function(player) step(player) end,
    buy = function(player, ped)
        step(player)
        play(ped, "DEALER", "shop_pay")
        later(player, 2000, function() stand(ped) end)
    end,
    leave = function(player, ped, done) done() end,
}

-- Clothes: CJ steps into the changing room, poses in what's highlighted (per apparel category) and
-- steps out when done. The clerk stays at the counter.
local function door(shopName, visible)
    if isElement(props[shopName]) then setElementAlpha(props[shopName], visible and 255 or 0) end
end

Flows.clothes = {
    idle = function(ped) stand(ped) end,
    sit = function(player, ped, c)
        door(c.shop, false)
        play(player, "CLOTHES", "CLO_In")
        later(player, 4000, function() door(c.shop, true) end)
    end,
    browse = function(player, ped, entry)
        local c = step(player)
        local layout = KeeperLayouts.clothes
        local category = entry and tonumber(entry.category)
        local hat = category and layout.hatCategories[category] or false
        if hat ~= (c.hat or false) then
            c.hat = hat
            camera(player, c.shop, hat and layout.hatCamera or layout.camera)
        end
        if not category or category == c.part then return end
        c.part = category
        play(player, "CLOTHES", "CLO_Pose_" .. (layout.poses[category] or "Torso"))
        later(player, 3330, function() play(player, "CLOTHES", "CLO_Pose_Loop", true) end)
    end,
    buy = function(player)
        step(player)
        play(player, "CLOTHES", "CLO_Buy")
        later(player, 2070, function() play(player, "CLOTHES", "CLO_Pose_Loop", true) end)
    end,
    leave = function(player, ped, done, c, shopName)
        door(shopName, false)
        play(player, "CLOTHES", "CLO_Out")
        setTimer(function() door(shopName, true); done() end, 2670, 1)
    end,
}

local function spawnKeeper(shopName)
    local k, point = Keepers[shopName], ShopPoints[shopName]
    local layout = KeeperLayouts[k.layout]
    local x, y, z, heading
    if k.keeper then x, y, z, heading = unpack(k.keeper) else x, y, z, heading = spot(shopName, layout.keeper) end
    -- A clerk from the shop's pool (24/7s: the locals' faces) or its one vanilla model.
    local model = k.models and k.models[math.random(#k.models)] or k.model
    local ped = createPed(model, x, y, z + 1, heading)
    if not ped then return end
    setElementInterior(ped, point.interior)
    setElementDimension(ped, point.instance or 0)
    setElementFrozen(ped, true)
    setElementData(ped, "vana:keeper", shopName)
    staff[shopName] = ped
    Flows[k.layout].idle(ped)
    if layout.kit and not props[shopName] then
        local kit = createObject(layout.kit.model, x, y, z + layout.kit.z, 0, 0, heading)
        setElementInterior(kit, point.interior)
        setElementDimension(kit, point.instance or 0)
        props[shopName] = kit
    end
    if layout.door and k.door and not props[shopName] then
        local dx, dy, dz, dh = spot(shopName, layout.door)
        local d = createObject(k.door, dx, dy, dz, 0, 0, dh)
        setElementInterior(d, point.interior)
        setElementDimension(d, point.instance or 0)
        props[shopName] = d
    end
end

-- Seats the customer and starts the service. False (and why) if the shop is busy.
function keeperSeat(player, shopName)
    local k = Keepers[shopName]
    if not k then return true end
    if serving[shopName] and serving[shopName] ~= player then return false, "You look a bit busy, why don't you come back later." end
    local ped = staff[shopName]
    if not isElement(ped) or isPedDead(ped) then return false, "There's nobody here to serve you." end
    if robberies[shopName] then return false, "The shop's closed." end
    serving[shopName] = player
    customers[player] = { shop = shopName, layout = k.layout, token = 0 }
    -- A counter you shop at standing (24/7s): no seat, no camera.
    if not KeeperLayouts[k.layout].customer then
        Flows[k.layout].sit(player, ped, customers[player])
        return true
    end
    local x, y, z, heading = spot(shopName, KeeperLayouts[k.layout].customer)
    setElementFrozen(player, true)
    setElementPosition(player, x, y, z + 1)
    setElementRotation(player, 0, 0, heading, "default", true)
    Flows[k.layout].sit(player, ped, customers[player])
    camera(player, shopName, KeeperLayouts[k.layout].camera)
    return true
end

function keeperBrowse(player, entry)
    local c = customers[player]
    if c then Flows[c.layout].browse(player, staff[c.shop], entry) end
end

function keeperBought(player, entry)
    local c = customers[player]
    if c then Flows[c.layout].buy(player, staff[c.shop], entry, c) end
end

-- Gets the customer up; `instant` skips the animation (death, quit, resource stop).
function keeperLeave(player, instant)
    local c = customers[player]
    if not c then return end
    customers[player] = nil
    if serving[c.shop] == player then serving[c.shop] = nil end
    local ped = staff[c.shop]
    if isElement(player) then triggerClientEvent(player, "vana-shops:camera", resourceRoot, nil) end
    local function done()
        if not isElement(player) or customers[player] then return end
        setPedAnimation(player)
        setElementFrozen(player, false)
    end
    if instant or not isElement(player) or isPedDead(player) then
        if isElement(ped) and not isPedDead(ped) then hold(ped, nil); Flows[c.layout].idle(ped) end
        door(c.shop, true)
        if isElement(player) and not isPedDead(player) then done() end
    else
        Flows[c.layout].leave(player, ped, done, c, c.shop)
    end
end

addEventHandler("onResourceStart", resourceRoot, function()
    for shopName in pairs(Keepers) do
        if ShopPoints[shopName] then spawnKeeper(shopName) end
    end
end)

-- A keeper who's killed comes back once nobody is being served there.
addEventHandler("onPedWasted", root, function()
    local shopName = getElementData(source, "vana:keeper")
    if not shopName then return end
    local ped = source
    setTimer(function()
        if isElement(ped) then destroyElement(ped) end
        spawnKeeper(shopName)
    end, 60000, 1)
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for player in pairs(customers) do keeperLeave(player, true) end
end)

-- For shoptest: how many staffed shops have a live keeper.
function keeperStatus()
    local alive, total = 0, 0
    for shopName in pairs(Keepers) do
        total = total + 1
        local ped = staff[shopName]
        if isElement(ped) and not isPedDead(ped) and getElementInterior(ped) == ShopPoints[shopName].interior
            and getElementDimension(ped) == (ShopPoints[shopName].instance or 0) then alive = alive + 1 end
    end
    return alive, total
end

addEventHandler("onPlayerQuit", root, function() meals[source] = nil end)

---------------------------------------------------------------------------------------------------
-- Robbery (config/shops.lua: robbery). Reported by the clients of players threatening a keeper.

local R = ShopConfig.robbery
-- robberies: shopName -> { robber, mode = "handsup" | "attack", aimFrom, lastAim, lastNear, cashDone }
local lastCash = {}  -- shopName -> tick the till was last handed over

local function nearbyPlayer(ped)
    local x, y, z = getElementPosition(ped)
    for _, player in ipairs(getElementsByType("player")) do
        if getElementInterior(player) == getElementInterior(ped) and getElementDimension(player) == getElementDimension(ped) then
            local px, py, pz = getElementPosition(player)
            if getDistanceBetweenPoints3D(x, y, z, px, py, pz) < R.resetRadius then return true end
        end
    end
    return false
end

local function startRobbery(shopName, robber, now)
    local ped = staff[shopName]
    local layout = Keepers[shopName].layout
    local r = { robber = robber, aimFrom = now, lastAim = now, lastNear = now }
    robberies[shopName] = r
    if serving[shopName] then interruptCustomer(serving[shopName]) end
    hold(ped, nil)
    if layout == "weapons" then
        -- Vanilla AMUNAT: pistol, pro skill, stays behind the counter and shoots.
        r.mode = "attack"
        setPedAnimation(ped)
        setElementFrozen(ped, false)
        giveWeapon(ped, R.clerkWeapon, R.clerkAmmo, true)
        setElementSyncer(ped, robber, true, true)
        triggerClientEvent(robber, "vana-shops:keeperAttack", resourceRoot, ped, robber)
    else
        r.mode = "handsup"
        setPedAnimation(ped, "ped", "handsup", -1, false, false, false, true)
    end
end

local function endRobbery(shopName)
    robberies[shopName] = nil
    local ped = staff[shopName]
    if not isElement(ped) or isPedDead(ped) then
        if isElement(ped) then destroyElement(ped) end
        staff[shopName] = nil
        spawnKeeper(shopName)
        return
    end
    takeAllWeapons(ped)
    setElementSyncer(ped, true)
    local k = Keepers[shopName]
    local x, y, z, heading
    if k.keeper then x, y, z, heading = unpack(k.keeper) else x, y, z, heading = spot(shopName, KeeperLayouts[k.layout].keeper) end
    setElementPosition(ped, x, y, z + 1)
    setElementRotation(ped, 0, 0, heading, "default", true)
    setElementFrozen(ped, true)
    setPedAnimation(ped)
    Flows[k.layout].idle(ped)
end

function isShopRobbed(shopName)
    return robberies[shopName] ~= nil
end

addEvent("vana-shops:threat", true)
addEventHandler("vana-shops:threat", resourceRoot, function(ped, how)
    local shopName = isElement(ped) and getElementData(ped, "vana:keeper")
    if not shopName or staff[shopName] ~= ped or isPedDead(ped) or isPedDead(client) then return end
    if getElementInterior(client) ~= getElementInterior(ped) or getElementDimension(client) ~= getElementDimension(ped) then return end
    local x, y, z = getElementPosition(ped)
    local px, py, pz = getElementPosition(client)
    if getDistanceBetweenPoints3D(x, y, z, px, py, pz) > R.resetRadius then return end
    local now = getTickCount()
    local r = robberies[shopName]
    if not r then return startRobbery(shopName, client, now) end
    if r.robber == client and how == "aim" then
        if now - r.lastAim > R.aimTimeoutMs then r.aimFrom = now end -- a fresh aim starts the count again
        r.lastAim = now
    end
end)

local function handOverTill(shopName, r, now)
    r.cashDone = true
    if lastCash[shopName] and now - lastCash[shopName] < R.cooldownMs then return end
    lastCash[shopName] = now
    local ped = staff[shopName]
    local range = R.cash[Keepers[shopName].layout]
    if not range then return end
    local amount = math.random(range[1], range[2])
    local x, y, z = getElementPosition(ped)
    local _, _, rz = getElementRotation(ped)
    local h = math.rad(rz)
    local pickup = createPickup(x - math.sin(h) * 0.8, y + math.cos(h) * 0.8, z - 0.4, 3, 1212, 3600000)
    if pickup then
        setElementInterior(pickup, getElementInterior(ped))
        setElementDimension(pickup, getElementDimension(ped))
        addEventHandler("onPickupHit", pickup, function(player)
            if getElementType(player) ~= "player" or isPedDead(player) then return end
            givePlayerMoney(player, amount)
            destroyElement(source)
        end)
        setTimer(function() if isElement(pickup) then destroyElement(pickup) end end, 60000, 1)
    end
    local res = getResourceFromName("vana-services")
    if res and getResourceState(res) == "running" and isElement(r.robber) then
        pcall(function() exports["vana-services"]:reportCrime(r.robber, "holdup", x, y, z) end)
    end
end

setTimer(function()
    local now = getTickCount()
    for shopName, r in pairs(robberies) do
        local ped = staff[shopName]
        if not isElement(ped) then
            robberies[shopName] = nil
        else
            if nearbyPlayer(ped) then r.lastNear = now end
            if now - r.lastNear > R.resetMs then
                endRobbery(shopName)
            elseif r.mode == "handsup" and not r.cashDone and not isPedDead(ped) and isElement(r.robber)
                and now - r.lastAim < R.aimTimeoutMs and now - r.aimFrom >= R.cashSeconds * 1000 then
                handOverTill(shopName, r, now)
            end
        end
    end
end, 500, 0)
