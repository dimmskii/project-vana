-- Dancing (vanilla DANCE) on the club floors and the lowrider contest (vanilla LOWR): the rhythm game
-- (games/rhythm_client.lua). Dancing keeps your best score; the lowrider contest is a wager against a
-- rival's hydraulics, paid double if you out-bounce them.
local D, L = Games.dance, Games.lowrider

Activity.register("dance", {
    title = "Dance",
    start = function(session)
        setElementFrozen(session.player, true)
        setPedAnimation(session.player, "DANCING", D.anims[math.random(#D.anims)], -1, true, false, false)
        triggerClientEvent(session.player, "vana-dance:start", resourceRoot, "dance", { beats = D.beats, beatMs = D.beatMs, title = "Dance" })
    end,
    stop = function(session)
        if isElement(session.player) then
            setElementFrozen(session.player, false)
            setPedAnimation(session.player)
            triggerClientEvent(session.player, "vana-dance:start", resourceRoot, nil)
        end
    end,
})

Activity.register("lowrider", {
    title = "Lowrider",
    start = function(session, wager)
        session.data.wager = wager
        triggerClientEvent(session.player, "vana-dance:start", resourceRoot, "lowrider", { beats = L.beats, beatMs = L.beatMs, title = Activity.text("LOWR") })
    end,
    stop = function(session)
        if isElement(session.player) then triggerClientEvent(session.player, "vana-dance:start", resourceRoot, nil) end
    end,
})

addEvent("vana-dance:done", true)
addEventHandler("vana-dance:done", resourceRoot, function(share, points)
    local s = Activity.of(client)
    if not s or (s.name ~= "dance" and s.name ~= "lowrider") or type(share) ~= "number" then return end
    share, points = math.max(0, math.min(1, share)), math.floor(tonumber(points) or 0)
    if s.name == "dance" then
        if points > (Activity.progress(client, "dance.best") or 0) then
            Activity.setProgress(client, "dance.best", points)
            s:big("NEW BEST SCORE~n~~w~" .. points, 3500, "small")
        else
            s:big(Activity.text("DNC_001") .. " " .. points, 3500, "small")
        end
        return s:after(3000, function(ss) ss:stop("done") end)
    end
    local rival = L.rival[1] + math.random() * (L.rival[2] - L.rival[1])
    local won = share > rival
    if won then givePlayerMoney(client, s.data.wager * 2) end
    s:big(won and Activity.text("WINNER", nil, s.data.wager) or Activity.text("LOSER", nil, s.data.wager), 4000, won and "passed" or "failed")
    s:after(3500, function(ss) ss:stop("done") end)
end)

addEventHandler("onResourceStart", resourceRoot, function()
    for _, f in ipairs(D.floors) do
        local m = createMarker(f.x, f.y, f.z - 0.1, "cylinder", 1.5, 255, 120, 220, 110)
        setElementInterior(m, f.interior)
        addEventHandler("onMarkerHit", m, function(player, matching)
            if matching and getElementType(player) == "player" and not getPedOccupiedVehicle(player) and not Activity.of(player) then
                Activity.start(player, "dance")
            end
        end)
    end
    -- The lowrider contest: a lowrider with hydraulics into the marker, then the wager.
    local m = createMarker(L.x, L.y, L.z - 0.5, "cylinder", 5, 255, 200, 0, 100)
    createBlip(L.x, L.y, L.z, 0, 2, 255, 200, 0, 255, 0, 400)
    addEventHandler("onMarkerHit", m, function(player, matching)
        local v = matching and getElementType(player) == "player" and getPedOccupiedVehicle(player)
        if not v or Activity.of(player) then return end
        if getVehicleUpgradeOnSlot(v, 9) ~= L.hydraulics then
            return triggerClientEvent(player, "vana-activities:say", resourceRoot, "You need a lowrider with hydraulics for this.", 4000)
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
