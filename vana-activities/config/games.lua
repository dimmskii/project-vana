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
}
