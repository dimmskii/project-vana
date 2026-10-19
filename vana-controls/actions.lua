-- Actions on other players, open to everyone (the gate in server.lua applies as to any action).
local lastGift = {} -- player -> tick

local function savePlayer(player)
    local res = getResourceFromName("vana-player")
    if res and getResourceState(res) == "running" then pcall(function() exports["vana-player"]:savePlayer(player) end) end
end

local function plainName(player) return (getPlayerName(player):gsub("#%x%x%x%x%x%x", "")) end

Actions.add{
    name = "givemoney", aliases = { "pay" }, label = "Give money", usage = "<amount> [player]",
    summary = "Hand some of your cash to a player next to you",
    targets = { "player" }, reach = 4,
    params = { { "amount", "number", true }, { "player", "target", false } },
    run = function(player, target, args)
        local amount = math.floor(args.amount or 0)
        if amount < 1 then return false, "Give at least $1." end
        if getPlayerMoney(player) < amount then return false, "You don't have that much money." end
        local now = getTickCount()
        if lastGift[player] and now - lastGift[player] < 2000 then return false, "Wait a moment." end
        lastGift[player] = now
        takePlayerMoney(player, amount)
        givePlayerMoney(target, amount)
        savePlayer(player)
        savePlayer(target)
        Actions.status(target, ("%s gave you $%d."):format(plainName(player), amount))
        return ("You gave %s $%d."):format(plainName(target), amount)
    end,
}

addEventHandler("onPlayerQuit", root, function() lastGift[source] = nil end)
