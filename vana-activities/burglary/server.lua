-- Burglary (vanilla BURGJB): at night, in a Boxville, press the sub-mission key. Break into houses
-- (doors in config/burglary_houses.lua), carry what you can to the back of the van, and sell each
-- load at a lock-up before daylight runs out. Houses are instanced in the burglar's private dimension.
-- The client (burglary/client.lua) finds the doors, places loot, runs the noise meter and the carrying.
local B = Burglary

local function hour()
    local h = getTime()
    return h
end

local function isNight()
    local h = hour()
    return h >= B.startHour or h < B.dawnHour
end

-- Game-time ms until dawn.
local function msToDawn()
    local h, m = getTime()
    local minutes = ((B.dawnHour * 60) - (h * 60 + m)) % 1440
    return minutes * getMinuteDuration()
end

local function send(session, event, ...)
    triggerClientEvent(session.player, "vana-burglary:" .. event, resourceRoot, ...)
end

local function nearestLockup(x, y, z)
    local best, bestD
    for i, l in ipairs(B.lockups) do
        local d = getDistanceBetweenPoints3D(x, y, z, l.x, l.y, l.z)
        if not bestD or d < bestD then best, bestD = i, d end
    end
    return best
end

-- The objective line and blips, from where the burglar is at (vanilla's BURG1/26/27/29/30/31 choices).
local function objective(session)
    local d = session.data
    if d.house then
        send(session, "objective", "inside")
        return session:say(session:text(d.carrying and "BURG57" or "BURG30"))
    end
    local inVan = getPedOccupiedVehicle(session.player) == d.van
    if d.carrying then return session:say(session:text("BURG27")) end
    if d.items > 0 and d.dawn then return session:say(session:text(inVan and "BURG26" or "BURG1")) end
    if d.items > 0 then return session:say(session:text(inVan and "BURG4" or "BURG31")) end
    session:say(session:text("BURG29"))
end

local function updateLockupBlip(session)
    local d = session.data
    local want = d.items > 0 and getPedOccupiedVehicle(session.player) == d.van
    if want and not d.lockupBlip then
        local x, y, z = getElementPosition(d.van)
        d.lockup = nearestLockup(x, y, z)
        local l = B.lockups[d.lockup]
        d.lockupBlip = session:blip({ l.x, l.y, l.z }, 0, 255, 255, 0)
    elseif not want and d.lockupBlip then
        destroyElement(session:disown(d.lockupBlip))
        d.lockupBlip, d.lockup = nil, nil
    end
    local inVan = getPedOccupiedVehicle(session.player) == d.van
    if not inVan and not d.vanBlip and isElement(d.van) then
        d.vanBlip = session:blip(d.van, 0, 80, 120, 255, 1)
    elseif inVan and d.vanBlip then
        destroyElement(session:disown(d.vanBlip))
        d.vanBlip = nil
    end
end

local function dawn(session)
    local d = session.data
    d.dawn = true
    session:clearCounter("daylight")
    send(session, "doors", false)
    if d.items == 0 and not d.carrying then
        return session:fail("BURG53")
    end
    session:say(session:text("BURG2"))
    session:counter("lockup", session:text("BURG3"), B.lockupMs, "timer")
    d.lockupTimer = session:after(B.lockupMs, function(s) s:fail("BURG53") end)
end

-- Selling a load at a lock-up.
local function sell(session)
    local d = session.data
    local l = B.lockups[d.lockup]
    setGarageOpen(l.garage, false)
    local n = d.items
    local pay = n * n * B.payPerItemSquared
    d.items, d.made = 0, d.made + pay
    givePlayerMoney(session.player, pay)
    local total = (Activity.progress(session.player, "burglary.total") or 0) + pay
    Activity.setProgress(session.player, "burglary.total", total)
    Activity.setProgress(session.player, "burglary.items", (Activity.progress(session.player, "burglary.items") or 0) + n)
    session:big(session:text(n < 2 and "BURG39" or "BURG36", n, pay), 5000, "small")
    session:counter("cash", session:text("BURG51"), d.made, "money")
    if total >= B.perkTotal and Activity.grantPerk(session.player, "burglar") then
        session:after(5000, function(s) s:big(s:text("BURG54", total), 5000, "small") end)
    end
    session:after(4000, function(s)
        setGarageOpen(l.garage, true)
        if s.data.dawn then s:pass(nil, 0) else updateLockupBlip(s); objective(s) end
    end)
end

local function enterHouse(session, index)
    local d = session.data
    local door = BurglaryDoors[index]
    local house = door and BurglaryHouses[door.house]
    if not house or d.house or d.dawn then return end
    local player = session.player
    if getPedOccupiedVehicle(player) or getElementDimension(player) ~= 0 then return end
    local x, y, z = getElementPosition(player)
    if getDistanceBetweenPoints3D(x, y, z, door.x, door.y, door.z + 1) > B.doorRadius + 2 then return end
    local dim = Activity.dimension(player)
    d.house, d.door = door.house, index
    d.visits[index] = d.visits[index] or { loot = {}, placed = false, resident = nil, detected = false }
    local visit = d.visits[index]
    setElementInterior(player, house.interior, house.ex, house.ey, house.ez + 1)
    setElementDimension(player, dim)
    setElementPosition(player, house.ex, house.ey, house.ez + 1)
    setElementRotation(player, 0, 0, house.heading, "default", true)
    if d.carrying and isElement(d.carrying) then
        setElementInterior(d.carrying, house.interior)
        setElementDimension(d.carrying, dim)
    end
    local alive = {}
    for _, obj in ipairs(visit.loot) do if isElement(obj) then alive[#alive + 1] = obj end end
    visit.loot = alive
    local residentHere = visit.resident and isElement(visit.resident) and not isPedDead(visit.resident) and not visit.detected
    send(session, "inside", door.house, house.interior, dim, not visit.placed, visit.loot, residentHere and visit.resident or nil)
    if not visit.placed then
        -- The client picks free floor spots; we decide what goes there.
        local count = math.random(B.lootPerHouse[1], B.lootPerHouse[2])
        local models = {}
        for i = 1, count do models[i] = B.loot[math.random(#B.loot)] end
        visit.models = models
        visit.wantsResident = math.random() < B.residentChance
        send(session, "place", models, visit.wantsResident)
    end
    if not d.counted[index] then
        d.counted[index] = true
        Activity.setProgress(player, "burglary.houses", (Activity.progress(player, "burglary.houses") or 0) + 1)
    end
    objective(session)
end

local function leaveHouse(session)
    local d = session.data
    if not d.house then return end
    local door = BurglaryDoors[d.door]
    local player = session.player
    d.house = nil
    local visit = d.visits[d.door]
    if visit and visit.getOut then
        if isTimer(visit.getOut) then killTimer(visit.getOut) end
        visit.getOut = nil
        session:clearCounter("cops")
    end
    session:clearCounter("noise")
    setElementInterior(player, 0, door.ex, door.ey, door.ez + 1)
    setElementDimension(player, 0)
    setElementPosition(player, door.ex, door.ey, door.ez + 1)
    setElementRotation(player, 0, 0, door.heading, "default", true)
    if d.carrying and isElement(d.carrying) then
        setElementInterior(d.carrying, 0)
        setElementDimension(d.carrying, 0)
    end
    send(session, "outside")
    updateLockupBlip(session)
    objective(session)
end

-- The resident wakes up (vanilla: stealth bar full). Ten seconds to get out, then the cops.
local function detected(session)
    local d = session.data
    local visit = d.house and d.visits[d.door]
    if not visit or visit.detected then return end
    visit.detected = true
    session:clearCounter("noise")
    session:say(session:text("BURG55"))
    local resident = visit.resident
    if isElement(resident) and not isPedDead(resident) then
        setPedAnimation(resident)
        send(session, "wake", resident, visit.residentKind)
    end
    session:counter("cops", session:text("BURG61"), B.getOutMs, "timer")
    visit.getOut = session:after(B.getOutMs, function(s)
        s:clearCounter("cops")
        if s.data.house then
            Activity.call("vana-services", "setMinimumWanted", s.player, B.wantedStars)
            s:say(s:text("BURG60"))
        end
    end)
end

Activity.register("burglary", {
    title = "BURGLAR",
    gxt = "BURGLAR",
    cancelText = "BURG41",
    launch = {
        vehicles = { [Burglary.van] = true },
        help = "BTUTOR2",
        check = function() if isNight() then return true end return false, "BURGHEL" end,
    },
    start = function(session, van)
        local player = session.player
        local d = session.data
        d.van, d.items, d.made, d.visits, d.counted = van, 0, 0, {}, {}
        d.costume = { getPedClothes(player, B.balaclava.slot) }
        addPedClothes(player, B.balaclava.texture, B.balaclava.model, B.balaclava.slot)
        session:big(session:text("BURGLAR"), 4000, "title")
        local untilDawn = msToDawn()
        session:counter("daylight", session:text("BURG52"), untilDawn, "timer")
        session:counter("cash", session:text("BURG51"), 0, "money")
        session:after(untilDawn, dawn)
        send(session, "doors", true, van, { pick = session:text("BURG23"), load = session:text("BURG24"), noise = session:text("BURG25") })
        session:every(1000, function(s)
            if not isElement(s.data.van) or isVehicleBlown(s.data.van) then return s:fail("BURG41") end
            updateLockupBlip(s)
            local dd = s.data
            -- At the lock-up: the door opens for the van; parked inside, the load sells.
            if dd.lockup and dd.items > 0 and getPedOccupiedVehicle(s.player) == dd.van and not dd.selling then
                local l = B.lockups[dd.lockup]
                local x, y, z = getElementPosition(dd.van)
                if getDistanceBetweenPoints3D(x, y, z, l.x, l.y, l.z) < B.openRadius then
                    setGarageOpen(l.garage, true)
                    if getDistanceBetweenPoints2D(x, y, l.park[1], l.park[2]) < B.parkRadius then
                        if getPlayerWantedLevel(s.player) > 0 then
                            s:say(s:text("BURG50"), 2000)
                        else
                            dd.selling = true
                            sell(s)
                            s:after(4500, function(ss) ss.data.selling = false end)
                        end
                    else
                        s:say(s:text("BURG40"), 1200)
                    end
                end
            end
        end)
        objective(session)
    end,
    stop = function(session)
        local player = session.player
        local d = session.data
        if isElement(player) then
            if d.house then leaveHouse(session) end
            local c = d.costume
            if c and c[1] then addPedClothes(player, c[1], c[2], B.balaclava.slot) else removePedClothes(player, B.balaclava.slot) end
            send(session, "doors", false)
            send(session, "outside")
            Activity.save(player)
        end
        if d.lockup then setGarageOpen(B.lockups[d.lockup].garage, false) end
    end,
})

-- Client requests (validated against the burglar's own session).
local function burglarSession(player)
    local session = Activity.of(player)
    return session and session.name == "burglary" and session or nil
end

addEvent("vana-burglary:enter", true)
addEventHandler("vana-burglary:enter", resourceRoot, function(index)
    local session = burglarSession(client)
    if session and type(index) == "number" then enterHouse(session, index) end
end)

addEvent("vana-burglary:leave", true)
addEventHandler("vana-burglary:leave", resourceRoot, function()
    local session = burglarSession(client)
    if session then leaveHouse(session) end
end)

-- The client found free floor for the loot (and maybe a resident): { { x, y, z, rz }, ... }.
addEvent("vana-burglary:spots", true)
addEventHandler("vana-burglary:spots", resourceRoot, function(spots, residentSpot)
    local session = burglarSession(client)
    local d = session and session.data
    local visit = d and d.house and d.visits[d.door]
    if not visit or visit.placed or type(spots) ~= "table" then return end
    visit.placed = true
    local house = BurglaryHouses[d.house]
    local dim = getElementDimension(client)
    local hx, hy, hz = house.ex, house.ey, house.ez
    local function plausible(s)
        return type(s) == "table" and tonumber(s[1]) and tonumber(s[2]) and tonumber(s[3])
            and getDistanceBetweenPoints3D(s[1], s[2], s[3], hx, hy, hz) < 30
    end
    for i, model in ipairs(visit.models or {}) do
        local s = spots[i]
        if plausible(s) then
            local obj = session:object(model, s[1], s[2], s[3], 0, 0, tonumber(s[4]) or 0)
            setElementInterior(obj, house.interior)
            setElementDimension(obj, dim)
            setElementData(obj, "vana:loot", true, false)
            visit.loot[#visit.loot + 1] = obj
        end
    end
    if visit.wantsResident and plausible(residentSpot) then
        local who = B.residents[math.random(#B.residents)]
        local ped = session:ped(who.model, residentSpot[1], residentSpot[2], residentSpot[3] + 1, math.random(0, 359))
        setElementInterior(ped, house.interior)
        setElementDimension(ped, dim)
        setElementSyncer(ped, client, true, true)
        setPedAnimation(ped, "BEACH", "bather", -1, true, false, false)
        visit.resident, visit.residentKind = ped, who.kind
    end
    send(session, "inside", d.house, house.interior, dim, false, visit.loot, visit.resident)
end)

addEvent("vana-burglary:carry", true)
addEventHandler("vana-burglary:carry", resourceRoot, function(object)
    local session = burglarSession(client)
    if not session then return end
    local d = session.data
    if object == nil then
        d.carrying = nil
    elseif isElement(object) and getElementData(object, "vana:loot") then
        d.carrying = object
    end
    objective(session)
end)

addEvent("vana-burglary:load", true)
addEventHandler("vana-burglary:load", resourceRoot, function(object)
    local session = burglarSession(client)
    local d = session and session.data
    if not d or not isElement(object) or object ~= d.carrying or d.house or not isElement(d.van) then return end
    local vx, vy, vz = getElementPosition(d.van)
    local _, _, rz = getElementRotation(d.van)
    local h = math.rad(rz)
    local bx, by = vx + math.sin(h) * B.vanBack, vy - math.cos(h) * B.vanBack
    local x, y, z = getElementPosition(client)
    if getDistanceBetweenPoints2D(x, y, bx, by) > B.vanReach + 1 then return end
    destroyElement(session:disown(object))
    d.carrying = nil
    d.items = d.items + 1
    session:counter("items", "ITEMS", d.items, "number")
    updateLockupBlip(session)
    objective(session)
end)

addEvent("vana-burglary:noise", true)
addEventHandler("vana-burglary:noise", resourceRoot, function(level)
    local session = burglarSession(client)
    if not session or type(level) ~= "number" then return end
    if level >= 100 then detected(session) end
end)

addEventHandler("onPlayerVehicleEnter", root, function()
    local session = burglarSession(source)
    if session then updateLockupBlip(session); objective(session) end
end)
addEventHandler("onPlayerVehicleExit", root, function()
    local session = burglarSession(source)
    if session then updateLockupBlip(session); objective(session) end
end)

Activity.test("burglary", function()
    local doors, missing = #BurglaryDoors, 0
    for _, door in ipairs(BurglaryDoors) do
        if not BurglaryHouses[door.house] then missing = missing + 1 end
    end
    local houses = 0
    for _ in pairs(BurglaryHouses) do houses = houses + 1 end
    local ok = doors > 500 and missing == 0 and #Burglary.lockups == 3 and Gxt.raw("BURG36", "BURGLAR") ~= nil
    return ok, ("%d doors into %d houses, %d without a house, %d lock-ups"):format(doors, houses, missing, #Burglary.lockups)
end)
