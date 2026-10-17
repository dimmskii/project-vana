-- Inside Track Betting (vanilla OTB_SCRIPT), the arcade machines and consoles (vanilla ARCADE and the
-- video game missions) and basketball hoops (vanilla BASKETB). The server takes stakes and decides races;
-- the games themselves are drawn and played on the client (games/side_client.lua).
local G = Games

-- Betting ---------------------------------------------------------------------------------------------------
local function newRace()
    local race, used = {}, {}
    for i = 1, G.betting.horses do
        local n
        repeat n = math.random(G.betting.names) until not used[n]
        used[n] = true
        local key = n < 10 and ("HORS__" .. n) or n < 100 and ("HORS_" .. n) or ("HORS" .. n)
        race[i] = { name = Activity.text(key, "OTB"), odds = G.betting.odds[math.random(#G.betting.odds)] }
    end
    return race
end

Activity.register("betting", {
    title = "Inside Track Betting",
    start = function(session)
        session.data.race = newRace()
        setElementFrozen(session.player, true)
        triggerClientEvent(session.player, "vana-side:open", resourceRoot, "betting", { race = session.data.race, stakes = G.betting.stakes, max = G.betting.maxStake })
    end,
    stop = function(session)
        if isElement(session.player) then
            setElementFrozen(session.player, false)
            triggerClientEvent(session.player, "vana-side:open", resourceRoot, nil)
        end
    end,
})

addEvent("vana-side:bet", true)
addEventHandler("vana-side:bet", resourceRoot, function(horse, amount)
    local s = Activity.of(client)
    local d = s and s.name == "betting" and s.data
    amount = math.floor(tonumber(amount) or 0)
    if not d or not d.race[horse] or amount <= 0 or amount > G.betting.maxStake then return end
    if getPlayerMoney(client) < amount then return triggerClientEvent(client, "vana-casino:nomoney", resourceRoot) end
    takePlayerMoney(client, amount)
    -- Each horse's chance is its share of 1 / (odds + 1).
    local total, weights = 0, {}
    for i, h in ipairs(d.race) do weights[i] = 1 / (h.odds + 1) total = total + weights[i] end
    local roll, winner = math.random() * total, #d.race
    for i, w in ipairs(weights) do
        if roll <= w then winner = i break end
        roll = roll - w
    end
    local win = (winner == horse) and amount * (d.race[horse].odds + 1) or 0
    if win > 0 then givePlayerMoney(client, win) end
    triggerClientEvent(client, "vana-side:race", resourceRoot, winner, win)
    d.race = newRace()
    setTimer(function() if Activity.of(s.player) == s then triggerClientEvent(s.player, "vana-side:newrace", resourceRoot, d.race) end end, 9000, 1)
end)

-- Arcade ------------------------------------------------------------------------------------------------------
Activity.register("arcade", {
    title = "Arcade",
    start = function(session, index)
        local spot = MinigameSpots[index]
        local gameKey = G.arcade.games[spot.model] or "uranus"
        if spot.kind == "arcade" then
            if getPlayerMoney(session.player) < G.arcade.price then return session:stop("broke") end
            takePlayerMoney(session.player, G.arcade.price)
        end
        session.data.game = gameKey
        setElementFrozen(session.player, true)
        triggerClientEvent(session.player, "vana-side:open", resourceRoot, "arcade",
            { game = gameKey, title = G.arcade.titles[gameKey], best = Activity.progress(session.player, "arcade." .. gameKey) or 0 })
    end,
    stop = function(session)
        if isElement(session.player) then
            setElementFrozen(session.player, false)
            triggerClientEvent(session.player, "vana-side:open", resourceRoot, nil)
        end
    end,
})

-- Basketball --------------------------------------------------------------------------------------------------
Activity.register("basketball", {
    title = "Basketball",
    start = function(session, index)
        local spot = MinigameSpots[index]
        session.data.spot = spot
        setElementFrozen(session.player, true)
        triggerClientEvent(session.player, "vana-side:open", resourceRoot, "basketball",
            { hoop = { spot.x, spot.y, spot.z }, timeMs = G.basketball.timeMs, sweet = G.basketball.sweet,
              best = Activity.progress(session.player, "basketball.best") or 0 })
    end,
    stop = function(session)
        if isElement(session.player) then
            setElementFrozen(session.player, false)
            setPedAnimation(session.player)
            triggerClientEvent(session.player, "vana-side:open", resourceRoot, nil)
        end
    end,
})

addEvent("vana-side:shot", true)
addEventHandler("vana-side:shot", resourceRoot, function(made)
    local s = Activity.of(client)
    if not s or s.name ~= "basketball" then return end
    setPedAnimation(client, "BSKTBALL", made and "BBALL_Jump_Shot" or "BBALL_Jump_Cancel", -1, false, false, false, false)
end)

-- Scores and leaving (arcade, basketball, betting).
addEvent("vana-side:done", true)
addEventHandler("vana-side:done", resourceRoot, function(score)
    local s = Activity.of(client)
    if not s or not (s.name == "arcade" or s.name == "basketball" or s.name == "betting") then return end
    score = math.floor(tonumber(score) or 0)
    local key = s.name == "arcade" and ("arcade." .. s.data.game) or s.name == "basketball" and "basketball.best" or nil
    if key and score > (Activity.progress(client, key) or 0) then
        Activity.setProgress(client, key, score)
        s:big("NEW HIGH SCORE~n~~w~" .. score, 4000, "small")
    end
    s:stop("done")
end)

Activity.test("side games", function()
    return Gxt.raw("HORS__1", "OTB") ~= nil and Gxt.raw("HORS149", "OTB") ~= nil, "betting, arcade, basketball"
end)
