-- Schools (vanilla DSKOOL, BSKOOL, BOAT, DESERT5 "Learning to Fly"). Each school has a menu point where
-- tests are chosen, a test start, medals (vanilla 70 / 85 / 100%) and vanilla's reward vehicles for
-- every test at bronze, silver or gold. Test positions are offsets from the start in its frame:
-- { right, forward } metres (vanilla works them out from the test car the same way). Scoring constants
-- marked "ours" condense vanilla's per-test maths.
Schools = {
    driving = {
        title = "Driving School", gxt = "DS",
        menu = At("Schools.driving.menu", { interior = 3 }),   -- the noticeboard / TV inside the school
        start = At("Schools.driving.start"),              -- the test area behind the school
        skill = { stat = 160, gain = 40 },                   -- vanilla: driving skill +40 per pass
        rewards = {
            At("Schools.driving.rewards.1", { medal = 1, model = 506, rz = 359.1 }),                    -- Super GT
            At("Schools.driving.rewards.2", { medal = 2, model = 541, rz = 1.1 }),                      -- Bullet
            At("Schools.driving.rewards.3", { medal = 3, model = 434, rz = 0.0, plate = "__GOLD__" }),  -- Hotknife
        },
        tests = {
            { key = "the360", title = "DS_P", help = "DS1_44", vehicle = 411, kind = "donut", timeMs = 11000,
              circle = { at = { 0, 1 }, radius = 6, count = 15 } },
            { key = "the180", title = "DS_O", help = "DS1_45", vehicle = 496, kind = "turn", timeMs = 20000,
              turn = { 0, 86 }, circle = { at = { 0, 86 }, radius = 10, count = 7, from = 90, step = 30 } },
            { key = "whip", title = "DS_I", help = "DS1_32", vehicle = 429, kind = "stopzone", timeMs = 15000,
              zone = { 40, 37 }, heading = 90, circle = { at = { 4, 30 }, radius = 3, count = 6 } },
            { key = "popcontrol", title = "DS_F", help = "DS1_30", vehicle = 597, kind = "stopzone", timeMs = 20000,
              zone = { 0, 120 }, heading = 0, stinger = { 0, 37 } },
            { key = "burnlap", title = "DS_E", help = "DS1_29", vehicle = 429, kind = "laps", laps = 5, targetMs = 40000,
              timeMs = 120000, ends = { { 4, 50 }, { 4, -4 } }, radius = 6 },
            { key = "conecoil", title = "DS_N", help = "DS1_36", vehicle = 429, kind = "coil", targetMs = 20000,
              timeMs = 60000, turn = { -0.5, 81 }, radius = 8, gates = 6 },
            { key = "the90", title = "DS_A", help = "DS1_1", vehicle = 429, kind = "stopzone", timeMs = 15000,
              zone = { 0, 75 }, heading = 90, parked = { { 6, 75 }, { -6, 75 } } },
            { key = "wheelieweave", title = "DS_K", help = "DS1_34", vehicle = 429, kind = "twowheels", timeMs = 30000,
              length = 80, ramp = { 1.2, 12 } },
            { key = "spingo", title = "DS_C", help = "DS1_28", vehicle = 420, kind = "turn", timeMs = 15000,
              reverse = true, turn = { 0, -25 } },
            { key = "pit", title = "DS_L", help = "DS1_35", vehicle = 597, kind = "pit", timeMs = 30000,
              target = { model = 597, at = { 0, 10 }, speed = 14 } },
            { key = "alleyoop", title = "DS_J", help = "DS1_33", vehicle = 429, kind = "roll", timeMs = 20000,
              ramp = { 0, 60 }, landing = { 0, 110 } },
            { key = "cityslicking", title = "DS_G", help = "DS1_31", vehicle = 506, kind = "route", targetMs = 120000,
              timeMs = 240000, from = At("Schools.driving.tests.12.from"), via = At("Schools.driving.tests.12.via") },
        },
    },
    bike = {
        title = "Bike School", gxt = "BS",
        menu = At("Schools.bike.menu", { interior = 0 }),     -- the noticeboard at the stadium
        start = At("Schools.bike.start"),
        skill = { stat = 229, gain = 50 },                   -- vanilla: bike skill +50 per pass
        rewards = {
            At("Schools.bike.rewards.1", { medal = 1, model = 463, rz = 280.0 }),  -- Freeway
            At("Schools.bike.rewards.2", { medal = 2, model = 521, rz = 282.2 }),  -- FCR-900
            At("Schools.bike.rewards.3", { medal = 3, model = 522, rz = 283.1 }),  -- NRG-500
        },
        tests = {
            { key = "the360", title = "BS_A", help = "BS_A_1", vehicle = 581, kind = "donut", timeMs = 11000,
              circle = { at = { 0, 1 }, radius = 6, count = 15 } },
            { key = "the180", title = "BS_B", help = "BS_B_1", vehicle = 461, kind = "turn", timeMs = 20000,
              turn = { 0, 85 }, circle = { at = { 0, 85 }, radius = 3, count = 6 } },
            { key = "wheelie", title = "BS_C", help = "BS_C_1", vehicle = 521, kind = "section", wheel = "front", timeMs = 25000,
              section = { 56, 84 }, width = 3.5, zone = { 0, 124 } },
            { key = "stoppie", title = "BS_D", help = "BS_D_1", vehicle = 521, kind = "section", wheel = "rear", timeMs = 25000,
              section = { 56, 84 }, width = 3.5, zone = { 0, 124 } },
            { key = "jumpstop", title = "BS_E", help = "BS_E_1", vehicle = 468, kind = "jumpstop", timeMs = 20000,
              ramp = { 0, 46 }, zone = { 0, 124 } },
            { key = "jumpstoppie", title = "BS_F", help = "BS_F_1", vehicle = 522, kind = "jumpstop", stoppie = true, timeMs = 20000,
              ramp = { 0, 46 }, zone = { 0, 114 } },
        },
    },
    boat = {
        title = "Boat School", gxt = "BOAT",
        menu = At("Schools.boat.menu", { interior = 0 }),
        start = At("Schools.boat.start"),
        rewards = {
            At("Schools.boat.rewards.1", { medal = 1, model = 484, rz = 229.4 }),  -- Marquis
            At("Schools.boat.rewards.2", { medal = 2, model = 446, rz = 49.1 }),   -- Squalo
            At("Schools.boat.rewards.3", { medal = 3, model = 493, rz = 220.2 }),  -- Jetmax
        },
        -- Medals are vanilla's times (bronze, silver, gold ms) or jump distances (m).
        tests = {
            { key = "basic", title = "BOAT_A", help = "BOAT_A4", vehicle = 472, kind = "region", medals = { 12000, 10500, 9700 },
              timeMs = 30000, region = { 0, 80 }, width = 10, depth = 12 },
            { key = "course", title = "BOAT_B", help = "BOAT_B4", vehicle = 472, kind = "gates", medals = { 40000, 37000, 33000 },
              timeMs = 80000, from = At("Schools.boat.tests.2.from"), width = 12,
              gates = { { 0, 80 }, { 40, 160 }, { 0, 240 }, { -40, 320 }, { 0, 400 } } },             -- ours: vanilla's are in loops
            { key = "slalom", title = "BOAT_C", help = "BOAT_C1", vehicle = 473, kind = "gates", medals = { 120000, 85000, 80000 },
              timeMs = 200000, from = At("Schools.boat.tests.3.from"), width = 10,
              gates = { { 15, 60 }, { -15, 120 }, { 15, 180 }, { -15, 240 }, { 15, 300 }, { -15, 360 }, { 15, 420 }, { -15, 480 },
                        { 0, 560 }, { 30, 520 }, { 45, 440 }, { 30, 360 }, { 45, 280 }, { 30, 200 }, { 45, 120 }, { 20, 40 } } }, -- ours
            { key = "flyingfish", title = "BOAT_D", help = "BOAT_D1", vehicle = 539, kind = "fishjump", medals = { 55, 63, 67 },
              timeMs = 40000, from = At("Schools.boat.tests.4.from"), ramp = { 0, 70 }, width = 20 },
            { key = "landseaair", title = "BOAT_E", help = "BOAT_C1", vehicle = 539, kind = "gates", medals = { 180000, 150000, 130000 },
              timeMs = 300000, from = At("Schools.boat.tests.5.from"), width = 14, world = {
                { -1886.39, 2070.88 }, { -1839.55, 1907.61 }, { -1806.99, 1795.02 }, { -1936.99, 1835.02 }, { -2036.99, 1755.02 },
                { -2136.99, 1815.02 }, { -2277.57, 1749.17 }, { -2327.57, 1649.17 }, { -2277.57, 1549.17 }, { -2352.22, 1467.90 },
                { -2452.22, 1487.90 }, { -2552.22, 1487.90 }, { -2681.96, 1531.70 }, { -2681.96, 1607.79 }, { -2681.96, 1944.74 } } },
        },
    },
    flight = {
        title = "Flight School", gxt = "DSERT5",
        menu = At("Schools.flight.menu", { interior = 0 }),     -- Verdant Meadows
        start = At("Schools.flight.start"),              -- on the runway, facing west
        skill = { stat = 223, gain = 50 },                   -- ours: flying skill per pass
        rewards = {
            At("Schools.flight.rewards.1", { medal = 1, model = 476, rz = 180 }),  -- Rustler
            At("Schools.flight.rewards.2", { medal = 2, model = 513, rz = 180 }),  -- Stuntplane
            At("Schools.flight.rewards.3", { medal = 3, model = 425, rz = 180 }),  -- Hunter
        },
        -- Rings are world positions (vanilla's, from the runway's ends); radius 15 as vanilla's tori.
        tests = {
            { key = "takeoff", title = "DES5_MA", help = "DES5_1A", vehicle = 476, kind = "rings", targetMs = 45000, timeMs = 120000,
              rings = Spots("Schools.flight.tests.1.rings") },
            { key = "land", title = "DES5_MB", help = "DES5_5H", vehicle = 476, kind = "landat", timeMs = 120000,
              from = At("Schools.flight.tests.2.from"), target = At("Schools.flight.tests.2.target"), length = 400 },
            { key = "circle", title = "DES5_MC", help = "DES5_2C", vehicle = 476, kind = "rings", targetMs = 120000, timeMs = 240000,
              from = At("Schools.flight.tests.3.from"),
              rings = Spots("Schools.flight.tests.3.rings") }, -- ours
            { key = "circleland", title = "DES5_MD", help = "DES5_2C", vehicle = 476, kind = "rings", land = true, targetMs = 150000,
              timeMs = 300000, from = At("Schools.flight.tests.4.from"),
              rings = Spots("Schools.flight.tests.4.rings") },                                                       -- ours
            { key = "helitakeoff", title = "DES5_ME", help = "DES5_7A", vehicle = 425, kind = "rings", targetMs = 30000, timeMs = 90000,
              from = At("Schools.flight.tests.5.from"), rings = Spots("Schools.flight.tests.5.rings") },
            { key = "heliland", title = "DES5_MF", help = "DES5_8A", vehicle = 425, kind = "landat", timeMs = 120000,
              from = At("Schools.flight.tests.6.from"), target = At("Schools.flight.tests.6.target"), length = 30 },
            { key = "targets", title = "DES5_MG", help = "DES5_9A", vehicle = 425, kind = "destroy", targetMs = 60000, timeMs = 180000,
              from = At("Schools.flight.tests.7.from"), trucks = Spots("Schools.flight.tests.7.trucks") },
            { key = "loop", title = "DES5_MH", help = "DES5_AA", vehicle = 513, kind = "aerobatic", turn = "pitch", timeMs = 90000,
              from = At("Schools.flight.tests.8.from"), rings = Spots("Schools.flight.tests.8.rings") },
            { key = "roll", title = "DES5_MI", help = "DES5_BB", vehicle = 513, kind = "aerobatic", turn = "roll", timeMs = 90000,
              from = At("Schools.flight.tests.9.from"), rings = Spots("Schools.flight.tests.9.rings") },
            { key = "parachute", title = "DES5_MJ", help = "DES5_CA", kind = "parachute", timeMs = 120000,
              from = At("Schools.flight.tests.10.from"), target = At("Schools.flight.tests.10.target"), radius = 6.5 },
        },
    },
}

-- Medal thresholds (vanilla), and how scores are made (ours where noted).
SchoolRules = {
    medals = { 70, 85, 100 },
    headingPerPoint = 2,     -- ours: a degree off the target heading costs 1/2 %
    metrePerPoint = 0.2,     -- ours: a metre off the target position costs 5 %
    damagePerPoint = 10,     -- ours: 10 points of vehicle damage cost 1 %
    conePenalty = 5,         -- ours: each cone knocked over costs 5 %
    lateFloor = 70,          -- ours: timed tests pay 100% at the target time, 70% at double it
    ringRadius = 15,         -- vanilla's tori
}
