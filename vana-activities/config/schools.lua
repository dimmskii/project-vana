-- Schools (vanilla DSKOOL, BSKOOL, BOAT, DESERT5 "Learning to Fly"). Each school has a menu point where
-- tests are chosen, a test start, medals (vanilla 70 / 85 / 100%) and vanilla's reward vehicles for
-- every test at bronze, silver or gold. Test positions are offsets from the start in its frame:
-- { right, forward } metres (vanilla works them out from the test car the same way). Scoring constants
-- marked "ours" condense vanilla's per-test maths.
Schools = {
    driving = {
        title = "Driving School", gxt = "DS",
        menu = { -2031.2, -118.0, 1034.2, interior = 3 },   -- the noticeboard / TV inside the school
        start = { -2050.6, -130.0, 34.3, 180 },              -- the test area behind the school
        skill = { stat = 160, gain = 40 },                   -- vanilla: driving skill +40 per pass
        rewards = {
            { medal = 1, model = 506, x = -2093.9, y = -83.7, z = 33.9, rz = 359.1 },                    -- Super GT
            { medal = 2, model = 541, x = -2076.8, y = -84.0, z = 33.7, rz = 1.1 },                      -- Bullet
            { medal = 3, model = 434, x = -2064.4, y = -83.7, z = 34.1, rz = 0.0, plate = "__GOLD__" },  -- Hotknife
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
              timeMs = 240000, from = { -2046.7, -90.2, 33.9, 180 }, via = { -1724.3, 1294.0, 6.0 } },
        },
    },
    bike = {
        title = "Bike School", gxt = "BS",
        menu = { 1173.93, 1351.07, 9.92, interior = 0 },     -- the noticeboard at the stadium
        start = { 1130.44, 1341.0, 10.0, 180 },
        skill = { stat = 229, gain = 50 },                   -- vanilla: bike skill +50 per pass
        rewards = {
            { medal = 1, model = 463, x = 1174.76, y = 1364.83, z = 10.12, rz = 280.0 },  -- Freeway
            { medal = 2, model = 521, x = 1175.00, y = 1366.48, z = 10.12, rz = 282.2 },  -- FCR-900
            { medal = 3, model = 522, x = 1174.47, y = 1368.36, z = 10.12, rz = 283.1 },  -- NRG-500
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
        menu = { -2187.38, 2416.55, 4.17, interior = 0 },
        start = { -2323.63, 2105.29, 0.5, 90 },
        rewards = {
            { medal = 1, model = 484, x = -2227.10, y = 2445.78, z = 0.0, rz = 229.4 },  -- Marquis
            { medal = 2, model = 446, x = -2223.87, y = 2409.87, z = 0.0, rz = 49.1 },   -- Squalo
            { medal = 3, model = 493, x = -2247.84, y = 2425.68, z = 0.0, rz = 220.2 },  -- Jetmax
        },
        -- Medals are vanilla's times (bronze, silver, gold ms) or jump distances (m).
        tests = {
            { key = "basic", title = "BOAT_A", help = "BOAT_A4", vehicle = 472, kind = "region", medals = { 12000, 10500, 9700 },
              timeMs = 30000, region = { 0, 80 }, width = 10, depth = 12 },
            { key = "course", title = "BOAT_B", help = "BOAT_B4", vehicle = 472, kind = "gates", medals = { 40000, 37000, 33000 },
              timeMs = 80000, from = { -2578.67, 2050.84, 0.5, 0 }, width = 12,
              gates = { { 0, 80 }, { 40, 160 }, { 0, 240 }, { -40, 320 }, { 0, 400 } } },             -- ours: vanilla's are in loops
            { key = "slalom", title = "BOAT_C", help = "BOAT_C1", vehicle = 473, kind = "gates", medals = { 120000, 85000, 80000 },
              timeMs = 200000, from = { -2124.13, 2438.35, 0.5, 180 }, width = 10,
              gates = { { 15, 60 }, { -15, 120 }, { 15, 180 }, { -15, 240 }, { 15, 300 }, { -15, 360 }, { 15, 420 }, { -15, 480 },
                        { 0, 560 }, { 30, 520 }, { 45, 440 }, { 30, 360 }, { 45, 280 }, { 30, 200 }, { 45, 120 }, { 20, 40 } } }, -- ours
            { key = "flyingfish", title = "BOAT_D", help = "BOAT_D1", vehicle = 539, kind = "fishjump", medals = { 55, 63, 67 },
              timeMs = 40000, from = { -2318.05, 2312.30, 1.0, 174.6 }, ramp = { 0, 70 }, width = 20 },
            { key = "landseaair", title = "BOAT_E", help = "BOAT_C1", vehicle = 539, kind = "gates", medals = { 180000, 150000, 130000 },
              timeMs = 300000, from = { -2014.27, 2365.43, 6.05, 111 }, width = 14, world = {
                { -1886.39, 2070.88 }, { -1839.55, 1907.61 }, { -1806.99, 1795.02 }, { -1936.99, 1835.02 }, { -2036.99, 1755.02 },
                { -2136.99, 1815.02 }, { -2277.57, 1749.17 }, { -2327.57, 1649.17 }, { -2277.57, 1549.17 }, { -2352.22, 1467.90 },
                { -2452.22, 1487.90 }, { -2552.22, 1487.90 }, { -2681.96, 1531.70 }, { -2681.96, 1607.79 }, { -2681.96, 1944.74 } } },
        },
    },
    flight = {
        title = "Flight School", gxt = "DSERT5",
        menu = { 415.55, 2533.57, 19.18, interior = 0 },     -- Verdant Meadows
        start = { 321.52, 2502.31, 17.16, 90 },              -- on the runway, facing west
        skill = { stat = 223, gain = 50 },                   -- ours: flying skill per pass
        rewards = {
            { medal = 1, model = 476, x = 325.12, y = 2537.10, z = 17.52, rz = 180 },  -- Rustler
            { medal = 2, model = 513, x = 348.00, y = 2537.10, z = 17.42, rz = 180 },  -- Stuntplane
            { medal = 3, model = 425, x = 365.51, y = 2537.10, z = 17.42, rz = 180 },  -- Hunter
        },
        -- Rings are world positions (vanilla's, from the runway's ends); radius 15 as vanilla's tori.
        tests = {
            { key = "takeoff", title = "DES5_MA", help = "DES5_1A", vehicle = 476, kind = "rings", targetMs = 45000, timeMs = 120000,
              rings = { { -383.79, 2502.31, 147.09 }, { -683.79, 2502.31, 127.09 }, { -1033.79, 2502.31, 157.09 } } },
            { key = "land", title = "DES5_MB", help = "DES5_5H", vehicle = 476, kind = "landat", timeMs = 120000,
              from = { -383.79, 2502.31, 85.09, 270 }, target = { 177.28, 2502.31, 17.2 }, length = 400 },
            { key = "circle", title = "DES5_MC", help = "DES5_2C", vehicle = 476, kind = "rings", targetMs = 120000, timeMs = 240000,
              from = { -383.79, 2502.31, 85.09, 270 },
              rings = { { -683.79, 2502.31, 100 }, { -783.79, 2802.31, 110 }, { -83.79, 2902.31, 110 }, { 635.92, 2802.31, 110 },
                        { 735.92, 2502.31, 100 }, { 635.92, 2202.31, 110 }, { -83.79, 2102.31, 110 }, { -383.79, 2502.31, 100 } } }, -- ours
            { key = "circleland", title = "DES5_MD", help = "DES5_2C", vehicle = 476, kind = "rings", land = true, targetMs = 150000,
              timeMs = 300000, from = { -383.79, 2502.31, 85.09, 270 },
              rings = { { -683.79, 2502.31, 100 }, { -783.79, 2802.31, 110 }, { -83.79, 2902.31, 110 }, { 635.92, 2802.31, 110 },
                        { 735.92, 2502.31, 80 }, { 535.92, 2502.31, 40 } } },                                                       -- ours
            { key = "helitakeoff", title = "DES5_ME", help = "DES5_7A", vehicle = 425, kind = "rings", targetMs = 30000, timeMs = 90000,
              from = { 321.52, 2502.31, 15.07, 270 }, rings = { { -178.48, 2502.31, 137.16 } } },
            { key = "heliland", title = "DES5_MF", help = "DES5_8A", vehicle = 425, kind = "landat", timeMs = 120000,
              from = { -383.79, 2502.31, 85.09, 270 }, target = { 308.0, 2502.31, 17.07 }, length = 30 },
            { key = "targets", title = "DES5_MG", help = "DES5_9A", vehicle = 425, kind = "destroy", targetMs = 60000, timeMs = 180000,
              from = { -383.79, 2502.31, 85.09, 270 }, trucks = { { 418.5, 2502.31, 17.1 }, { 378.5, 2502.31, 17.1 }, { 338.5, 2502.31, 17.1 } } },
            { key = "loop", title = "DES5_MH", help = "DES5_AA", vehicle = 513, kind = "aerobatic", turn = "pitch", timeMs = 90000,
              from = { -383.79, 2502.31, 80, 270 }, rings = { { 177.28, 2502.31, 80 }, { 377.28, 2502.31, 80 } } },
            { key = "roll", title = "DES5_MI", help = "DES5_BB", vehicle = 513, kind = "aerobatic", turn = "roll", timeMs = 90000,
              from = { -383.79, 2502.31, 80, 270 }, rings = { { 177.28, 2502.31, 80 }, { 377.28, 2502.31, 80 } } },
            { key = "parachute", title = "DES5_MJ", help = "DES5_CA", kind = "parachute", timeMs = 120000,
              from = { 527.28, 2502.31, 900, 90 }, target = { 177.28, 2502.31, 15.53 }, radius = 6.5 },
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
