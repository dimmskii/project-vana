-- Minigames and challenges with no vehicle: the Ammu-Nation shooting range (vanilla SHRANGE), and
-- (below) the rest of the minigames. Values from the scripts unless marked "ours".
Games = {
    range = {
        -- The four ranges (vanilla Srange / its range table): entry, interior, booth and facing.
        ranges = {
            { entry = At("Games.range.ranges.1.entry"), interior = 1, booth = At("Games.range.ranges.1.booth"), heading = 0 },
            { entry = At("Games.range.ranges.2.entry"), interior = 4, booth = At("Games.range.ranges.2.booth"), heading = 270 },
            { entry = At("Games.range.ranges.3.entry"), interior = 7, booth = At("Games.range.ranges.3.booth"), heading = 90 },
            { entry = At("Games.range.ranges.4.entry"), interior = 6, booth = At("Games.range.ranges.4.booth"), heading = 90 },
        },
        -- Weapon challenges in order: weapon, its skill stat, the GXT names of rounds and the pass line.
        weapons = {
            { weapon = 22, stat = 69, rounds = { "ANR_6", "ANR_18", "ANR_19" }, passed = "ANR_29" },
            { weapon = 28, stat = 75, rounds = { "ANR_20", "ANR_21", "ANR_22" }, passed = "ANR_30" },
            { weapon = 25, stat = 72, rounds = { "ANR_23", "ANR_24", "ANR_25" }, passed = "ANR_31" },
            { weapon = 30, stat = 77, rounds = { "ANR_26", "ANR_27", "ANR_28" }, passed = "ANR_32" },
        },
        skillGain = 50, skillBonus = 100,    -- vanilla: +50 for the challenge, +100 more the first time
        distance = 13.6, laneWidth = 6.1,    -- vanilla: targets 13.6 m down the lane, lanes ~6 m apart
        parts = { 3025, 3024, 3023, 3022, 3021, 3020, 3019, 3018 }, -- frame, head, arms, torso halves, legs
        destroyedAt = 5,                     -- ours: parts shot off for a target to count as destroyed
        targetsToWin = 3, pointsToWin = 20,  -- vanilla: first to three targets (rounds 1-2), to 20 points (round 3)
        rivalSeconds = { 7, 5, 5.5, 4.5 },   -- ours: how long a rival takes per target, by weapon
    },
    -- Casino games (vanilla BANDIT, VIDPOK, ROULETE, BLACKJ, WOF), at the seeded spots ([data]/vana-data-activities/activities.map).
    -- Table tiers by interior (ours: vanilla varies them per table): 1 low .. 4 high.
    tiers = { [1] = 4, [10] = 3, [12] = 2 }, defaultTier = 1,
    slots = {
        bets = { 10, 20, 50 },   -- vanilla: each machine takes one of these
        -- Vanilla's three reels (18 stops each) and what three of a kind pays (x the bet).
        reels = {
            { "bar2", "69", "bar1", "bell", "cherry", "grape", "cherry", "grape", "bell", "69", "bell", "bar1", "cherry", "grape", "69", "grape", "bell", "cherry" },
            { "69", "bell", "cherry", "grape", "bar2", "bell", "grape", "cherry", "bell", "bar1", "grape", "69", "cherry", "bar1", "cherry", "69", "bell", "grape" },
            { "grape", "cherry", "69", "bell", "grape", "bell", "69", "grape", "cherry", "bar1", "bar2", "cherry", "bell", "69", "grape", "bar1", "bell", "cherry" },
        },
        pays = { cherry = 25, grape = 100, ["69"] = 250, bell = 500, bar1 = 1000, bar2 = 5000 },
    },
    videopoker = {
        coinValues = { 1, 5, 10, 25, 50, 100, 500, 1000, 5000, 10000 }, maxCoins = 5,
        -- Jacks or Better: per coin, by coins bet 1..5 (vanilla's royal / straight flush / four of a kind;
        -- the rest the standard 9/6 table).
        pays = {
            royal = { 250, 500, 750, 1000, 4000 }, straightflush = { 50, 100, 150, 200, 250 }, four = { 25, 50, 75, 100, 125 },
            fullhouse = 9, flush = 6, straight = 4, three = 3, twopair = 2, jacks = 1,
        },
    },
    roulette = { maxBet = { 20, 200, 2000, 20000 }, minBet = { 1, 10, 100, 1000 } },  -- by tier (vanilla's maxima)
    blackjack = { minBet = { 10, 100, 1000, 10000 }, maxBet = { 100, 1000, 10000, 100000 } },
    -- Wheel of fortune: what each symbol pays (vanilla: value + 1 times the stake) and how many slots it has
    -- (ours: the usual 54-slot money wheel).
    wheel = { maxBet = { 100, 1000, 10000, 100000 }, symbols = { 1, 2, 5, 10, 20, 40 }, slots = { 24, 15, 7, 4, 2, 2 } },
    reach = 1.8,                 -- how close to a machine or table to play
    -- Inside Track Betting (vanilla OTB): five horses a race, named from vanilla's list (HORS__1..HORS149).
    betting = { horses = 5, names = 149, stakes = { 5, 25, 100, 250 }, maxStake = 10000,
                odds = { 1, 2, 3, 5, 8, 12, 20, 33 } },   -- ours: odds (to 1) a horse can get; longer odds win less often
    -- Arcade machines and consoles (vanilla ARCADE and the video game missions): which game each model runs.
    -- Ours: small dx versions of the four games; high scores are kept.
    arcade = { games = { cj_coin_op = "uranus", cj_coin_op_1 = "duality", cj_coin_op_2 = "monkey", cj_coin_op_3 = "bumble",
                         swank_console = "uranus", snesish = "bumble", low_console = "duality" },
               titles = { uranus = "They Crawled From Uranus", duality = "Duality", monkey = "Go Go Space Monkey", bumble = "Let's Get Ready To Bumble" },
               price = 1 },
    -- Basketball (vanilla BASKETB): a minute to score as much as you can. Ours: the timing meter.
    basketball = { timeMs = 60000, points = 2, farPoints = 3, sweet = 0.12 },
    -- Pool (vanilla POOL2 / POOL_SCRIPT): 8-ball against the bar's player for a wager (vanilla $50-$1000).
    -- Ours: a top-down table with 2D physics.
    pool = { minBet = 50, maxBet = 1000 },
    -- Dancing (vanilla DANCE) on club floors, and the lowrider contest (vanilla LOWR / LOWGAME): the
    -- rhythm game on the routine playing at that music zone (`station`: vana-radio's zone stations,
    -- heard from its speakers). A routine already playing is joined if half its beats are still
    -- ahead (readyMs to get ready), else the next one.
    dance = {
        floors = {
            At("Games.dance.floors.1", { interior = 17, station = 101 }),   -- the Alhambra (vanilla's floor)
            At("Games.dance.floors.2", { interior = 11, station = 102 }),   -- ours: inside BAR2 (Ten Green Bottles)
            At("Games.dance.floors.3", { interior = 18, station = 103 }),   -- ours: inside the Lil' Probe Inn
        },
        readyMs = 3000,
        -- DANCE's animation block by beat track: 1-2 GFUNK, 3 RUNNINGMAN, 4 WOP. Hits play the next of
        -- DANCE_G1..G16 in turn, misses DANCE_B1..B16; DANCE_LOOP in between.
        blocks = { [1] = "GFUNK", [2] = "GFUNK", [3] = "RUNNINGMAN", [4] = "WOP" },
        idleMs = 1500, -- back to DANCE_LOOP this long after the last move
        -- Without vana-radio: made-up beats.
        count = 40, beatMs = 700,
    },
    lowrider = At("Games.lowrider", {
        station = 110, readyMs = 3000, hydraulics = 1087,
        minBet = 50, maxBet = 1000, -- vanilla
        -- The opposition's points per beat by its skill (1-5): a roll of 0-9 picks one (LOWGAME_7669).
        -- Each contest raises the skill by 4 x wager / maxBet (rounded down), up to 5, and it stays.
        rival = {
            { 0, 0, 10, 10, 10, 10, 20, 20, 20, 50 },
            { 0, 10, 10, 10, 10, 20, 20, 20, 50, 50 },
            { 0, 10, 10, 10, 20, 20, 20, 50, 50, 50 },
            { 10, 10, 10, 20, 20, 20, 20, 50, 50, 50 },
            { 10, 10, 20, 20, 20, 20, 50, 50, 50, 50 },
        },
        count = 30, beatMs = 800, -- without vana-radio: made-up beats
    }),
}
