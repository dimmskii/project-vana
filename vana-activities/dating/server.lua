-- Dating (vanilla GF_MEETING / GFAGNT / GF_DATE / GF_SEX), per player. Meet her and talk to her
-- (conversation yes); if she likes what she sees she becomes your girlfriend. Stop your car at her
-- house when she isn't busy to take her on a date: food, a cruise or dancing, as she likes. Take her
-- home after a good date; she may ask you in for coffee. Her liking unlocks her car keys, a gift
-- outfit and her perk. Progress lives in vana-player ("gf.<key>.*").
local D = Dating
local girls = {}       -- key -> girl
local meetPeds = {}    -- key -> ped (shared NPC at her meeting spot)
local homeBlips = {}   -- player -> { key -> blip }
local cars = {}        -- player -> { key -> vehicle }
local busyNoted = {}   -- player -> { key -> hour } (the "not at home" note, once per block)
for i, g in ipairs(D.girls) do g.index = i girls[g.key] = g end

local function progress(player, key) return Activity.progress(player, key) end
local function setProgress(player, key, value) return Activity.setProgress(player, key, value) end

local function likesOf(player, g) return progress(player, "gf." .. g.key .. ".likes") end
local function isGirlfriend(player, g)
    return likesOf(player, g) ~= nil and not progress(player, "gf." .. g.key .. ".dumped")
end

local function say(player, text, ms)
    triggerClientEvent(player, "vana-activities:say", resourceRoot, text, ms or 5000)
end
local function help(player, text)
    triggerClientEvent(player, "vana-activities:help", resourceRoot, text, false)
end
local function text(key, ...) return Activity.text(key, nil, ...) end

-- Tells a player's client who their girlfriends are (for prompts and dates).
local function sendState(player)
    local state = {}
    for _, g in ipairs(D.girls) do
        state[g.key] = { likes = likesOf(player, g), dumped = progress(player, "gf." .. g.key .. ".dumped") == true }
    end
    triggerClientEvent(player, "vana-dating:state", resourceRoot, state, text("TALK_1"))
end

local function refreshBlips(player)
    homeBlips[player] = homeBlips[player] or {}
    for _, g in ipairs(D.girls) do
        local blip = homeBlips[player][g.key]
        local want = isGirlfriend(player, g)
        if want and not blip then
            homeBlips[player][g.key] = createBlip(g.home[1], g.home[2], g.home[3], D.blips.home, 2, 255, 255, 255, 255, 0, 16383, player)
        elseif not want and blip then
            destroyElement(blip)
            homeBlips[player][g.key] = nil
        end
    end
end

-- Vanilla's appraisal (GF_MEETING / GF_DATE): sex appeal / 10, her outfit, and fat and muscle against
-- her taste. Returns the score and what she'd say about the body (a GXT key or nil).
local function appraise(player, g)
    local score = math.floor((Activity.call("vana-shops", "getSexAppeal", player) or 0) / 10)
    local special = getPedClothes(player, 17)
    local gift = special and D.giftCostumes and D.giftCostumes[g.gift]
    if special and gift and special:lower() == gift then score = score + D.favouriteOutfitBonus end
    local remark
    local fat = math.floor(getPedStat(player, 21) / 20)
    if fat >= 25 then
        if g.traits == "fat" then score = score + fat else score = score - fat remark = "GF_0053" end
    elseif g.traits == "fat" then
        score = score - fat remark = "GF_0074"
    elseif g.traits == "slim" then
        score = score + (fat == 0 and 5 or fat)
    end
    local muscle = math.floor(getPedStat(player, 23) / 20)
    if muscle >= 20 then
        if g.traits == "muscle" then score = score + muscle elseif g.traits == "slim" then score = score - muscle remark = "GF_0075" end
    elseif g.traits == "muscle" then
        score = score - muscle remark = remark or "GF_0053"
    end
    return score, remark
end

local function busy(g)
    local h = getTime()
    for _, b in ipairs(g.busy) do
        if h == b or h == (b + 1) % 24 then return true end
    end
    return false
end

-- Liking changes, rewards and break-ups.

local function changeLikes(player, g, delta)
    local likes = math.max(-100, math.min(100, (likesOf(player, g) or 0) + delta))
    setProgress(player, "gf." .. g.key .. ".likes", likes)
    if likes <= D.dumped then
        setProgress(player, "gf." .. g.key .. ".dumped", true)
        if g.perk then setProgress(player, "perk." .. g.perk, false) end
        say(player, text("GF_0011"), 6000)
    else
        if likes >= D.keysAt and not progress(player, "gf." .. g.key .. ".keys") then
            setProgress(player, "gf." .. g.key .. ".keys", true)
            help(player, text(g.keys))
        end
        if likes >= D.giftAt and not progress(player, "gf." .. g.key .. ".gift") then
            setProgress(player, "gf." .. g.key .. ".gift", true)
            Activity.call("vana-player", "grantOwned", player, "special", g.gift)
            help(player, text("GF_H006"))
        end
    end
    refreshBlips(player)
    sendState(player)
    return likes
end

-- Meeting.
local function becomeGirlfriend(player, g)
    setProgress(player, "gf." .. g.key .. ".likes", g.likes)
    setProgress(player, "gf." .. g.key .. ".dumped", false)
    if g.perk == "free_busted" or g.perk == "free_wasted" then Activity.grantPerk(player, g.perk) end
    help(player, g.girlfriend and text(g.girlfriend)
        or (g.name .. " is your girlfriend now. Keep her happy and she'll love you.~N~To take her on a date just stop by her house."))
    refreshBlips(player)
    sendState(player)
end

addEvent("vana-dating:answer", true)
addEventHandler("vana-dating:answer", resourceRoot, function(key, yes)
    local player = client
    local g = girls[key]
    local ped = g and meetPeds[key]
    if not ped or not isElement(ped) or isGirlfriend(player, g) or progress(player, "gf." .. key .. ".dumped") then return end
    local x, y, z = getElementPosition(player)
    local px, py, pz = getElementPosition(ped)
    if getDistanceBetweenPoints3D(x, y, z, px, py, pz) > 4 then return end
    if not yes then return say(player, text(g.reply.no)) end
    local score, remark = appraise(player, g)
    if score >= g.appeal then
        say(player, text(g.reply.yes))
        becomeGirlfriend(player, g)
    else
        say(player, text(g.reply.no))
        setTimer(function() if isElement(player) then say(player, text(remark or "GF_0052")) end end, 5000, 1)
    end
end)

-- Dates.
local function nearestVenues(kinds, x, y, limit)
    local found = {}
    for kind in pairs(kinds) do
        for _, v in ipairs(D.venues[kind] or {}) do
            found[#found + 1] = { kind = kind, x = v[1], y = v[2], z = v[3], d = getDistanceBetweenPoints2D(x, y, v[1], v[2]) }
        end
    end
    table.sort(found, function(a, b) return a.d < b.d end)
    for i = #found, limit + 1, -1 do found[i] = nil end
    return found
end

local function likedFoods(g)
    local kinds = {}
    for _, k in ipairs({ "diner", "bar", "restaurant", "fastfood" }) do if g.dates[k] then kinds[k] = true end end
    return kinds
end

local function chooseDate(player, g)
    local likes = likesOf(player, g) or 0
    if g.dates.kinky and getPedClothes(player, 17) == "gimpleg" then return "cruise", "GF_0044" end
    if likes <= 30 then return "food", "GF_0026" end
    local r = math.random(0, 45)
    if r <= 10 then return "food", "GF_0026" end
    if r <= 20 or r > 35 then return "cruise", "GF_0027" end
    return "dance", "GF_0028"
end

local function clearVenueBlips(session)
    for _, b in ipairs(session.data.venueBlips or {}) do
        if isElement(b) then destroyElement(session:disown(b)) end
    end
    session.data.venueBlips = {}
end

local function goHome(session, textKey)
    local d = session.data
    clearVenueBlips(session)
    session:clearCounter("fun")
    d.phase = "home"
    session:say(session:text(textKey or "GF_0022"))
    d.homeBlip = session:blip({ d.girl.home[1], d.girl.home[2], d.girl.home[3] }, D.blips.home)
end

-- A bad date: she's had enough and goes home on her own.
local function badDate(session, textKey)
    local d = session.data
    changeLikes(session.player, d.girl, D.badDate)
    session:say(session:text(textKey or "GF_0034"), 6000)
    if isElement(d.ped) then
        removePedFromVehicle(d.ped)
        session:disown(d.ped)
        local ped = d.ped
        setTimer(function() if isElement(ped) then destroyElement(ped) end end, 20000, 1)
        triggerClientEvent(session.player, "vana-dating:leave", resourceRoot, ped)
    end
    d.ped = nil
    session:stop("bad")
end

local function venueReached(session, venue)
    local d = session.data
    d.phase = "venue"
    clearVenueBlips(session)
    triggerClientEvent(session.player, "vana-dating:venue", resourceRoot, d.kind, venue.x, venue.y, venue.z)
    if d.kind == "food" then
        session:after(4000, function(s)
            if s.data.girl.dates[venue.kind] then
                goHome(s, "GF_0065")
            else
                badDate(s, "GF_0055")
            end
        end)
    end
end

addEvent("vana-dating:danced", true)
addEventHandler("vana-dating:danced", resourceRoot, function(share)
    local session = Activity.of(client)
    if not session or session.name ~= "date" or session.data.phase ~= "venue" or type(share) ~= "number" then return end
    if share >= D.dance.goodShare then goHome(session, "GF_0054") else badDate(session, "GF_0056") end
end)

-- The cruise: vanilla's fun meter, checked each second.
local function cruiseTick(session, report)
    local d = session.data
    local g = d.girl
    local f = D.fun
    local vehicle = getPedOccupiedVehicle(session.player)
    if not vehicle or getPedOccupiedVehicle(d.ped) ~= vehicle then return end
    local delta = f.boredom
    local vx, vy, vz = getElementVelocity(vehicle)
    local speed = math.sqrt(vx * vx + vy * vy + vz * vz) * 50 -- m/s
    local x, y, z = getElementPosition(vehicle)
    local _, zone = Activity.call("vana-population", "getZoneAt", x, y, z)
    local zoneType = type(zone) == "table" and zone.type
    for area, types in pairs(D.areas) do
        if g.dates[area] and zoneType and types[zoneType] then delta = delta + f.area end
    end
    if g.dates.speed then delta = delta + (speed > f.fastSpeed and f.speed or f.slow * 0.2) end
    if g.dates.moderate and speed > 1 then
        delta = delta + ((speed > f.moderateMin and speed < f.moderateMax) and f.moderate or f.slow * 0.2)
    end
    if g.dates.jumps and report and report.airborne then delta = delta + f.jump end
    local health = getElementHealth(vehicle)
    if d.lastHealth and health < d.lastHealth - 1 then
        delta = delta + (g.dates.crashes and f.crash or f.damage)
    end
    d.lastHealth = health
    if g.dates.radio and report and report.radio == g.dates.radio then delta = delta + f.radio end
    local h = getTime()
    if g.dates.parking and speed < 0.5 and (h >= 20 or h < 6) and zoneType and (zoneType == "park" or zoneType == "countryside") then
        delta = delta + f.parking
    end
    d.fun = math.max(0, math.min(100, d.fun + delta))
    session:counter("fun", session:text("GF_0029"), d.fun, "bar")
    if d.fun >= 100 then
        goHome(session, ({ "GF_0007", "GF_0008", "GF_0009" })[math.random(3)])
    elseif d.fun <= 0 then
        badDate(session, "GF_0032")
    elseif d.fun < 20 and not d.warned then
        d.warned = true
        session:say(session:text("GF_0078"))
    elseif d.fun >= 30 then
        d.warned = false
    end
end

addEvent("vana-dating:report", true)
addEventHandler("vana-dating:report", resourceRoot, function(report)
    local session = Activity.of(client)
    if session and session.name == "date" and session.data.phase == "out" and session.data.kind == "cruise" and type(report) == "table" then
        cruiseTick(session, report)
    end
end)

-- Home again: a good date, maybe coffee.
local function arrivedHome(session)
    local d = session.data
    local g = d.girl
    local player = session.player
    local likes = changeLikes(player, g, D.goodDate)
    if isElement(d.ped) then removePedFromVehicle(d.ped) end
    if likes >= D.coffeeAt then
        session:say(session:text("GF_0014"), 5000)
        triggerClientEvent(player, "vana-dating:coffee", resourceRoot, g.home, D.coffeeMs)
        session:after(D.coffeeMs, function(s)
            Activity.setProgress(player, "gf." .. g.key .. ".coffee", (Activity.progress(player, "gf." .. g.key .. ".coffee") or 0) + 1)
            s:pass("GF_0033", 0)
        end)
    else
        session:after(3000, function(s) s:pass("GF_0033", 0) end)
    end
end

Activity.register("date", {
    title = "Date",
    wastedText = nil,
    start = function(session, g, vehicle)
        local d = session.data
        d.girl, d.vehicle, d.fun, d.phase, d.venueBlips = g, vehicle, D.fun.start, "pickup", {}
        local h = g.home
        local ped = session:ped(g.model, h[1], h[2], h[3] + 1, h[4])
        d.ped = ped
        setElementSyncer(ped, session.player, true, true)
        setElementData(ped, "vana:date", true)
        session:say(session:text("GF_0004"), 3000)
        triggerClientEvent(session.player, "vana-dating:pickup", resourceRoot, ped, vehicle)
        -- She walks to the car; if she isn't in after 8 s she gets in anyway (vanilla warps her too).
        session:after(8000, function(s)
            if isElement(s.data.ped) and not getPedOccupiedVehicle(s.data.ped) and isElement(s.data.vehicle) then
                warpPedIntoVehicle(s.data.ped, s.data.vehicle, 1)
            end
        end)
        session:after(2500, function(s)
            local score, remark = appraise(s.player, g)
            if score < g.appeal and remark then
                s:say(s:text(remark), 4000)
                changeLikes(s.player, g, -1)
            end
            local kind, line = chooseDate(s.player, g)
            s.data.kind, s.data.phase = kind, "out"
            s:after(4000, function(ss) ss:say(ss:text(line), 5000) end)
            if kind == "food" then
                s:help(s:text("GF_0036"))
                local x, y = getElementPosition(s.player)
                for _, v in ipairs(nearestVenues({ diner = true, bar = true, restaurant = true, fastfood = true }, x, y, 8)) do
                    local blip = s:blip({ v.x, v.y, v.z }, D.blips[v.kind])
                    table.insert(s.data.venueBlips, blip)
                    setElementData(blip, "vana:venue", v, false)
                end
            elseif kind == "dance" then
                s:help(s:text("GF_0038"))
                local x, y = getElementPosition(s.player)
                for _, v in ipairs(nearestVenues({ disco = true }, x, y, 3)) do
                    local blip = s:blip({ v.x, v.y, v.z }, D.blips.disco)
                    table.insert(s.data.venueBlips, blip)
                    setElementData(blip, "vana:venue", v, false)
                end
            else
                s:help(s:text("GF_0037"))
                s:counter("fun", s:text("GF_0029"), s.data.fun, "bar")
                s.data.lastHealth = isElement(s.data.vehicle) and getElementHealth(s.data.vehicle) or nil
            end
            triggerClientEvent(s.player, "vana-dating:date", resourceRoot, kind, g.dates.radio)
        end)
        -- Every second: abandonment, venues, getting her home.
        session:every(1000, function(s)
            local dd = s.data
            if not isElement(dd.ped) or isPedDead(dd.ped) then
                s:say(s:text("GF_0039"))
                return s:stop("dead")
            end
            local x, y, z = getElementPosition(s.player)
            local px, py, pz = getElementPosition(dd.ped)
            if getDistanceBetweenPoints3D(x, y, z, px, py, pz) > D.abandonRadius then
                changeLikes(s.player, g, D.abandoned)
                s:say(s:text("GF_H017"))
                return s:stop("abandoned")
            end
            local vehicle = getPedOccupiedVehicle(s.player)
            local stopped = vehicle and getVehicleController(vehicle) == s.player and getPedOccupiedVehicle(dd.ped) == vehicle
            if stopped then
                local vx, vy, vz = getElementVelocity(vehicle)
                stopped = vx * vx + vy * vy + vz * vz < 0.0004
            end
            if dd.phase == "out" and (dd.kind == "food" or dd.kind == "dance") and stopped then
                for _, blip in ipairs(dd.venueBlips) do
                    local v = isElement(blip) and getElementData(blip, "vana:venue")
                    if v and getDistanceBetweenPoints2D(x, y, v.x, v.y) < D.venueRadius then
                        venueReached(s, v)
                        break
                    end
                end
            elseif dd.phase == "home" and stopped and getDistanceBetweenPoints2D(x, y, g.home[1], g.home[2]) < D.pickupRadius then
                dd.phase = "done"
                arrivedHome(s)
            end
        end)
    end,
    stop = function(session, reason)
        local d = session.data
        if isElement(session.player) then
            triggerClientEvent(session.player, "vana-dating:over", resourceRoot)
            if reason == "failed" then changeLikes(session.player, d.girl, D.abandoned) end
        end
    end,
})

-- She was hurt by her date: the date is over (GF_H018).
addEvent("vana-dating:hurt", true)
addEventHandler("vana-dating:hurt", resourceRoot, function()
    local session = Activity.of(client)
    if session and session.name == "date" and session.data.phase ~= "done" then
        changeLikes(client, session.data.girl, D.abandoned)
        session:say(session:text("GF_H018"))
        session:stop("abused")
    end
end)

-- Pick-ups, her car, her perks: checked for every player each second.
local function carFor(player, g)
    cars[player] = cars[player] or {}
    local car = cars[player][g.key]
    local x, y = getElementPosition(player)
    local d = getDistanceBetweenPoints2D(x, y, g.car.x, g.car.y)
    if progress(player, "gf." .. g.key .. ".keys") and isGirlfriend(player, g) then
        if (not car or not isElement(car)) and d < 200 then
            car = createVehicle(g.car.model, g.car.x, g.car.y, g.car.z, 0, 0, g.car.rz, g.car.plate)
            setElementData(car, "vana:owner", player, false)
            cars[player][g.key] = car
        elseif car and isElement(car) and d > 400 and not getVehicleOccupant(car) then
            destroyElement(car)
            cars[player][g.key] = nil
        end
    elseif car and isElement(car) then
        destroyElement(car)
        cars[player][g.key] = nil
    end
end

setTimer(function()
    for _, player in ipairs(getElementsByType("player")) do
        if not isPedDead(player) then
            local x, y, z = getElementPosition(player)
            local vehicle = getPedOccupiedVehicle(player)
            for _, g in ipairs(D.girls) do
                if isGirlfriend(player, g) then
                    carFor(player, g)
                    local near = getDistanceBetweenPoints2D(x, y, g.home[1], g.home[2])
                    local session = Activity.of(player)
                    if vehicle and not session and near < D.pickupRadius and getVehicleController(vehicle) == player then
                        local vx, vy, vz = getElementVelocity(vehicle)
                        if vx * vx + vy * vy + vz * vz < 0.0004 then
                            if g.perk == "repair" and getElementHealth(vehicle) < 1000 then
                                fixVehicle(vehicle)
                                say(player, g.name .. " fixed your car.", 3000)
                            end
                            if busy(g) then
                                busyNoted[player] = busyNoted[player] or {}
                                if busyNoted[player][g.key] ~= getTime() then
                                    busyNoted[player][g.key] = getTime()
                                    help(player, text("GF_0048"))
                                end
                            elseif getVehicleMaxPassengers(vehicle) and getVehicleMaxPassengers(vehicle) > 0 and not getVehicleOccupant(vehicle, 1) then
                                Activity.start(player, "date", g, vehicle)
                            end
                        end
                    elseif not vehicle and g.perk == "stash" and near < 4 then
                        local day = getRealTime().yearday
                        if progress(player, "gf.helena.stash") ~= day then
                            setProgress(player, "gf.helena.stash", day)
                            for _, w in ipairs(D.stash) do giveWeapon(player, w[1], w[2]) end
                            say(player, "Helena left you something from her stash.", 4000)
                        end
                    end
                end
            end
        end
    end
end, 1000, 0)

-- Her car is only yours.
addEventHandler("onVehicleStartEnter", root, function(player, seat)
    local owner = getElementData(source, "vana:owner")
    if owner and owner ~= player and seat == 0 then cancelEvent() end
end)

-- Meeting NPCs: each girl waits at her meeting spot (Helena and Katie at tai chi, as in vanilla).
local function spawnMeeting(g)
    local m = g.meet
    local ped = createPed(g.model, m[1], m[2], m[3] + 1, m[4])
    if not ped then return end
    setElementInterior(ped, m.interior or 0)
    setElementFrozen(ped, true)
    setElementData(ped, "vana:girl", g.key)
    if g.key == "helena" or g.key == "katie" then
        setPedAnimation(ped, "PARK", "Tai_Chi_Loop", -1, true, false, false)
    end
    meetPeds[g.key] = ped
end

addEventHandler("onPedWasted", root, function()
    local key = getElementData(source, "vana:girl")
    if not key or meetPeds[key] ~= source then return end
    local ped = source
    setTimer(function()
        if isElement(ped) then destroyElement(ped) end
        spawnMeeting(girls[key])
    end, 60000, 1)
end)

addEventHandler("onResourceStart", resourceRoot, function()
    for _, g in ipairs(D.girls) do spawnMeeting(g) end
    for _, player in ipairs(getElementsByType("player")) do
        setTimer(function() if isElement(player) then refreshBlips(player) sendState(player) end end, 2000, 1)
    end
end)

addEventHandler("onPlayerSpawn", root, function()
    local player = source
    setTimer(function() if isElement(player) then refreshBlips(player) sendState(player) end end, 1500, 1)
end)

addEventHandler("onPlayerQuit", root, function()
    for _, blip in pairs(homeBlips[source] or {}) do if isElement(blip) then destroyElement(blip) end end
    for _, car in pairs(cars[source] or {}) do if isElement(car) and not getVehicleOccupant(car) then destroyElement(car) end end
    homeBlips[source], cars[source], busyNoted[source] = nil, nil, nil
end)

Activity.test("dating", function()
    local ok, missing = true, {}
    for _, g in ipairs(D.girls) do
        for _, key in ipairs({ g.reply.yes, g.reply.no, g.keys }) do
            if not Gxt.raw(key) then ok = false missing[#missing + 1] = key end
        end
    end
    for _, key in ipairs({ "GF_0004", "GF_0014", "GF_0026", "GF_0027", "GF_0028", "GF_0029", "GF_0033", "GF_0036", "GF_H006", "GF_H017" }) do
        if not Gxt.raw(key) then ok = false missing[#missing + 1] = key end
    end
    local alive = 0
    for _, ped in pairs(meetPeds) do if isElement(ped) and not isPedDead(ped) then alive = alive + 1 end end
    ok = ok and alive == #D.girls
    return ok, ("%d girlfriends, %d waiting at their spots%s"):format(#D.girls, alive, #missing > 0 and (", missing text " .. table.concat(missing, " ")) or "")
end)
