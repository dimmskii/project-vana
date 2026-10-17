-- Vigilante (vanilla COPCAR): in a police vehicle, press the sub-mission key. Each level sends you
-- after criminals in cars (level N: N criminals, four to a car); they run, and fight when cornered.
-- Kill them all before the clock runs out. Levels pay level x level x $50; level 12 earns vanilla's
-- armour reward. The criminals' driving and fighting run on the player's client.
local V = Jobs.vigilante
local vehicles = Job.set(V.vehicles)

local function startLevel(session)
    local d = session.data
    local player = session.player
    local x, y, z = getElementPosition(player)
    local cx, cy, cz = Activity.streetSpot(x, y, z, V.range[1], V.range[2], "vehicle", { x, y, z })
    if not cx then return session:after(3000, startLevel) end
    d.criminals, d.alive = {}, 0
    local weapon = V.weapons[math.min(#V.weapons, 1 + math.floor((d.level - 1) / 3))]
    local left, crews = d.level, {}
    local carIndex = 0
    while left > 0 do
        carIndex = carIndex + 1
        local car = session:vehicle(V.criminalCars[math.random(#V.criminalCars)], cx + carIndex * 6, cy, cz + 1, math.random(0, 359))
        setElementSyncer(car, player, true, true)
        local crew = {}
        for seat = 0, math.min(V.perCar, (getVehicleMaxPassengers(car) or 0) + 1) - 1 do
            if left <= 0 then break end
            left = left - 1
            local ped = session:ped(V.criminals[math.random(#V.criminals)], cx, cy, cz + 2)
            warpPedIntoVehicle(ped, car, seat)
            giveWeapon(ped, weapon, 500, true)
            setElementSyncer(ped, player, true, true)
            setElementData(ped, "vana:fairGame", true)
            d.criminals[ped] = session:blip(ped, 0, 255, 40, 40, 2)
            d.alive = d.alive + 1
            crew[#crew + 1] = ped
        end
        crews[#crews + 1] = { car = car, peds = crew }
    end
    local zone = getZoneName(cx, cy, cz)
    session:say(session:text(d.level > 1 and "C_BREIS" or "C_BREIF"):gsub("~a~", zone), 5000)
    local ms = math.max(V.minimumMs, getDistanceBetweenPoints3D(x, y, z, cx, cy, cz) / V.speed * 1000)
    d.deadline = (d.deadline and d.deadline > getTickCount() and d.deadline or getTickCount()) + ms
    session:big(session:text("A_TIME", math.floor(ms / 1000)), 3000, "small")
    session:counter("level", session:text("COPLEVL"), d.level, "number")
    session:counter("kills", session:text("KILLS"), d.kills, "number")
    session:counter("time", "TIME", d.deadline - getTickCount(), "timer")
    triggerClientEvent(player, "vana-vigilante:crews", resourceRoot, crews)
end

local function levelDone(session)
    local d = session.data
    local player = session.player
    local pay = d.level * d.level * V.pay
    givePlayerMoney(player, pay)
    session:big(session:text("C_PASS", pay), 4000, "small")
    local best = Activity.progress(player, "vigilante.level") or 0
    if d.level > best then Activity.setProgress(player, "vigilante.level", d.level) end
    if d.level == V.levels and Activity.grantPerk(player, "vigilante") then
        session:after(4000, function(s) s:help(s:text("C_COMP1")) end)
    end
    d.level, d.criminals = d.level + 1, nil
    session:after(4500, startLevel)
end

-- The reward. Vanilla raises maximum armour to 150; MTA caps armour at 100, so you start each life
-- with full armour instead (ours).
Activity.perk("vigilante", function(player) setPedArmor(player, 100) end)

addEventHandler("onPedWasted", root, function()
    if not getElementData(source, "vana:fairGame") then return end
    for _, player in ipairs(getElementsByType("player")) do
        local session = Activity.of(player)
        local d = session and session.name == "vigilante" and session.data
        if d and d.criminals and d.criminals[source] then
            local blip = d.criminals[source]
            if isElement(blip) then destroyElement(session:disown(blip)) end
            d.criminals[source] = false
            d.alive, d.kills = d.alive - 1, d.kills + 1
            Activity.setProgress(player, "vigilante.kills", (Activity.progress(player, "vigilante.kills") or 0) + 1)
            session:counter("kills", session:text("KILLS"), d.kills, "number")
            if d.alive <= 0 then levelDone(session) end
            return
        end
    end
end)

Activity.register("vigilante", {
    title = "COP_M",
    gxt = "COPCAR",
    cancelText = "C_CANC",
    launch = { vehicles = vehicles, help = "CTUTOR" },
    start = function(session, vehicle)
        local d = session.data
        d.level, d.kills = 1, 0
        local model = isElement(vehicle) and getElementModel(vehicle)
        session:big(session:text(model == 425 and "COP_M3" or "COP_M"), 4000, "title")
        session:after(1500, startLevel)
        session:every(500, function(s)
            if not Job.watchVehicle(s, vehicles, V.outMs, "C_CANC") then return end
            if s.data.criminals and getTickCount() > s.data.deadline then s:fail("C_TIME") end
        end)
    end,
    stop = function(session)
        if isElement(session.player) then triggerClientEvent(session.player, "vana-vigilante:crews", resourceRoot, nil) end
    end,
})

Activity.test("vigilante", function()
    return Gxt.raw("C_BREIF", "COPCAR") ~= nil and Gxt.raw("COP_M") ~= nil, ("%d police vehicles"):format(#V.vehicles)
end)
