-- Dancing (vanilla DANCE) on the club floors and the lowrider contest (vanilla LOWR / LOWGAME): the
-- rhythm game (games/rhythm_client.lua) on the routine playing at that music zone, so everyone there
-- hears the same song and sees the moves on its beats: vana-radio plays the zone's station from its
-- speakers; dancers' moves are animations set here (synced), lowriders bounce on their own hydraulics.
-- Dancing keeps your best score; the lowrider contest is a wager against the opposition, paid double
-- if you outscore it.
local D, L = Games.dance, Games.lowrider

local function radio(fn, ...)
    local res = getResourceFromName("vana-radio")
    if not res or getResourceState(res) ~= "running" then return end
    local ok, result = pcall(function(...) return exports["vana-radio"][fn](exports["vana-radio"], ...) end, ...)
    return ok and result or nil
end

-- The routine to join on a zone's station: the one playing if at least half its beats are still
-- ahead (readyMs from now), else the next one. { beats = { { at, key } } (getTickCount, the server's
-- clock), endAt, beat (vanilla's beat-track number) }, or nil without vana-radio.
local function routine(station, readyMs)
    local segs = radio("getStationSegments", station)
    if not segs then return end
    local now = getTickCount()
    for _, seg in ipairs(segs) do
        local beats = seg.track and radio("getBeats", seg.track)
        if beats then
            local list, total, endAt = {}, 0, nil
            for _, b in ipairs(beats) do
                if b[2] == 33 then
                    endAt = seg.at + b[1]
                else
                    total = total + 1
                    if seg.at + b[1] > now + readyMs then list[#list + 1] = { seg.at + b[1], b[2] } end
                end
            end
            if #list > 0 and #list >= total / 2 then
                return { beats = list, endAt = endAt or seg.at + seg.length, beat = seg.beat }
            end
        end
    end
end

-- The game's lines for the rhythm game (DNC_*, LOWR*).
local function texts()
    local t = { score = Activity.text("DNC_001"), player = Activity.text("LOWR1"), opposition = Activity.text("LOWR2"),
                ratings = { Activity.text("DNC_003"), Activity.text("DNC_004"), Activity.text("DNC_002") }, feedback = {} }
    for set = 0, 2 do
        local lines = {}
        for i = 1, 7 do lines[i] = Activity.text(("DNC_%03d"):format(5 + set * 7 + i - 1)) end
        t.feedback[set + 1] = lines
    end
    return t
end

local function floorOf(player)
    local x, y, z = getElementPosition(player)
    for _, f in ipairs(D.floors) do
        if getElementInterior(player) == f.interior and getDistanceBetweenPoints3D(x, y, z, f.x, f.y, f.z) < 5 then return f end
    end
end

Activity.register("dance", {
    title = "Dance",
    start = function(session, floor)
        local p = session.player
        local r = floor and routine(floor.station, D.readyMs)
        local block = D.blocks[r and r.beat or 1] or "GFUNK"
        session.data.block, session.data.move, session.data.misses = block, 0, 0
        setElementFrozen(p, true)
        setPedAnimation(p, block, "DANCE_LOOP", -1, true, false, false)
        local opts = { rules = "dance", title = "Dance", text = texts() }
        if r then
            opts.beats, opts.endAt, opts.serverClock = r.beats, r.endAt, true
        else
            opts.count, opts.beatMs = D.count, D.beatMs
        end
        triggerClientEvent(p, "vana-dance:start", resourceRoot, "dance", opts)
    end,
    stop = function(session)
        if isElement(session.player) then
            setElementFrozen(session.player, false)
            setPedAnimation(session.player)
            triggerClientEvent(session.player, "vana-dance:start", resourceRoot, nil)
        end
    end,
})

-- Each judged beat: the dancer's next move, as DANCE plays them (hits DANCE_G1..G16 in turn, misses
-- DANCE_B1..B16), then back to the loop if nothing follows.
addEvent("vana-dance:beat", true)
addEventHandler("vana-dance:beat", resourceRoot, function(grade)
    local s = Activity.of(client)
    if not s or s.name ~= "dance" or type(grade) ~= "string" then return end
    local now = getTickCount()
    if s.data.lastBeat and now - s.data.lastBeat < 100 then return end
    s.data.lastBeat = now
    local hit = grade == "perfect" or grade == "good" or grade == "ok"
    local anim
    if hit then
        s.data.move = s.data.move % 16 + 1
        anim = "DANCE_G" .. s.data.move
    else
        s.data.misses = s.data.misses % 16 + 1
        anim = "DANCE_B" .. s.data.misses
    end
    setPedAnimation(client, s.data.block, anim, -1, false, false, false, true)
    local player, block = client, s.data.block
    if isTimer(s.data.idle) then killTimer(s.data.idle) end
    s.data.idle = setTimer(function()
        local ss = Activity.of(player)
        if ss and ss.name == "dance" then setPedAnimation(player, block, "DANCE_LOOP", -1, true, false, false) end
    end, D.idleMs, 1)
end)

Activity.register("lowrider", {
    title = "Lowrider",
    start = function(session, wager)
        local p = session.player
        session.data.wager = wager
        -- The opposition gets better with every contest, more so the bigger the bet (LOWR).
        local skill = math.max(1, Activity.progress(p, "lowrider.skill") or 1)
        skill = math.min(5, skill + math.floor(4 * wager / L.maxBet))
        Activity.setProgress(p, "lowrider.skill", skill)
        local r = routine(L.station, L.readyMs)
        local opts = { rules = "lowrider", title = Activity.text("LOWR"), text = texts() }
        local n
        if r then
            opts.beats, opts.endAt, opts.serverClock = r.beats, r.endAt, true
            n = #r.beats
        else
            opts.count, opts.beatMs = L.count, L.beatMs
            n = L.count
        end
        -- The opposition's points, one roll per beat; the server keeps the total to settle the bet.
        local rolls, total = {}, 0
        for i = 1, n do
            rolls[i] = L.rival[skill][math.random(10)]
            total = total + rolls[i]
        end
        opts.rival = rolls
        session.data.rival, session.data.beats = total, n
        triggerClientEvent(p, "vana-dance:start", resourceRoot, "lowrider", opts)
    end,
    stop = function(session)
        if isElement(session.player) then triggerClientEvent(session.player, "vana-dance:start", resourceRoot, nil) end
    end,
})

addEvent("vana-dance:done", true)
addEventHandler("vana-dance:done", resourceRoot, function(share, points)
    local s = Activity.of(client)
    if not s or (s.name ~= "dance" and s.name ~= "lowrider") or type(share) ~= "number" then return end
    points = math.max(0, math.floor(tonumber(points) or 0))
    if s.name == "dance" then
        if points > (Activity.progress(client, "dance.best") or 0) then
            Activity.setProgress(client, "dance.best", points)
            s:big("NEW BEST SCORE~n~~w~" .. points, 3500, "small")
        else
            s:big(Activity.text("DNC_001") .. " " .. points, 3500, "small")
        end
        return s:after(3000, function(ss) ss:stop("done") end)
    end
    -- At most 50 points a beat, x10 while rated PERFECT.
    points = math.min(points, 500 * (s.data.beats or 0))
    local won = points > s.data.rival
    if won then givePlayerMoney(client, s.data.wager * 2) end
    s:big(won and Activity.text("WINNER", nil, s.data.wager * 2) or Activity.text("LOSER", nil, s.data.wager), 4000, won and "passed" or "failed")
    s:after(3500, function(ss) ss:stop("done") end)
end)

addEventHandler("onResourceStart", resourceRoot, function()
    for _, f in ipairs(D.floors) do
        local m = createMarker(f.x, f.y, f.z - 0.1, "cylinder", 1.5, 255, 120, 220, 110)
        setElementInterior(m, f.interior)
        addEventHandler("onMarkerHit", m, function(player, matching)
            if matching and getElementType(player) == "player" and not getPedOccupiedVehicle(player) and not Activity.of(player) then
                Activity.start(player, "dance", floorOf(player) or f)
            end
        end)
    end
    -- The lowrider contest: any car with hydraulics (the mod garages fit them to all) into the marker, then the wager.
    local m = createMarker(L.x, L.y, L.z - 0.5, "cylinder", 5, 255, 200, 0, 100)
    MapPoints.set("lowrider", { category = "lowrider", x = L.x, y = L.y, z = L.z })
    addEventHandler("onMarkerHit", m, function(player, matching)
        local v = matching and getElementType(player) == "player" and getPedOccupiedVehicle(player)
        if not v or Activity.of(player) then return end
        if getVehicleUpgradeOnSlot(v, 9) ~= L.hydraulics then
            return triggerClientEvent(player, "vana-activities:say", resourceRoot, "You must have hydraulics for this.", 4000)
        end
        local items = {}
        local amounts = {}
        local a = L.minBet
        while a <= L.maxBet do
            amounts[#amounts + 1] = a
            items[#items + 1] = { label = "$" .. a }
            a = a < 500 and a + 50 or a + 250
        end
        Activity.menu(player, Activity.text("LOWR"), items, function(p, i)
            if Activity.of(p) or getPlayerMoney(p) < amounts[i] then return end
            takePlayerMoney(p, amounts[i])
            Activity.start(p, "lowrider", amounts[i])
        end, "Choose your wager   Enter: bet   Backspace: leave")
    end)
end)
