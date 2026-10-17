-- Casino games, drawn here (vanilla-style panels); the server decides every outcome (games/casino.lua).
-- Keys: arrows to choose, Enter to bet / deal / spin, Backspace to leave. Video poker: 1-5 to hold.
local game -- { kind, params, ... }

local function sx(v) return v * (select(2, guiGetScreenSize()) / 720) end
local function money(n) return "$" .. tostring(n) end

local SUITS = { "S", "H", "D", "C" }
local RANKS = { [11] = "J", [12] = "Q", [13] = "K", [14] = "A" }
local function cardText(c) return (RANKS[c.rank] or tostring(c.rank)) .. SUITS[c.suit] end
local function cardColour(c) return (c.suit == 2 or c.suit == 3) and tocolor(200, 30, 30) or tocolor(20, 20, 20) end

local function close()
    game = nil
    toggleAllControls(true, true, false)
end

addEvent("vana-casino:open", true)
addEventHandler("vana-casino:open", resourceRoot, function(kind, params)
    if not kind then return close() end
    game = { kind = kind, p = params or {}, message = nil }
    toggleAllControls(false, true, false)
    if kind == "videopoker" then game.coins, game.value, game.holds = 1, 1, {}
    elseif kind == "roulette" then game.bets, game.choice, game.amount = {}, 1, params.min
    elseif kind == "blackjack" then game.amount = params.min
    elseif kind == "wheel" then game.stakes, game.choice, game.amount = {}, 1, 10 end
end)

addEvent("vana-casino:nomoney", true)
addEventHandler("vana-casino:nomoney", resourceRoot, function() if game then game.message = "~r~Not enough money." end end)

addEvent("vana-casino:slots", true)
addEventHandler("vana-casino:slots", resourceRoot, function(symbols, win)
    if not game then return end
    game.symbols, game.spinUntil, game.win = symbols, getTickCount() + 1500, win
end)

addEvent("vana-casino:vpHand", true)
addEventHandler("vana-casino:vpHand", resourceRoot, function(hand, done, result, win)
    if not game then return end
    game.hand, game.done, game.result, game.win = hand, done, result, win
    if not done then game.holds = {} end
end)

addEvent("vana-casino:roulette", true)
addEventHandler("vana-casino:roulette", resourceRoot, function(n, win)
    if not game then return end
    game.result, game.win, game.bets, game.spinUntil = n, win, {}, getTickCount() + 2000
end)

addEvent("vana-casino:bj", true)
addEventHandler("vana-casino:bj", resourceRoot, function(mine, dealer, myScore, dealerScore, done, result, win)
    if not game then return end
    game.mine, game.dealer, game.myScore, game.dealerScore, game.done, game.result, game.win = mine, dealer, myScore, dealerScore, done, result, win
end)

addEvent("vana-casino:wheel", true)
addEventHandler("vana-casino:wheel", resourceRoot, function(landed, win)
    if not game then return end
    game.landed, game.win, game.stakes, game.spinUntil = landed, win, {}, getTickCount() + 2500
end)

-- Roulette bet choices, in menu order.
local ROULETTE = { { "red", "Red" }, { "black", "Black" }, { "odd", "Odd" }, { "even", "Even" }, { "low", "1 to 18" }, { "high", "19 to 36" },
                   { "dozen", "1st 12", 1 }, { "dozen", "2nd 12", 2 }, { "dozen", "3rd 12", 3 } }
for n = 0, 37 do ROULETTE[#ROULETTE + 1] = { "number", n == 37 and "00" or tostring(n), n } end

local function step(amount, up, min, max)
    local s = amount >= 10000 and 1000 or amount >= 1000 and 100 or amount >= 100 and 10 or 1
    return math.max(min or 1, math.min(max or 1e9, amount + (up and s or -s)))
end

addEventHandler("onClientKey", root, function(key, pressed)
    if not game or not pressed then return end
    local k, p = game.kind, game.p
    if key == "backspace" or key == "escape" then
        triggerServerEvent("vana-casino:leave", resourceRoot)
        close()
    elseif k == "slots" then
        if (key == "enter" or key == "space") and not (game.spinUntil and getTickCount() < game.spinUntil) then
            game.message = nil
            triggerServerEvent("vana-casino:slots", resourceRoot)
        end
    elseif k == "videopoker" then
        if not game.hand or game.done then
            if key == "arrow_u" then game.coins = math.min(p.maxCoins, game.coins + 1)
            elseif key == "arrow_d" then game.coins = math.max(1, game.coins - 1)
            elseif key == "arrow_r" then game.value = math.min(#p.coinValues, game.value + 1)
            elseif key == "arrow_l" then game.value = math.max(1, game.value - 1)
            elseif key == "enter" then game.message, game.hand = nil, nil triggerServerEvent("vana-casino:vpDeal", resourceRoot, game.coins, game.value) end
        else
            local n = tonumber(key)
            if n and n >= 1 and n <= 5 then game.holds[n] = not game.holds[n]
            elseif key == "enter" then triggerServerEvent("vana-casino:vpDraw", resourceRoot, game.holds) end
        end
    elseif k == "roulette" then
        if key == "arrow_u" then game.choice = (game.choice - 2) % #ROULETTE + 1
        elseif key == "arrow_d" then game.choice = game.choice % #ROULETTE + 1
        elseif key == "arrow_r" then game.amount = step(game.amount, true, p.min, p.max)
        elseif key == "arrow_l" then game.amount = step(game.amount, false, p.min, p.max)
        elseif key == "enter" and #game.bets < 20 then
            local c = ROULETTE[game.choice]
            table.insert(game.bets, { kind = c[1], number = c[3], amount = game.amount, label = c[2] })
        elseif key == "space" and #game.bets > 0 then
            game.message = nil
            triggerServerEvent("vana-casino:roulette", resourceRoot, game.bets)
        end
    elseif k == "blackjack" then
        if not game.mine or game.done then
            if key == "arrow_r" then game.amount = step(game.amount, true, p.min, p.max)
            elseif key == "arrow_l" then game.amount = step(game.amount, false, p.min, p.max)
            elseif key == "enter" then game.message = nil triggerServerEvent("vana-casino:bj", resourceRoot, "deal", game.amount) end
        elseif key == "h" then triggerServerEvent("vana-casino:bj", resourceRoot, "hit")
        elseif key == "s" then triggerServerEvent("vana-casino:bj", resourceRoot, "stand")
        elseif key == "d" then triggerServerEvent("vana-casino:bj", resourceRoot, "double") end
    elseif k == "wheel" then
        if key == "arrow_u" then game.choice = (game.choice - 2) % #p.symbols + 1
        elseif key == "arrow_d" then game.choice = game.choice % #p.symbols + 1
        elseif key == "arrow_r" then game.amount = step(game.amount, true, 1, p.max)
        elseif key == "arrow_l" then game.amount = step(game.amount, false, 1, p.max)
        elseif key == "enter" then game.stakes[game.choice] = (game.stakes[game.choice] or 0) + game.amount
        elseif key == "space" then game.message = nil triggerServerEvent("vana-casino:wheel", resourceRoot, game.stakes) end
    else
        return
    end
    cancelEvent()
end)

local function panel(title, lines, hint)
    local x, y, w = sx(40), sx(110), sx(460)
    local row = sx(24)
    dxDrawRectangle(x, y, w, row * (#lines + 3), tocolor(0, 0, 0, 200))
    dxDrawText(title, x + sx(12), y + sx(6), x + w, y + row, tocolor(172, 203, 241), sx(1.3), "bankgothic")
    for i, l in ipairs(lines) do
        local text, colour = l, tocolor(230, 230, 230)
        if type(l) == "table" then text, colour = l[1], l[2] end
        dxDrawText(Hud.format(text), x + sx(12), y + row * (i + 0.4), x + w, y + row * (i + 1.4), colour, sx(1.1), "default-bold",
            "left", "center", false, false, false, true)
    end
    dxDrawText(hint, x + sx(12), y + row * (#lines + 1.6), x + w, y + row * (#lines + 2.6), tocolor(180, 180, 180), sx(1), "default", "left", "center")
end

local function result(lines)
    if game.message then lines[#lines + 1] = game.message
    elseif game.win and game.win > 0 then lines[#lines + 1] = { "WINNER! " .. money(game.win), tocolor(120, 255, 120) }
    elseif game.win == 0 then lines[#lines + 1] = { "NO WIN!", tocolor(255, 140, 140) } end
end

addEventHandler("onClientRender", root, function()
    if not game then return end
    local k, p, now = game.kind, game.p, getTickCount()
    local lines = {}
    if k == "slots" then
        local spinning = game.spinUntil and now < game.spinUntil
        local reel = Games.slots.reels[1]
        local shown = {}
        for i = 1, 3 do
            shown[i] = spinning and Games.slots.reels[i][math.floor(now / 70 + i * 5) % #reel + 1] or (game.symbols and game.symbols[i] or "-")
        end
        lines[1] = ("[ %s ]   [ %s ]   [ %s ]"):format(shown[1]:upper(), shown[2]:upper(), shown[3]:upper())
        lines[2] = "Bet " .. money(p.bet) .. "   |   You " .. money(getPlayerMoney())
        if not spinning then result(lines) end
        panel("Slots", lines, "Enter: pull   Backspace: leave")
    elseif k == "videopoker" then
        if game.hand then
            local cards = {}
            for i, c in ipairs(game.hand) do cards[i] = (game.holds[i] and not game.done and "[" or " ") .. cardText(c) .. (game.holds[i] and not game.done and "]" or " ") end
            lines[1] = table.concat(cards, "  ")
        end
        lines[#lines + 1] = ("Coins %d x %s   |   You %s"):format(game.coins, money(p.coinValues[game.value]), money(getPlayerMoney()))
        if game.done then
            lines[#lines + 1] = game.result and game.result:upper() or "NO WIN"
            result(lines)
        end
        panel("Video Poker", lines, (game.hand and not game.done) and "1-5: hold   Enter: draw" or "Up/Down: coins   Left/Right: coin value   Enter: deal")
    elseif k == "roulette" then
        local c = ROULETTE[game.choice]
        lines[1] = ("Bet on: %s   Stake %s  (%s-%s)"):format(c[2], money(game.amount), money(p.min), money(p.max))
        local placed = {}
        for _, b in ipairs(game.bets) do placed[#placed + 1] = b.label .. " " .. money(b.amount) end
        lines[2] = #placed > 0 and table.concat(placed, ", ") or "No bets yet"
        if game.result and not (game.spinUntil and now < game.spinUntil) then
            lines[3] = "The ball lands on " .. (game.result == 37 and "00" or tostring(game.result))
            result(lines)
        elseif game.spinUntil and now < game.spinUntil then
            lines[3] = "Spinning... " .. math.random(0, 36)
        end
        panel("Roulette", lines, "Up/Down: bet   Left/Right: stake   Enter: place   Space: spin")
    elseif k == "blackjack" then
        if game.mine then
            local mine, dealer = {}, {}
            for i, c in ipairs(game.mine) do mine[i] = cardText(c) end
            for i, c in ipairs(game.dealer) do dealer[i] = cardText(c) end
            lines[1] = "Dealer: " .. table.concat(dealer, " ") .. (game.dealerScore and ("  (" .. game.dealerScore .. ")") or "  ??")
            lines[2] = "You: " .. table.concat(mine, " ") .. "  (" .. game.myScore .. ")"
            if game.done then lines[3] = (game.result or ""):upper() result(lines) end
        end
        lines[#lines + 1] = ("Wager %s  (%s-%s)   |   You %s"):format(money(game.amount), money(p.min), money(p.max), money(getPlayerMoney()))
        panel("Blackjack", lines, (game.mine and not game.done) and "H: hit   S: stand   D: double" or "Left/Right: wager   Enter: deal")
    elseif k == "wheel" then
        for i, sym in ipairs(p.symbols) do
            local mark = i == game.choice and "> " or "  "
            lines[i] = mark .. sym .. "  pays " .. (sym + 1) .. " to 1" .. ((game.stakes[i] or 0) > 0 and ("   staked " .. money(game.stakes[i])) or "")
        end
        lines[#lines + 1] = "Stake " .. money(game.amount) .. "   |   max " .. money(p.max)
        if game.landed and not (game.spinUntil and now < game.spinUntil) then
            lines[#lines + 1] = "The wheel stops on " .. p.symbols[game.landed]
            result(lines)
        end
        panel("Wheel of Fortune", lines, "Up/Down: symbol   Left/Right: stake   Enter: add   Space: spin")
    end
end)
