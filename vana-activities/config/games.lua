-- Minigames and challenges with no vehicle: the Ammu-Nation shooting range (vanilla SHRANGE), and
-- (below) the rest of the minigames. Values from the scripts unless marked "ours".
Games = {
    range = {
        -- The four ranges (vanilla Srange / its range table): entry, interior, booth and facing.
        ranges = {
            { entry = { 292.33, -35.39, 1000.5 }, interior = 1, booth = { 290.63, -24.55, 1000.52 }, heading = 0 },
            { entry = { 289.48, -79.66, 1001.73 }, interior = 4, booth = { 303.08, -61.23, 1000.52 }, heading = 270 },
            { entry = { 309.97, -135.39, 1002.83 }, interior = 7, booth = { 300.10, -137.04, 1003.05 }, heading = 90 },
            { entry = { 306.90, -164.99, 1000.26 }, interior = 6, booth = { 299.45, -166.35, 998.61 }, heading = 90 },
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
    -- Dancing (vanilla DANCE) on club floors, and the lowrider contest (vanilla LOWR): a rhythm game.
    dance = {
        floors = {
            { interior = 17, x = 488.00, y = -14.08, z = 999.68 },   -- the Alhambra (vanilla's floor)
            { interior = 11, x = 501.98, y = -72.15, z = 997.84 },   -- ours: inside BAR2
            { interior = 18, x = -224.03, y = 1404.23, z = 26.77 },  -- ours: inside the Lil' Probe Inn
        },
        beats = 40, beatMs = 700, anims = { "dnce_M_a", "dnce_M_b", "dnce_M_c", "dnce_M_d", "dnce_M_e" },
    },
    lowrider = { x = 2644.44, y = -2012.56, z = 12.55, minBet = 50, maxBet = 2000, beats = 30, beatMs = 800,
                 hydraulics = 1087, rival = { 0.55, 0.85 } },  -- ours: the rival's score share range
}
