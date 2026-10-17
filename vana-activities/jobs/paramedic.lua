-- Paramedic (vanilla AMBULAN): in an ambulance, press the sub-mission key. Level N has N patients to
-- bring to hospital before the clock runs out, gently: hard bumps hurt them. Each level pays level x
-- level x $50; finishing level 12 pays $5000 and raises your maximum health.
local P = Jobs.paramedic
local ambulances = Job.set(P.vehicles)

local function seatsFree(vehicle)
    local free = 0
    for seat = 1, getVehicleMaxPassengers(vehicle) or 0 do
        if not getVehicleOccupant(vehicle, seat) then free = free + 1 end
    end
    return free
end

local function freeSeat(vehicle)
    for seat = 1, getVehicleMaxPassengers(vehicle) or 0 do
        if not getVehicleOccupant(vehicle, seat) then return seat end
    end
end

-- A level: N injured people around the player, and the time to save them.
local function startLevel(session)
    local d = session.data
    local x, y, z = getElementPosition(session.player)
    d.patients, d.saved = {}, 0
    local total = 0
    for _ = 1, d.level do
        local px, py, pz = Activity.streetSpot(x, y, z, P.patientRange[1], P.patientRange[2], "ped")
        if px then
            local ped = session:ped(Job.civilian(), px, py, pz + 1, math.random(0, 359))
            setPedAnimation(ped, "CRACK", "crckidle2", -1, true, false, false)
            local patient = { ped = ped, life = 100, blip = session:blip(ped, 0, 80, 120, 255, 2) }
            d.patients[#d.patients + 1] = patient
            local h = Job.nearest(P.hospitals, px, py, pz)
            local route = getDistanceBetweenPoints3D(x, y, z, px, py, pz) + getDistanceBetweenPoints3D(px, py, pz, h[1], h[2], h[3])
            total = total + math.max(P.patientMs[1], math.min(P.patientMs[2], route * P.msPerMetre))
        end
    end
    d.level = #d.patients > 0 and d.level or d.level
    d.deadline = getTickCount() + math.max(P.minimumMs, total)
    session:counter("level", session:text("ALEV"), d.level, "number")
    session:counter("time", session:text("AMBTIME"), d.deadline - getTickCount(), "timer")
    session:big(session:text("ALEVEL", d.level), 3000, "small")
end

local function hospitalBlip(session, on)
    local d = session.data
    if on and not d.hospital then
        local x, y, z = getElementPosition(session.player)
        local h = Job.nearest(P.hospitals, x, y, z)
        d.hospital = h
        d.hospitalBlip = session:blip(h, 22, 255, 255, 0)
        d.hospitalMarker = session:marker("checkpoint", h[1], h[2], h[3], 6, 255, 255, 0, 120)
    elseif not on and d.hospital then
        destroyElement(session:disown(d.hospitalBlip))
        destroyElement(session:disown(d.hospitalMarker))
        d.hospital = nil
    end
end

local function levelDone(session)
    local d = session.data
    local player = session.player
    local pay = d.level * d.level * P.pay
    givePlayerMoney(player, pay)
    session:big(session:text("REWARD", pay), 4000, "small")
    local best = Activity.progress(player, "paramedic.level") or 0
    if d.level > best then Activity.setProgress(player, "paramedic.level", d.level) end
    Activity.setProgress(player, "paramedic.saved", (Activity.progress(player, "paramedic.saved") or 0) + d.level)
    if d.level == P.levels then
        givePlayerMoney(player, P.completeBonus)
        if Activity.grantPerk(player, "paramedic") then
            session:after(4000, function(s)
                s:big(s:text("A_COMP1", P.completeBonus), 5000, "passed")
                s:say(s:text("A_COMP3"), 5000)
            end)
        end
    end
    d.level = d.level + 1
    session:after(4500, startLevel)
end

-- The reward: maximum health raised to the top (vanilla: x1.5).
Activity.perk("paramedic", function(player) setPedStat(player, 24, 1000) end)

Activity.register("paramedic", {
    title = "AMBUL_M",
    gxt = "AMBULAE",
    cancelText = "A_CANC",
    launch = { vehicles = ambulances, help = "ATUTOR" },
    start = function(session)
        local d = session.data
        d.level = 1
        session:big(session:text("AMBUL_M"), 4000, "title")
        session:say(session:text("ATUTOR2"), 6000)
        session:after(1500, startLevel)
        session:every(500, function(s)
            local dd = s.data
            local v = Job.watchVehicle(s, ambulances, P.outMs, "A_FAIL1", "A_CANC")
            if not v or not dd.patients then return end
            local now = getTickCount()
            if now > dd.deadline then return s:fail("A_FAIL2") end
            -- Bumps hurt everyone aboard.
            local health = getElementHealth(v)
            if dd.lastHealth and dd.lastHealth - health >= P.bump then
                for _, p in ipairs(dd.patients) do
                    if p.aboard then
                        p.life = p.life - (dd.lastHealth - health) / 2
                        if p.life <= 0 then return s:fail("A_FAIL3") end
                    end
                end
            end
            dd.lastHealth = health
            local x, y, z = getElementPosition(v)
            local aboard = 0
            for _, p in ipairs(dd.patients) do
                if not p.saved and (not isElement(p.ped) or isPedDead(p.ped)) then return s:fail("A_FAIL3") end
                if p.aboard then aboard = aboard + 1 end
                if not p.aboard and not p.saved then
                    local px, py, pz = getElementPosition(p.ped)
                    if getDistanceBetweenPoints3D(x, y, z, px, py, pz) < P.pickupRadius and Job.stopped(v) then
                        local seat = freeSeat(v)
                        if seat then
                            setPedAnimation(p.ped)
                            warpPedIntoVehicle(p.ped, v, seat)
                            p.aboard = true
                            destroyElement(s:disown(p.blip))
                            aboard = aboard + 1
                        elseif not dd.fullSaid or now - dd.fullSaid > 5000 then
                            dd.fullSaid = now
                            s:say(s:text("A_FULL"), 3000)
                        end
                    end
                end
            end
            s:counter("seats", s:text("AMBSEAT"), seatsFree(v), "number")
            hospitalBlip(s, aboard > 0)
            local h = dd.hospital
            if h and getDistanceBetweenPoints3D(x, y, z, h[1], h[2], h[3]) < P.dropRadius and Job.stopped(v) then
                for _, p in ipairs(dd.patients) do
                    if p.aboard then
                        p.aboard, p.saved = false, true
                        dd.saved = dd.saved + 1
                        local ped = s:disown(p.ped)
                        removePedFromVehicle(ped)
                        setTimer(function() if isElement(ped) then destroyElement(ped) end end, 8000, 1)
                    end
                end
                hospitalBlip(s, false)
                s:say(s:text("A_PASS"), 2000)
                if dd.saved >= #dd.patients then
                    dd.patients = nil
                    levelDone(s)
                end
            end
        end)
    end,
    stop = function(session, reason)
        if isElement(session.player) and reason ~= "quit" and reason ~= "failed" then
            session:big(session:text("A_FAIL1"), 4000, "small")
        end
    end,
})

Activity.test("paramedic", function()
    local ok = #Jobs.paramedic.hospitals == 8 and Gxt.raw("ALEVEL", "AMBULAE") ~= nil and Gxt.raw("REWARD") ~= nil
    return ok, ("%d hospitals, %d levels"):format(#Jobs.paramedic.hospitals, Jobs.paramedic.levels)
end)
