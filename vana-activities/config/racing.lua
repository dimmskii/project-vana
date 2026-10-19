-- The race tournament (vanilla CPRACE): where races are entered, prizes and race rules. The races
-- themselves (checkpoints, cars) are seeded into [data]/vana-data-activities/activities.map.
Racing = {
    -- Entry points (vanilla's on-foot markers) and the races each offers.
    entries = {
        At("Racing.entries.1", { races = { 0, 1, 2, 3, 4, 5, 6, 7, 8 } }),        -- Los Santos
        At("Racing.entries.2", { races = { 9, 10, 11, 12, 13, 14 } }),            -- San Fierro
        At("Racing.entries.3", { races = { 15, 16, 17, 18 } }),                     -- Las Venturas
        At("Racing.entries.4", { races = { 19, 20, 21, 22, 23, 24 } }),            -- LV airport: air races
        At("Racing.entries.5", { races = { 25 } }),                               -- LS stadium: 8-Track
        At("Racing.entries.6", { races = { 26 }, also = "kickstart" }),            -- LV stadium: Dirt Track
    },
    names = { [25] = "STAD_03", [26] = "STAD_01" },
    interiors = { [25] = 7, [26] = 4 },
    -- First win pays (vanilla): $10000 a race, except these; every race won pays $1000000.
    prize = 10000, prizes = { [0] = 1000, [7] = 5000, [25] = 10000, [26] = 25000 }, allRaces = 1000000,
    -- The 8-Track's first win also parks vanilla's reward cars at the LS stadium.
    stadiumCars = { At("Racing.stadiumCars.1", { model = 556, rz = 178.8 }), At("Racing.stadiumCars.2", { model = 494, rz = 178.8 }) },
    drivers = { 34, 60, 69, 96, 100, 101, 112, 121, 122, 123, 124, 133, 143, 170, 180, 181, 185, 188, 202, 222, 223, 227, 230, 233, 234, 235, 240, 241, 242, 247, 248, 250 },
    outMs = 10000,           -- vanilla: seconds to get back in before disqualification
    radius = 12, airRadius = 20,
    gridBack = 7, gridSide = 3, -- ours: grid rows and columns
    aiSpeed = 48,            -- ours: opponents' cruise speed
    -- Stadium events (vanilla KICKSTA, BLOOD).
    kickstart = {
        interior = 14, bike = 468, start = At("Racing.kickstart.start"), exit = At("Racing.kickstart.exit"),
        timeMs = 240000, payPerPoint = 100,       -- vanilla: score x $100
        -- Coronas: position and colour (1 green = 1 point, 2 amber = 2, 3 red = 3).
        coronas = Spots("Racing.kickstart.coronas"),
    },
    bloodring = {
        entry = At("Racing.bloodring.entry"), interior = 15, car = 504, opponents = 11,
        startMs = 30000, perCheckpointMs = 15000, targetMs = 60000, targetStepMs = 60000, prize = 10000,
        player = At("Racing.bloodring.player"),
        grid = Spots("Racing.bloodring.grid"),
        -- Checkpoints fall at random on the arena floor (vanilla's box).
        area = { -1530, -1384, 923, 995, 1024.1 },
    },
    -- The Chiliad Challenge (vanilla MTBIKER): ride a mountain bike into the summit marker; routes unlock
    -- as you win them, paying $500, $1000, $2000.
    chiliad = { entry = At("Racing.chiliad.entry"), bike = 510, racers = 6,
                names = { "MTROUT1", "MTROUT2", "MTROUT3" }, wins = { "MTWIN1", "MTWIN2", "MTWIN3" }, prizes = { 500, 1000, 2000 } },
    -- BMX and NRG-500 stunt courses (vanilla STUNT): ride the bike onto the marker, enter/exit; collect every corona
    -- before the clock runs out (11 s to start, +10 s per corona). First completion pays $1000.
    stunts = {
        entries = { bmx = At("Racing.stunts.entries.bmx"), nrg = At("Racing.stunts.entries.nrg") },
        startMs = 11000, perCoronaMs = 10000, prize = 1000,
        bmx = { bike = 481, start = At("Racing.stunts.bmx.start"), coronas = Spots("Racing.stunts.bmx.coronas") },
        nrg = { bike = 522, start = At("Racing.stunts.nrg.start"), coronas = Spots("Racing.stunts.nrg.coronas") },

    },
    -- Beat the Cock! (vanilla TRIA): run, swim, cycle, run. stages: vanilla's checkpoint indices (start, swim
    -- from, swim to, bikes at, ..., dismount, run from, finish). Vanilla races 12 athletes; ours races the
    -- clock: the target is each leg's length at these speeds (m/s).
    triathlon = {
        entries = { beach = At("Racing.triathlon.entries.beach"), fleischberg = At("Racing.triathlon.entries.fleischberg") },
        prizes = { beach = 10000, fleischberg = 20000 }, bike = 510, outMs = 10000,
        pace = { run = 5.0, swim = 1.8, bike = 8.5 },
        beach = { stages = { 0, 1, 7, 8, 8, 37, 37, 38, 62 }, checkpoints = Spots("Racing.triathlon.beach.checkpoints") },
        fleischberg = { stages = { 0, 1, 9, 10, 10, 96, 96, 97, 103 }, checkpoints = Spots("Racing.triathlon.fleischberg.checkpoints") },

    },
}
