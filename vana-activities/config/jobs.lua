-- Vehicle side jobs (vanilla sub-missions launched with the sub-mission key). Values from the mission
-- scripts unless marked "ours".
Jobs = {
    -- Ours: who hails a cab or needs an ambulance (ordinary civilians).
    civilians = { 7, 9, 10, 11, 12, 13, 14, 15, 17, 20, 21, 22, 23, 24, 25, 26, 29, 31, 32, 33, 34, 35, 36, 37,
                  38, 39, 40, 41, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62 },
    taxi = {
        vehicles = { 420, 438 },
        firstTimeMs = 36000,       -- the clock when the first fare gets in
        -- Time per metre to the destination (ms), by fares done in a row (vanilla: 100 down to 60).
        msPerMetre = { [0] = 100, 95, 80, 79, 78, 76, 75, 75, 75, 75, 75 }, msPerMetreLater = 70, msPerMetreLate = 65,
        msPerMetreLatest = 60,
        fare = 40, fareFast = 16,  -- pay = distance / fare (or / fareFast with tip left: the speed bonus)
        streakEvery = 5, streakBonus = 500, -- every 5 fares in a row: $500, then $1000, ...
        damagePenaltyMs = 180,     -- each point of taxi damage takes this off the tip
        pickupRange = { 60, 180 }, destinationRange = { 300, 1500 }, -- ours (vanilla picks nearby peds / its own spots)
        pickupRadius = 8, dropRadius = 6,
        junkHealth = 400,          -- ours: below this the fare refuses (vanilla: "car is trashed")
        outOfTaxiMs = 10000,       -- ours: time to get back in before the job ends
        rewardFares = 50,          -- vanilla: 50 fares in total -> all taxis get nitro
    },
    paramedic = {
        vehicles = { 416 },
        levels = 12,               -- level N: N patients; level 12 done = the reward
        pay = 50,                  -- each level pays level x level x this
        patientMs = { 15000, 45000 }, minimumMs = 60000, -- vanilla clamps per patient and overall
        msPerMetre = 70,           -- ours: per patient, from where you are via them to the hospital
        patientRange = { 100, 600 }, -- ours: how far patients are
        pickupRadius = 7, dropRadius = 7,
        bump = 40,                 -- ours: ambulance damage in one jolt that hurts patients aboard (life 100 each)
        outMs = 10000,
        completeBonus = 5000,
        -- Hospitals (vanilla's drop-offs).
        hospitals = { { 2004.96, -1442.96, 12.56 }, { 1180.85, -1325.57, 12.58 }, { 1244.44, 331.23, 18.55 },
                      { -2198.69, -2290.11, 29.63 }, { -2670.29, 616.44, 13.45 }, { -316.38, 1056.05, 18.73 },
                      { -1514.82, 2527.12, 54.74 }, { 1578.45, 1770.68, 9.84 } },
    },
    firefighter = {
        vehicles = { 407 },
        levels = 12, pay = 50, completeBonus = 5000, -- as paramedic: level x level x $50, $5000 at 12
        carModels = { 400, 401, 404, 405, 410, 412, 418, 420, 421, 426, 436, 445, 466, 467, 474, 475, 491, 492,
                      496, 507, 516, 517, 518, 526, 527, 529, 540, 542, 546, 547, 549, 550, 551, 554, 560, 562, 566 },
        range = { 250, 800 },      -- ours: how far the fire is
        msPerMetre = 120, extraMs = 30000, perFireMs = 6000, -- ours: vanilla works the clock out from the route
        outMs = 10000,
    },
    vigilante = {
        -- Police vehicles (and the Hunter: vanilla's "Brown Thunder").
        vehicles = { 596, 597, 598, 599, 523, 427, 490, 528, 601, 425 },
        levels = 12, pay = 50,     -- level x level x $50
        criminalCars = { 521, 522, 461, 462, 463, 468, 581, 586, 411, 415, 429, 451, 477, 480, 506, 541, 603,
                         400, 401, 402, 410, 412, 413, 419 },
        criminals = { 28, 29, 30, 47, 48, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 114, 115, 116 },
        perCar = 4,                -- vanilla: four criminals to a car, a new car every 4 levels
        minimumMs = 40000, speed = 6, -- vanilla: the clock is distance / (4 + bonus) m/s, at least 40 s
        range = { 200, 700 },      -- ours
        weapons = { 22, 28, 32, 30 }, -- ours: pistols at first, SMGs and an AK as levels climb
        bailRadius = 25,           -- ours: criminals ditch the car and fight when you're this close and they're slow
        outMs = 10000,
    },
    pimping = {
        vehicles = { 575 },        -- the Broadway
        startMs = 180000, perJobMs = 60000, -- vanilla: 3 minutes, +1 per delivery
        payPerJob = 300,           -- vanilla: paid when the session ends, per job done
        rewardJobs = 10,           -- vanilla: 10 jobs in a session -> prostitutes pay you
        girls = { 63, 64, 75, 152, 178, 207, 237, 238, 243, 244, 245, 246, 256, 257 },
        girlRange = { 100, 400 }, trickRange = { 400, 1200 }, -- ours
        serviceMs = { 20000, 40000 }, -- ours: how long she's busy
        radius = 7, outMs = 15000,
    },
    freight = {
        vehicles = { 537, 538 },
        -- Stations in line order, with vanilla's time to reach each going one way (forward) or the other.
        stations = {
            { 1698.83, -1953.75, 12.55, forward = 150000, back = 60000 },  -- Unity Station, LS
            { 789.50, -1343.80, -2.58, forward = 60000, back = 140000 },   -- Market Station, LS
            { -1943.24, 159.59, 24.72, forward = 140000, back = 150000 },  -- Cranberry Station, SF
            { 1463.36, 2632.25, 9.82, forward = 150000, back = 105000 },   -- Yellow Bell Station, LV
            { 2864.62, 1248.27, 9.82, forward = 105000, back = 150000 },   -- Linden Station, LV
        },
        extraMs = { 15000, 10000 }, -- per leg, by level
        levelBonus = { 10000, 50000 },
        radius = 10, outMs = 10000,
    },
    trucking = {
        start = { -77.65, -1136.40, 0.08 },       -- RS Haul, Flint County: walk into the marker
        truckSpot = { -76.17, -1128.96, 0.08, 70 }, trailerSpot = { -60.60, -1136.90, 0.08, 70 },
        trucks = { 514, 403, 515 }, trailers = { 584, 435, 450, 591 },
        -- Vanilla's drop-offs.
        destinations = {
            { -187.40, -277.02, 0.42 }, { 58.04, -256.73, 0.58 }, { 95.87, -154.36, 1.58 }, { 809.76, -598.00, 15.19 },
            { 1403.83, 399.43, 18.75 }, { 1338.29, 348.90, 18.41 }, { 1449.72, 2358.85, 9.82 }, { 1037.48, 2131.34, 9.82 },
            { 987.97, 2080.39, 9.82 }, { 1288.67, 1195.23, 9.87 }, { 2467.90, 1950.06, 9.24 }, { 2792.74, 2578.34, 9.82 },
            { 2271.48, 2791.74, 9.82 }, { 2596.52, 1738.58, 9.83 }, { 2818.84, 912.51, 9.75 }, { 2706.50, 827.32, 9.21 },
            { 1627.72, 688.40, 9.83 }, { 1504.49, 981.14, 9.72 }, { 1724.01, 1590.13, 9.26 }, { 1727.83, 2338.02, 9.81 },
            { 2413.68, -2113.67, 12.39 }, { 2784.97, -2455.44, 12.63 }, { 2112.66, -2070.38, 12.55 }, { 1763.64, -2070.37, 12.62 },
            { -1888.62, -1711.84, 20.77 }, { -2117.23, -2380.51, 29.47 }, { -1545.44, -2747.03, 47.53 }, { -1407.37, 2645.96, 54.70 },
            { -2245.58, 2371.69, 3.99 }, { -1360.63, 2068.09, 51.46 }, { 274.27, 1382.78, 9.60 }, { 628.86, 1714.89, 5.99 },
            { 635.00, 1213.78, 10.72 }, { -914.95, 2012.14, 59.93 }, { 385.82, 2595.55, 15.48 }, { -1556.98, -441.35, 5.0 },
            { -2659.63, 1380.64, 6.16 }, { -1650.93, 437.57, 6.18 }, { -1745.12, 37.88, 2.54 },
        },
        -- Load types (vanilla TRK_H6..H12): fragile (damage costs cash), timed (late halves the pay), hot
        -- (police interest, stars), or both.
        loads = {
            { help = "TRK_H6", fragile = true }, { help = "TRK_H7", timed = true }, { help = "TRK_H9", stars = 1 },
            { help = "TRK_H10", stars = 2 }, { help = "TRK_H11", fragile = true, timed = true }, { help = "TRK_H12", fragile = true, veryFragile = true },
        },
        cashPerMetre = 1.4,         -- ours, from vanilla's distance x 140 scaling
        msPerMetre = 140,           -- ours: the deadline for timed loads
        attachGraceMs = 30000, cabGraceMs = 30000,
        missions = 8,               -- vanilla: 8 missions buy you the depot
        income = { pickup = { -82.27, -1135.53, 0.58 }, perDay = 2000, cap = 2000 },
        dropRadius = 8,
    },
    quarry = {
        start = { 823.68, 854.17, 10.79 },   -- the site office
        pay = { 500, 1000, 2000, 3000, 5000, 7500, 10000 },
        dozer = 486, dumper = 406, copBike = 523,
        entrance = { 808.41, 841.99, 10.0 }, depot = { 816.48, 845.85, 9.49, 0 },
        -- 1: the cop's body and bike, pushed to the crane's pick-up area. Vanilla then has you work the
        -- crane to load the dumper; MTA has no crane controls, so the load goes aboard when both are there.
        cop = { body = { 606.95, 933.09, -38.53 }, bike = { 560.30, 844.94, -13.03 }, dozer = { 653.16, 879.98, -42.58, 0 },
                dumper = { 717.02, 938.37, -19.73, 0 }, pickup = { 705.11, 916.32, -19.64 }, water = { 371.55, 978.17, 28.52 },
                timeMs = 420000 },
        -- 2: rocks over the edge into their markers.
        rocks = { timeMs = 480000, items = {
            { 771.64, 836.23, 4.90, target = { 762.12, 836.65, -3.44 } }, { 751.67, 945.00, 4.86, target = { 735.87, 933.04, -4.39 } },
            { 538.91, 985.64, -8.59, target = { 518.97, 967.76, -25.89 } }, { 680.53, 963.45, -13.66, target = { 671.33, 941.19, -29.34 } },
            { 516.84, 928.72, -27.62, target = { 523.22, 907.20, -43.41 } }, { 522.62, 828.30, -27.18, target = { 536.80, 838.08, -38.23 } },
            { 646.72, 752.23, -12.15, target = { 645.26, 773.70, -28.25 } } } },
        -- 3: bombs to their safe areas, one at a time, each against its own clock.
        bombs = { perBombMs = 90000, items = {
            { 817.07, 865.59, 11.05, target = { 830.43, 889.85, 12.35 }, line = "QUAR_16" },
            { 714.53, 920.06, -19.68, target = { 678.58, 981.43, -13.75 }, line = "QUAR_17" },
            { 632.28, 895.86, -43.95, target = { 660.67, 913.72, -41.41 }, line = "QUAR_18" },
            { 675.80, 841.87, -43.96, target = { 632.45, 810.32, -43.96 }, line = "QUAR_34" } } },
        -- 4: the bombers' bodies on a dumper at the other entrance, burned on the quarry floor.
        bodies = { dumper = { 355.86, 895.65, 19.40, 0 }, fire = { 469.38, 877.28, -29.04 }, timeMs = 360000 },
        -- 5: explosives to the desert airstrip and back, gently.
        explosives = { airstrip = { -59.31, 2502.25, 15.48 }, timeMs = 600000, jolt = 60 },
        -- 6: explosives spilled along the tracks, pushed clear before the train.
        tracks = { timeMs = 240000, clear = 4, items = {
            { 744.14, 1583.60, 7.54 }, { 743.04, 1602.77, 7.14 }, { 743.58, 1616.75, 6.85 }, { 742.66, 1653.42, 6.16 },
            { 743.81, 1671.52, 5.85 }, { 742.58, 1700.30, 5.42 }, { 743.44, 1730.14, 5.07 }, { 742.02, 1765.32, 4.66 },
            { 742.18, 1812.38, 4.33 }, { 742.72, 1869.99, 4.33 } } },
        -- 7: thieves escaping in a dumper: wreck it.
        thieves = { dumper = { 812.50, 1144.57, 27.34, 0 }, warn = 400, lose = 650 },
        -- The reward (vanilla car generators): a dumper and a bulldozer always at the quarry.
        reward = { { 406, 687.37, 890.67, -40.43, 35.1 }, { 486, 620.88, 861.25, -43.95, 298.7 } },
        models = { rock = 1303, barrel = 3046, body = 3092, crate = 3014, ammo = 3013 },
    },
    courier = {
        -- Per city: the bike, the pick-up point (start marker and where you're paid) and vanilla's drop-offs.
        cities = {
            { name = "BCOU_18", bike = 481, base = { 1359.45, -1755.0, 12.85 }, back = { 1346.02, -1741.78, 12.40 },
              drops = { { 1286.77, -1676.17, 12.56 }, { 1544.06, -1675.75, 12.56 }, { 1320.10, -1795.10, 12.54 }, { 1614.26, -1885.76, 12.55 },
                        { 2009.17, -1716.91, 12.55 }, { 1256.51, -1010.97, 32.90 }, { 1016.67, -1508.78, 12.54 }, { 2865.39, -1438.96, 9.97 },
                        { 2740.56, -2103.44, 11.12 }, { 1346.46, -989.38, 28.03 }, { 150.49, -1945.38, 2.77 }, { 378.09, -2053.58, 7.02 },
                        { 804.57, -1020.71, 25.68 } } },
            { name = "BCOU_20", bike = 463, base = { -2590.44, 73.21, 3.91 }, back = { -2594.82, 52.60, 3.34 },
              drops = { { -2797.95, 209.73, 6.20 }, { -2492.77, -196.66, 24.62 }, { -2611.99, -110.73, 3.33 }, { -2176.39, -41.71, 34.31 },
                        { -2243.90, 603.70, 40.12 }, { -1569.99, 662.33, 6.19 }, { -2756.37, 379.16, 3.33 }, { -2609.90, 131.94, 3.33 },
                        { -2743.86, 761.41, 53.38 }, { -2600.54, 980.75, 77.27 }, { -2153.96, 716.16, 68.55 }, { -2153.60, 251.92, 34.31 },
                        { -2808.29, -340.24, 6.18 }, { -2428.85, -164.12, 34.31 }, { -1984.21, 128.76, 26.68 }, { -1888.46, 819.63, 34.18 },
                        { -1503.33, 919.93, 6.18 }, { -2533.88, 987.91, 77.30 } } },
            { name = "BCOU_19", bike = 462, base = { 1887.79, 2087.39, 10.05 }, back = { 1904.68, 2096.17, 9.82 },
              drops = { { 1698.40, 2054.90, 9.82 }, { 2159.83, 2066.73, 9.81 }, { 1935.70, 2158.46, 9.82 }, { 1654.33, 1803.81, 9.81 },
                        { 2083.32, 1503.75, 9.81 }, { 1720.11, 1298.55, 9.82 }, { 2233.84, 1282.19, 9.82 }, { 1917.76, 2768.87, 9.82 },
                        { 2344.57, 2779.97, 9.82 }, { 973.12, 1782.24, 7.66 }, { 2346.52, 2296.97, 7.15 }, { 1488.18, 2148.47, 9.82 },
                        { 1104.70, 1648.06, 4.83 } } },
        },
        -- Levels (vanilla: items aboard and the time limit; ours: the quota of deliveries).
        levels = { { items = 6, quota = 4, timeMs = 180000 }, { items = 6, quota = 5, timeMs = 300000 },
                   { items = 7, quota = 6, timeMs = 300000 }, { items = 8, quota = 7, timeMs = 480000 } },
        sparePay = 100,            -- vanilla: payment = time left / 100 x level + $100 per item to spare
        packet = 2891, dropRadius = 3.0, outMs = 20000,
    },
}
