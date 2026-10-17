-- Pool (vanilla POOL2 / POOL_SCRIPT): at a pool table, wager $50-$1000 and play 8-ball against the bar's
-- player. The game (top-down, 2D physics, the CPU's shots) runs on the client (games/pool_client.lua);
-- the server holds the stake and pays double for a win.
local P = Games.pool

Activity.register("pool", {
    title = "Pool",
    start = function(session, index)
        setElementFrozen(session.player, true)
        triggerClientEvent(session.player, "vana-pool:open", resourceRoot, P.minBet, P.maxBet)
    end,
    stop = function(session)
        if isElement(session.player) then
            setElementFrozen(session.player, false)
            triggerClientEvent(session.player, "vana-pool:open", resourceRoot, nil)
        end
    end,
})

addEvent("vana-pool:wager", true)
addEventHandler("vana-pool:wager", resourceRoot, function(amount)
    local s = Activity.of(client)
    amount = math.floor(tonumber(amount) or 0)
    if not s or s.name ~= "pool" or s.data.stake or amount < P.minBet or amount > P.maxBet then return end
    if getPlayerMoney(client) < amount then return triggerClientEvent(client, "vana-casino:nomoney", resourceRoot) end
    takePlayerMoney(client, amount)
    s.data.stake, s.data.since = amount, getTickCount()
    triggerClientEvent(client, "vana-pool:rack", resourceRoot)
end)

addEvent("vana-pool:result", true)
addEventHandler("vana-pool:result", resourceRoot, function(won)
    local s = Activity.of(client)
    local d = s and s.name == "pool" and s.data
    if not d or not d.stake or getTickCount() - d.since < 10000 then return end
    if won then
        givePlayerMoney(client, d.stake * 2)
        s:big(Activity.text("PL_07", "POOL", d.stake), 4000, "passed")
    else
        s:big(Activity.text("PL_10", "POOL", d.stake), 4000, "failed")
    end
    Activity.setProgress(client, won and "pool.won" or "pool.lost", (Activity.progress(client, won and "pool.won" or "pool.lost") or 0) + 1)
    d.stake = nil
    s:after(4000, function(ss) ss:stop("done") end)
end)

addEvent("vana-pool:leave", true)
addEventHandler("vana-pool:leave", resourceRoot, function()
    local s = Activity.of(client)
    if s and s.name == "pool" then s:stop("left") end -- a game walked out on is lost
end)
