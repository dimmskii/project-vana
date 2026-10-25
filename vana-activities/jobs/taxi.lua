-- Taxi driver (vanilla TAXIODD): in a taxi, press the sub-mission key. Pick up fares, get them where
-- they're going before the clock runs out; the tip bar pays a speed bonus. Every 5 fares in a row pays
-- a streak bonus; 50 fares in total puts nitro in every taxi you drive.
local T = Jobs.taxi
local taxis = {}
for _, m in ipairs(T.vehicles) do taxis[m] = true end

local function msPerMetre(streak)
    if T.msPerMetre[streak] then return T.msPerMetre[streak] end
    if streak <= 20 then return T.msPerMetreLater end
    if streak <= 50 then return T.msPerMetreLate end
    return T.msPerMetreLatest
end

local function taxiOf(session)
    local v = getPedOccupiedVehicle(session.player)
    return v and taxis[getElementModel(v)] and getVehicleController(v) == session.player and v or nil
end

local function stopped(vehicle)
    local vx, vy, vz = getElementVelocity(vehicle)
    return vx * vx + vy * vy + vz * vz < 0.0016
end

-- leave: the fare gets out and walks on ("out"), or runs from the player ("fled"); otherwise (dead) the
-- body goes after a while.
local function clearFare(session, leave)
    local d = session.data
    if d.blip and isElement(d.blip) then destroyElement(session:disown(d.blip)) end
    if d.marker and isElement(d.marker) then destroyElement(session:disown(d.marker)) end
    d.blip, d.marker = nil, nil
    if d.fare and isElement(d.fare) then
        local ped = session:disown(d.fare)
        if leave then
            Activity.letOut(ped, session.player, leave == "fled" and { mode = "flee", target = session.player } or nil)
        else
            setTimer(function() if isElement(ped) then destroyElement(ped) end end, 15000, 1)
        end
    end
    d.fare, d.destination = nil, nil
    session:clearCounter("tip")
end

local function seekFare(session)
    local d = session.data
    local x, y, z = getElementPosition(session.player)
    local fx, fy, fz = Activity.streetSpot(x, y, z, T.pickupRange[1], T.pickupRange[2], "ped")
    if not fx then
        session:say(session:text("TX_NONE"))
        d.retry = getTickCount() + 5000
        return
    end
    local ped = session:ped(Jobs.civilians[math.random(#Jobs.civilians)], fx, fy, fz + 1, math.random(0, 359))
    d.fare = ped
    d.blip = session:blip(ped, 0, 80, 120, 255, 2)
    session:say(session:text("TX_PKUP"))
end

local function pickedUp(session, taxi)
    local d = session.data
    local seat = getVehicleOccupant(taxi, 1) and (getVehicleOccupant(taxi, 2) and 3 or 2) or 1
    warpPedIntoVehicle(d.fare, taxi, seat)
    destroyElement(session:disown(d.blip))
    local x, y, z = getElementPosition(taxi)
    local dx, dy, dz = Activity.streetSpot(x, y, z, T.destinationRange[1], T.destinationRange[2], "vehicle", { x, y, z })
    if not dx then
        clearFare(session, "out")
        session:say(session:text("TX_OOPS"))
        return
    end
    local distance = getDistanceBetweenPoints3D(x, y, z, dx, dy, dz)
    d.destination, d.distance = { dx, dy, dz }, distance
    d.blip = session:blip(d.destination, 0, 255, 255, 0)
    d.marker = session:marker("checkpoint", dx, dy, dz, 4, 255, 255, 0, 120)
    local allowed = math.floor(distance * msPerMetre(d.streak))
    if not d.deadline then d.deadline = getTickCount() + T.firstTimeMs end
    d.deadline = d.deadline + allowed
    d.tipStart, d.tipUntil, d.tipPenalty = getTickCount(), getTickCount() + allowed, 0
    d.lastHealth = getElementHealth(taxi)
    session:counter("time", session:text("TX_TIME"), d.deadline - getTickCount(), "timer")
    session:help(session:text("TX_TIP"))
end

local function delivered(session)
    local d = session.data
    local player = session.player
    local tip = math.max(0, d.tipUntil - d.tipPenalty - getTickCount())
    local pay = math.floor(d.distance / (tip > 0 and T.fareFast or T.fare))
    clearFare(session, "out")
    givePlayerMoney(player, pay)
    d.earned, d.streak = d.earned + pay, d.streak + 1
    session:big(session:text(tip > 0 and "TX_FAST" or "TX_WIN"), 3000, "title")
    session:say(session:text("TX_PAY", pay), 3000)
    if d.streak % T.streakEvery == 0 then
        local bonus = T.streakBonus * (d.streak / T.streakEvery)
        givePlayerMoney(player, bonus)
        d.earned = d.earned + bonus
        session:after(3000, function(s) s:big(s:text("TX_SEQ", d.streak, bonus), 4000, "small") end)
    end
    local total = (Activity.progress(player, "taxi.fares") or 0) + 1
    Activity.setProgress(player, "taxi.fares", total)
    if total >= T.rewardFares and Activity.grantPerk(player, "taxi_nitro") then
        session:after(4000, function(s) s:big(s:text("TX_DONE"), 5000, "passed") s:say(s:text("TX_NTRO"), 6000) end)
    end
    d.retry = getTickCount() + 2000
end

Activity.perk("taxi_nitro", function() end)

Activity.register("taxi", {
    title = "TAXI_M",
    gxt = "TAXI1",
    launch = { vehicles = taxis, help = "TTUTOR" },
    start = function(session)
        local d = session.data
        d.streak, d.earned, d.retry = 0, 0, 0
        session:big(session:text("TAXI_M"), 4000, "title")
        session:every(500, function(s)
            local dd = s.data
            local now = getTickCount()
            local taxi = taxiOf(s)
            if not taxi then
                local v = getPedOccupiedVehicle(s.player)
                if v and taxis[getElementModel(v)] and isVehicleBlown(v) then return s:fail("TX_F3") end
                dd.outSince = dd.outSince or now
                if now - dd.outSince > T.outOfTaxiMs then return s:fail("TX_F1") end
                return
            end
            dd.outSince = nil
            if isVehicleBlown(taxi) then return s:fail("TX_F3") end
            if dd.deadline and now > dd.deadline then return s:fail("TX_F2") end
            if dd.fare and not isElement(dd.fare) or (dd.fare and isPedDead(dd.fare)) then
                clearFare(s)
                s:say(s:text("TX_OOPS"))
                dd.retry = now + 3000
                return
            end
            if getElementHealth(taxi) < T.junkHealth then
                if dd.fare and dd.destination then
                    s:say(s:text("TX_FLED"))
                    clearFare(s, "fled")
                elseif not dd.junkSaid or now - dd.junkSaid > 8000 then
                    dd.junkSaid = now
                    s:say(s:text("TX_REP"))
                end
                return
            end
            if not dd.fare then
                if now >= dd.retry then seekFare(s) end
                return
            end
            local x, y, z = getElementPosition(taxi)
            if not dd.destination then
                local px, py, pz = getElementPosition(dd.fare)
                if getDistanceBetweenPoints3D(x, y, z, px, py, pz) < T.pickupRadius and stopped(taxi) then pickedUp(s, taxi) end
                return
            end
            -- Damage eats the tip.
            local health = getElementHealth(taxi)
            if dd.lastHealth and health < dd.lastHealth then
                dd.tipPenalty = dd.tipPenalty + (dd.lastHealth - health) * T.damagePenaltyMs
            end
            dd.lastHealth = health
            local tipLeft = math.max(0, dd.tipUntil - dd.tipPenalty - now)
            s:counter("tip", s:text("TX_ADDS"), math.floor(tipLeft * 100 / math.max(1, dd.tipUntil - dd.tipStart)), "bar")
            local t = dd.destination
            if getDistanceBetweenPoints3D(x, y, z, t[1], t[2], t[3]) < T.dropRadius and stopped(taxi) then delivered(s) end
        end)
    end,
    stop = function(session, reason)
        local d = session.data
        if isElement(session.player) and reason ~= "quit" then
            session:big(session:text("TX_END"), 4000, "small")
            session:say(session:text("TX_PAY", d.earned or 0), 4000)
        end
    end,
})

-- The reward: nitro in every taxi its owner drives.
addEventHandler("onPlayerVehicleEnter", root, function(vehicle, seat)
    if seat == 0 and taxis[getElementModel(vehicle)] and Activity.hasPerk(source, "taxi_nitro") then
        addVehicleUpgrade(vehicle, 1010)
    end
end)

Activity.test("taxi", function()
    local x, y, z = Activity.streetSpot(2495, -1665, 13, 300, 1500, "vehicle", { 2495, -1665, 13 })
    local px = Activity.streetSpot(2495, -1665, 13, 60, 180, "ped")
    local ok = x ~= nil and px ~= nil and Gxt.raw("TX_PKUP", "TAXI1") ~= nil
    return ok, x and ("a destination from Grove Street: %.0f, %.0f"):format(x, y) or "no street spot found"
end)
