-- Casino games (vanilla BANDIT, VIDPOK, ROULETE, BLACKJ, WOF) at the seeded machines and tables
-- (config/minigames.lua). Walk up and press enter/exit; games/casino_client.lua draws the game. Every
-- bet, card and spin is decided here, and money moves only here.
local G = Games

local function tierOf(spot)
    return G.tiers[spot.interior] or G.defaultTier
end

local function pay(session, amount)
    if amount > 0 then
        givePlayerMoney(session.player, amount)
        Activity.setProgress(session.player, "gambling.won", (Activity.progress(session.player, "gambling.won") or 0) + amount)
    end
end

local function stake(session, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or getPlayerMoney(session.player) < amount then return false end
    takePlayerMoney(session.player, amount)
    return true
end

local function reply(session, event, ...)
    triggerClientEvent(session.player, "vana-casino:" .. event, resourceRoot, ...)
end

-- Cards -------------------------------------------------------------------------------------------------
local function newDeck()
    local deck = {}
    for suit = 1, 4 do for rank = 2, 14 do deck[#deck + 1] = { rank = rank, suit = suit } end end
    for i = #deck, 2, -1 do local j = math.random(i) deck[i], deck[j] = deck[j], deck[i] end
    return deck
end

local function pokerHand(hand)
    local counts, suits, ranks = {}, {}, {}
    for _, c in ipairs(hand) do
        counts[c.rank] = (counts[c.rank] or 0) + 1
        suits[c.suit] = true
        ranks[#ranks + 1] = c.rank
    end
    table.sort(ranks)
    local flush = next(suits, next(suits)) == nil
    local straight = true
    for i = 2, 5 do if ranks[i] ~= ranks[i - 1] + 1 then straight = false end end
    if not straight and ranks[5] == 14 and ranks[1] == 2 and ranks[2] == 3 and ranks[3] == 4 and ranks[4] == 5 then straight = true end
    local groups = {}
    for rank, n in pairs(counts) do groups[#groups + 1] = { n = n, rank = rank } end
    table.sort(groups, function(a, b) return a.n > b.n end)
    if straight and flush then return (ranks[1] == 10) and "royal" or "straightflush" end
    if groups[1].n == 4 then return "four" end
    if groups[1].n == 3 and groups[2].n == 2 then return "fullhouse" end
    if flush then return "flush" end
    if straight then return "straight" end
    if groups[1].n == 3 then return "three" end
    if groups[1].n == 2 and groups[2].n == 2 then return "twopair" end
    if groups[1].n == 2 and groups[1].rank >= 11 then return "jacks" end
    return nil
end

local function bjValue(cards)
    local total, aces = 0, 0
    for _, c in ipairs(cards) do
        if c.rank == 14 then total, aces = total + 11, aces + 1
        elseif c.rank >= 11 then total = total + 10
        else total = total + c.rank end
    end
    while total > 21 and aces > 0 do total, aces = total - 10, aces - 1 end
    return total
end

-- The session ---------------------------------------------------------------------------------------------
Activity.register("casino", {
    title = "Casino",
    start = function(session, index)
        local spot = MinigameSpots[index]
        local d = session.data
        d.spot, d.kind, d.tier = spot, spot.kind, tierOf(spot)
        setElementFrozen(session.player, true)
        local params = { tier = d.tier }
        if d.kind == "slots" then
            d.bet = G.slots.bets[index % #G.slots.bets + 1]
            params.bet = d.bet
        elseif d.kind == "roulette" then
            params.min, params.max = G.roulette.minBet[d.tier], G.roulette.maxBet[d.tier]
        elseif d.kind == "blackjack" then
            params.min, params.max = G.blackjack.minBet[d.tier], G.blackjack.maxBet[d.tier]
        elseif d.kind == "wheel" then
            params.max, params.symbols = G.wheel.maxBet[d.tier], G.wheel.symbols
        elseif d.kind == "videopoker" then
            params.coinValues, params.maxCoins = G.videopoker.coinValues, G.videopoker.maxCoins
        end
        reply(session, "open", d.kind, params)
    end,
    stop = function(session)
        if isElement(session.player) then
            setElementFrozen(session.player, false)
            reply(session, "open", nil)
        end
    end,
})

local function casinoSession(player, kind)
    local s = Activity.of(player)
    return s and s.name == "casino" and s.data.kind == kind and s or nil
end

addEvent("vana-casino:leave", true)
addEventHandler("vana-casino:leave", resourceRoot, function()
    local s = Activity.of(client)
    if s and s.name == "casino" then s:stop("left") end
end)

-- Slots: three reels; three of a kind pays bet x the symbol's value.
addEvent("vana-casino:slots", true)
addEventHandler("vana-casino:slots", resourceRoot, function()
    local s = casinoSession(client, "slots")
    if not s or not stake(s, s.data.bet) then return reply(s or { player = client }, "nomoney") end
    local stops, symbols = {}, {}
    for i, reel in ipairs(G.slots.reels) do
        stops[i] = math.random(#reel)
        symbols[i] = reel[stops[i]]
    end
    local win = 0
    if symbols[1] == symbols[2] and symbols[2] == symbols[3] then win = s.data.bet * G.slots.pays[symbols[1]] end
    pay(s, win)
    reply(s, "slots", symbols, win)
end)

-- Video poker: deal five, hold some, draw; Jacks or Better.
addEvent("vana-casino:vpDeal", true)
addEventHandler("vana-casino:vpDeal", resourceRoot, function(coins, valueIndex)
    local s = casinoSession(client, "videopoker")
    local P = G.videopoker
    coins, valueIndex = math.floor(tonumber(coins) or 0), math.floor(tonumber(valueIndex) or 0)
    if not s or coins < 1 or coins > P.maxCoins or not P.coinValues[valueIndex] or s.data.hand then return end
    local value = P.coinValues[valueIndex]
    if not stake(s, coins * value) then return reply(s, "nomoney") end
    local deck = newDeck()
    s.data.deck, s.data.hand, s.data.coins, s.data.value = deck, { table.remove(deck), table.remove(deck), table.remove(deck), table.remove(deck), table.remove(deck) }, coins, value
    reply(s, "vpHand", s.data.hand, false)
end)

addEvent("vana-casino:vpDraw", true)
addEventHandler("vana-casino:vpDraw", resourceRoot, function(holds)
    local s = casinoSession(client, "videopoker")
    local d = s and s.data
    if not d or not d.hand or type(holds) ~= "table" then return end
    for i = 1, 5 do
        if not holds[i] then d.hand[i] = table.remove(d.deck) end
    end
    local result = pokerHand(d.hand)
    local win = 0
    if result then
        local p = G.videopoker.pays[result]
        win = (type(p) == "table" and p[d.coins] or p * d.coins) * d.value
    end
    pay(s, win)
    reply(s, "vpHand", d.hand, true, result, win)
    d.hand = nil
end)

-- Roulette (0 and 00): bets { kind, number, amount }; the wheel spins once for all of them.
local RED = { [1] = true, [3] = true, [5] = true, [7] = true, [9] = true, [12] = true, [14] = true, [16] = true, [18] = true,
              [19] = true, [21] = true, [23] = true, [25] = true, [27] = true, [30] = true, [32] = true, [34] = true, [36] = true }

local function rouletteWin(bet, n)
    if n == 0 or n == 37 then return bet.kind == "number" and bet.number == n and 36 or 0 end
    local k = bet.kind
    if k == "number" then return bet.number == n and 36 or 0 end
    if k == "red" then return RED[n] and 2 or 0 end
    if k == "black" then return (not RED[n]) and 2 or 0 end
    if k == "odd" then return n % 2 == 1 and 2 or 0 end
    if k == "even" then return n % 2 == 0 and 2 or 0 end
    if k == "low" then return n <= 18 and 2 or 0 end
    if k == "high" then return n >= 19 and 2 or 0 end
    if k == "dozen" then return math.ceil(n / 12) == bet.number and 3 or 0 end
    return 0
end

addEvent("vana-casino:roulette", true)
addEventHandler("vana-casino:roulette", resourceRoot, function(bets)
    local s = casinoSession(client, "roulette")
    if not s or type(bets) ~= "table" or #bets == 0 or #bets > 20 then return end
    local total = 0
    for _, b in ipairs(bets) do
        local amount = math.floor(tonumber(b.amount) or 0)
        if amount < G.roulette.minBet[s.data.tier] or amount > G.roulette.maxBet[s.data.tier] then return end
        total = total + amount
    end
    if not stake(s, total) then return reply(s, "nomoney") end
    local n = math.random(0, 37) -- 37 is 00
    local win = 0
    for _, b in ipairs(bets) do win = win + rouletteWin(b, n) * math.floor(b.amount) end
    pay(s, win)
    reply(s, "roulette", n, win)
end)

-- Blackjack: dealer stands on 17; blackjack pays 3 to 2; doubling takes one card.
local function bjState(s, done, result, win)
    local d = s.data
    reply(s, "bj", d.player, done and d.dealer or { d.dealer[1] }, bjValue(d.player), done and bjValue(d.dealer) or nil, done, result, win)
end

local function bjSettle(s)
    local d = s.data
    while bjValue(d.dealer) < 17 do d.dealer[#d.dealer + 1] = table.remove(d.deck) end
    local p, q = bjValue(d.player), bjValue(d.dealer)
    local win, result = 0, "lose"
    if p > 21 then result = "bust"
    elseif q > 21 or p > q then win, result = d.bet * 2, "win"
    elseif p == q then win, result = d.bet, "push" end
    pay(s, win)
    bjState(s, true, result, win)
    d.player = nil
end

addEvent("vana-casino:bj", true)
addEventHandler("vana-casino:bj", resourceRoot, function(action, amount)
    local s = casinoSession(client, "blackjack")
    if not s then return end
    local d = s.data
    if action == "deal" and not d.player then
        amount = math.floor(tonumber(amount) or 0)
        if amount < G.blackjack.minBet[d.tier] or amount > G.blackjack.maxBet[d.tier] then return end
        if not stake(s, amount) then return reply(s, "nomoney") end
        d.deck, d.bet = newDeck(), amount
        d.player = { table.remove(d.deck), table.remove(d.deck) }
        d.dealer = { table.remove(d.deck), table.remove(d.deck) }
        if bjValue(d.player) == 21 then
            local push = bjValue(d.dealer) == 21
            local win = push and d.bet or math.floor(d.bet * 2.5)
            pay(s, win)
            bjState(s, true, push and "push" or "blackjack", win)
            d.player = nil
        else
            bjState(s, false)
        end
    elseif action == "hit" and d.player then
        d.player[#d.player + 1] = table.remove(d.deck)
        if bjValue(d.player) > 21 then bjSettle(s) else bjState(s, false) end
    elseif action == "double" and d.player and #d.player == 2 then
        if not stake(s, d.bet) then return reply(s, "nomoney") end
        d.bet = d.bet * 2
        d.player[#d.player + 1] = table.remove(d.deck)
        bjSettle(s)
    elseif action == "stand" and d.player then
        bjSettle(s)
    end
end)

-- Wheel of fortune: stakes on symbols; the wheel picks a slot.
addEvent("vana-casino:wheel", true)
addEventHandler("vana-casino:wheel", resourceRoot, function(stakes)
    local s = casinoSession(client, "wheel")
    if not s or type(stakes) ~= "table" then return end
    local W, total = G.wheel, 0
    for i in ipairs(W.symbols) do total = total + math.max(0, math.floor(tonumber(stakes[i]) or 0)) end
    if total <= 0 or total > W.maxBet[s.data.tier] then return end
    if not stake(s, total) then return reply(s, "nomoney") end
    local slots = 0
    for _, n in ipairs(W.slots) do slots = slots + n end
    local roll, landed = math.random(slots), 1
    for i, n in ipairs(W.slots) do
        if roll <= n then landed = i break end
        roll = roll - n
    end
    local win = math.max(0, math.floor(tonumber(stakes[landed]) or 0)) * (W.symbols[landed] + 1)
    pay(s, win)
    reply(s, "wheel", landed, win)
end)

-- Using a minigame object: the nearest seeded spot of the right kind within reach.
local ACTIVITY = { slots = "casino", videopoker = "casino", roulette = "casino", blackjack = "casino", wheel = "casino",
                   arcade = "arcade", console = "arcade", hoop = "basketball", pool = "pool", betting = "betting" }

addEvent("vana-minigame:use", true)
addEventHandler("vana-minigame:use", resourceRoot, function(index)
    local player = client
    local spot = type(index) == "number" and MinigameSpots[index]
    if not spot or Activity.of(player) or getPedOccupiedVehicle(player) then return end
    local x, y, z = getElementPosition(player)
    if getElementInterior(player) ~= spot.interior or getDistanceBetweenPoints3D(x, y, z, spot.x, spot.y, spot.z) > G.reach + 2.5 then return end
    local name = ACTIVITY[spot.kind]
    if name then Activity.start(player, name, index) end
end)

Activity.test("casino", function()
    local counts = {}
    for _, s in ipairs(MinigameSpots) do counts[s.kind] = (counts[s.kind] or 0) + 1 end
    -- Sanity: a royal flush and a full house are recognised.
    local royal = pokerHand({ { rank = 10, suit = 1 }, { rank = 11, suit = 1 }, { rank = 12, suit = 1 }, { rank = 13, suit = 1 }, { rank = 14, suit = 1 } })
    local full = pokerHand({ { rank = 3, suit = 1 }, { rank = 3, suit = 2 }, { rank = 3, suit = 3 }, { rank = 9, suit = 1 }, { rank = 9, suit = 2 } })
    local bj = bjValue({ { rank = 14, suit = 1 }, { rank = 13, suit = 2 } })
    local ok = royal == "royal" and full == "fullhouse" and bj == 21 and (counts.slots or 0) > 0
    return ok, ("%d slots, %d video poker, %d roulette, %d blackjack, %d wheels"):format(counts.slots or 0, counts.videopoker or 0,
        counts.roulette or 0, counts.blackjack or 0, counts.wheel or 0)
end)

-- The prompts players see by minigame objects (vanilla's where it has one).
addEvent("vana-minigame:hello", true)
addEventHandler("vana-minigame:hello", resourceRoot, function()
    triggerClientEvent(client, "vana-minigame:texts", resourceRoot, {
        slots = Activity.text("SLOT_02"), videopoker = Activity.text("VP01"), wheel = Activity.text("WOF_06"),
        hoop = Activity.text("BB_01"),
    })
end)
