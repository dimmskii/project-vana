-- Firefighter (vanilla FIRETRU): in a fire truck, press the sub-mission key. Each level reports burning
-- cars (one, two past level 4, three past level 8), with their occupants on fire from level 3; put
-- every fire out with the water cannon before the time runs out. Levels pay level x level x $50; level 12
-- pays $5000 and makes you fireproof. The player's client watches the fires (jobs/firefighter_client.lua).
local F = Jobs.firefighter
local trucks = Job.set(F.vehicles)

local function startLevel(session)
    local d = session.data
    local x, y, z = getElementPosition(session.player)
    local cx, cy, cz = Activity.streetSpot(x, y, z, F.range[1], F.range[2], "vehicle", { x, y, z })
    if not cx then return session:after(3000, startLevel) end
    local cars = 1 + (d.level > 4 and 1 or 0) + (d.level > 8 and 1 or 0)
    local people = math.max(0, math.min(cars * 3, d.level - 2))
    d.targets = {}
    for i = 1, cars do
        local car = session:vehicle(F.carModels[math.random(#F.carModels)], cx + (i - 1) * 5, cy + (i - 1) * 2, cz + 1, math.random(0, 359))
        setVehicleDamageProof(car, true) -- ours: the fire shouldn't blow the car up before you arrive
        setVehicleEngineState(car, false)
        setElementOnFire(car, true)
        d.targets[#d.targets + 1] = car
        for seat = 0, 3 do
            if people > 0 and seat <= (getVehicleMaxPassengers(car) or 0) then
                people = people - 1
                local ped = session:ped(Job.civilian(), cx, cy, cz + 2)
                warpPedIntoVehicle(ped, car, seat)
                setElementOnFire(ped, true)
                d.targets[#d.targets + 1] = ped
            end
        end
    end
    d.blip = session:blip({ cx, cy, cz }, 20, 255, 80, 0)
    d.left = #d.targets
    local zone = getZoneName(cx, cy, cz)
    session:say(session:text(cars > 1 and "F_STAR1" or "F_START"):gsub("~a~", zone), 5000)
    local ms = F.extraMs + getDistanceBetweenPoints3D(x, y, z, cx, cy, cz) * F.msPerMetre + #d.targets * F.perFireMs
    d.deadline = getTickCount() + ms
    session:counter("level", session:text("FLEV"), d.level, "number")
    session:counter("time", session:text("FIRTIME"), ms, "timer")
    session:counter("fires", session:text("F_EXTIN"), d.left, "number")
    triggerClientEvent(session.player, "vana-firefighter:targets", resourceRoot, d.targets)
end

local function levelDone(session)
    local d = session.data
    local player = session.player
    local pay = d.level * d.level * F.pay
    givePlayerMoney(player, pay)
    session:big(session:text("F_PASS1"), 3000, "title")
    session:say(session:text("REWARD", pay), 3000)
    if d.blip and isElement(d.blip) then destroyElement(session:disown(d.blip)) end
    for _, t in ipairs(d.targets) do
        if isElement(t) then
            local e = session:disown(t)
            setTimer(function() if isElement(e) then destroyElement(e) end end, 20000, 1)
        end
    end
    local best = Activity.progress(player, "firefighter.level") or 0
    if d.level > best then Activity.setProgress(player, "firefighter.level", d.level) end
    if d.level == F.levels then
        givePlayerMoney(player, F.completeBonus)
        if Activity.grantPerk(player, "fireproof") then
            session:after(3500, function(s) s:big(s:text("F_COMP1", F.completeBonus), 5000, "passed") end)
        end
    end
    d.level, d.targets = d.level + 1, nil
    session:after(5000, startLevel)
end

Activity.perk("fireproof", function() end) -- applied on the client (core/client.lua)

-- The client reports a fire that went out (the water cannon, or a burning occupant who died).
addEvent("vana-firefighter:out", true)
addEventHandler("vana-firefighter:out", resourceRoot, function(target)
    local session = Activity.of(client)
    local d = session and session.name == "firefighter" and session.data
    if not d or not d.targets then return end
    for i, t in ipairs(d.targets) do
        if t == target and not d.done[t] then
            d.done[t] = true
            d.left = d.left - 1
            if isElement(t) and getElementType(t) == "ped" then setElementOnFire(t, false) end
            if isElement(t) and getElementType(t) == "vehicle" then setElementOnFire(t, false) end
            session:counter("fires", session:text("F_EXTIN"), d.left, "number")
            if d.left <= 0 then levelDone(session) end
            return
        end
    end
end)

Activity.register("firefighter", {
    title = "FIRE_M",
    gxt = "FIRETRK",
    cancelText = "F_CANC",
    launch = { vehicles = trucks, help = "FTUTOR" },
    start = function(session)
        local d = session.data
        d.level, d.done = 1, {}
        session:big(session:text("FIRE_M"), 4000, "title")
        session:after(1500, startLevel)
        session:every(500, function(s)
            if not Job.watchVehicle(s, trucks, F.outMs, "F_FAIL1", "F_CANC") then return end
            if s.data.targets and getTickCount() > s.data.deadline then s:fail("F_FAIL2") end
        end)
    end,
    stop = function(session, reason)
        if isElement(session.player) then triggerClientEvent(session.player, "vana-firefighter:targets", resourceRoot, nil) end
    end,
})

Activity.test("firefighter", function()
    return Gxt.raw("F_START", "FIRETRK") ~= nil and #Jobs.firefighter.carModels > 10, ("%d car models"):format(#Jobs.firefighter.carModels)
end)
