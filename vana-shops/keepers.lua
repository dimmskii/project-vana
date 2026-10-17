-- Shopkeepers (config/keepers.lua): the vanilla shop scripts' staff, standing where vanilla puts them
-- and playing its animations while a customer is served. One customer per shop at a time.
local staff = {}    -- shopName -> ped
local props = {}    -- shopName -> object
local serving = {}  -- shopName -> player
local customers = {} -- player -> { shop, layout, part, token }

local function spot(shopName, point)
    local o = Keepers[shopName].offset
    return point[1] + o[1], point[2] + o[2], point[3] + o[3], point[4]
end

local function play(ped, lib, name, loop)
    if isElement(ped) then setPedAnimation(ped, lib, name, -1, loop or false, false, false, true) end
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

local function spawnKeeper(shopName)
    local k, point = Keepers[shopName], ShopPoints[shopName]
    local layout = KeeperLayouts[k.layout]
    local x, y, z, heading = spot(shopName, layout.keeper)
    local ped = createPed(k.model, x, y, z + 1, heading)
    if not ped then return end
    setElementInterior(ped, point.interior)
    setElementFrozen(ped, true)
    setElementData(ped, "vana:keeper", shopName)
    staff[shopName] = ped
    Flows[k.layout].idle(ped)
    if layout.kit and not props[shopName] then
        local kit = createObject(layout.kit.model, x, y, z + layout.kit.z, 0, 0, heading)
        setElementInterior(kit, point.interior)
        props[shopName] = kit
    end
end

-- Seats the customer and starts the service. False (and why) if the shop is busy.
function keeperSeat(player, shopName)
    local k = Keepers[shopName]
    if not k then return true end
    if serving[shopName] and serving[shopName] ~= player then return false, "You look a bit busy, why don't you come back later." end
    local ped = staff[shopName]
    if not isElement(ped) or isPedDead(ped) then return false, "There's nobody here to serve you." end
    serving[shopName] = player
    customers[player] = { shop = shopName, layout = k.layout, token = 0 }
    local x, y, z, heading = spot(shopName, KeeperLayouts[k.layout].customer)
    setElementFrozen(player, true)
    setElementPosition(player, x, y, z + 1)
    setElementRotation(player, 0, 0, heading, "default", true)
    Flows[k.layout].sit(player, ped)
    local cam = KeeperLayouts[k.layout].camera
    local o = k.offset
    triggerClientEvent(player, "vana-shops:camera", resourceRoot, { cam[1] + o[1], cam[2] + o[2], cam[3] + o[3], cam[4] + o[1], cam[5] + o[2], cam[6] + o[3] })
    return true
end

function keeperBrowse(player, entry)
    local c = customers[player]
    if c then Flows[c.layout].browse(player, staff[c.shop], entry) end
end

function keeperBought(player, entry)
    local c = customers[player]
    if c then step(player); Flows[c.layout].buy(player, staff[c.shop], entry) end
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
        if isElement(ped) and not isPedDead(ped) then Flows[c.layout].idle(ped) end
        if isElement(player) and not isPedDead(player) then done() end
    else
        Flows[c.layout].leave(player, ped, done)
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
        if isElement(ped) and not isPedDead(ped) and getElementInterior(ped) == ShopPoints[shopName].interior then alive = alive + 1 end
    end
    return alive, total
end
