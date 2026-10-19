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
        hospitals = Spots("Jobs.paramedic.hospitals"),
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
            At("Jobs.freight.stations.1", { forward = 150000, back = 60000 }),  -- Unity Station, LS
            At("Jobs.freight.stations.2", { forward = 60000, back = 140000 }),   -- Market Station, LS
            At("Jobs.freight.stations.3", { forward = 140000, back = 150000 }),  -- Cranberry Station, SF
            At("Jobs.freight.stations.4", { forward = 150000, back = 105000 }),   -- Yellow Bell Station, LV
            At("Jobs.freight.stations.5", { forward = 105000, back = 150000 }),   -- Linden Station, LV
        },
        extraMs = { 15000, 10000 }, -- per leg, by level
        levelBonus = { 10000, 50000 },
        radius = 10, outMs = 10000,
    },
    trucking = {
        start = At("Jobs.trucking.start"),       -- RS Haul, Flint County: enter/exit on the marker
        truckSpot = At("Jobs.trucking.truckSpot"), trailerSpot = At("Jobs.trucking.trailerSpot"),
        trucks = { 514, 403, 515 }, trailers = { 584, 435, 450, 591 },
        -- Vanilla's drop-offs.
        destinations = Spots("Jobs.trucking.destinations"),
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
        income = { pickup = At("Jobs.trucking.income.pickup"), perDay = 2000, cap = 2000 },
        dropRadius = 8,
    },
    quarry = {
        start = At("Jobs.quarry.start"),   -- the site office
        pay = { 500, 1000, 2000, 3000, 5000, 7500, 10000 },
        dozer = 486, dumper = 406, copBike = 523,
        entrance = At("Jobs.quarry.entrance"), depot = At("Jobs.quarry.depot"),
        -- 1: the cop's body and bike, pushed to the crane's pick-up area. Vanilla then has you work the
        -- crane to load the dumper; MTA has no crane controls, so the load goes aboard when both are there.
        cop = { body = At("Jobs.quarry.cop.body"), bike = At("Jobs.quarry.cop.bike"), dozer = At("Jobs.quarry.cop.dozer"),
                dumper = At("Jobs.quarry.cop.dumper"), pickup = At("Jobs.quarry.cop.pickup"), water = At("Jobs.quarry.cop.water"),
                timeMs = 420000 },
        -- 2: rocks over the edge into their markers.
        rocks = { timeMs = 480000, items = {
            At("Jobs.quarry.rocks.items.1", { target = At("Jobs.quarry.rocks.items.1.target") }), At("Jobs.quarry.rocks.items.2", { target = At("Jobs.quarry.rocks.items.2.target") }),
            At("Jobs.quarry.rocks.items.3", { target = At("Jobs.quarry.rocks.items.3.target") }), At("Jobs.quarry.rocks.items.4", { target = At("Jobs.quarry.rocks.items.4.target") }),
            At("Jobs.quarry.rocks.items.5", { target = At("Jobs.quarry.rocks.items.5.target") }), At("Jobs.quarry.rocks.items.6", { target = At("Jobs.quarry.rocks.items.6.target") }),
            At("Jobs.quarry.rocks.items.7", { target = At("Jobs.quarry.rocks.items.7.target") }) } },
        -- 3: bombs to their safe areas, one at a time, each against its own clock.
        bombs = { perBombMs = 90000, items = {
            At("Jobs.quarry.bombs.items.1", { target = At("Jobs.quarry.bombs.items.1.target"), line = "QUAR_16" }),
            At("Jobs.quarry.bombs.items.2", { target = At("Jobs.quarry.bombs.items.2.target"), line = "QUAR_17" }),
            At("Jobs.quarry.bombs.items.3", { target = At("Jobs.quarry.bombs.items.3.target"), line = "QUAR_18" }),
            At("Jobs.quarry.bombs.items.4", { target = At("Jobs.quarry.bombs.items.4.target"), line = "QUAR_34" }) } },
        -- 4: the bombers' bodies on a dumper at the other entrance, burned on the quarry floor.
        bodies = { dumper = At("Jobs.quarry.bodies.dumper"), fire = At("Jobs.quarry.bodies.fire"), timeMs = 360000 },
        -- 5: explosives to the desert airstrip and back, gently.
        explosives = { airstrip = At("Jobs.quarry.explosives.airstrip"), timeMs = 600000, jolt = 60 },
        -- 6: explosives spilled along the tracks, pushed clear before the train.
        tracks = { timeMs = 240000, clear = 4, items = Spots("Jobs.quarry.tracks.items") },
        -- 7: thieves escaping in a dumper: wreck it.
        thieves = { dumper = At("Jobs.quarry.thieves.dumper"), warn = 400, lose = 650 },
        -- The reward (vanilla car generators): a dumper and a bulldozer always at the quarry.
        reward = { { 406, 687.37, 890.67, -40.43, 35.1 }, { 486, 620.88, 861.25, -43.95, 298.7 } },
        models = { rock = 1303, barrel = 3046, body = 3092, crate = 3014, ammo = 3013 },
    },
    courier = {
        -- Per city: the bike, the pick-up point (start marker and where you're paid) and vanilla's drop-offs.
        cities = {
            { name = "BCOU_18", bike = 481, base = At("Jobs.courier.cities.1.base"), back = At("Jobs.courier.cities.1.back"),
              drops = Spots("Jobs.courier.cities.1.drops") },
            { name = "BCOU_20", bike = 463, base = At("Jobs.courier.cities.2.base"), back = At("Jobs.courier.cities.2.back"),
              drops = Spots("Jobs.courier.cities.2.drops") },
            { name = "BCOU_19", bike = 462, base = At("Jobs.courier.cities.3.base"), back = At("Jobs.courier.cities.3.back"),
              drops = Spots("Jobs.courier.cities.3.drops") },
        },
        -- Levels (vanilla: items aboard and the time limit; ours: the quota of deliveries).
        levels = { { items = 6, quota = 4, timeMs = 180000 }, { items = 6, quota = 5, timeMs = 300000 },
                   { items = 7, quota = 6, timeMs = 300000 }, { items = 8, quota = 7, timeMs = 480000 } },
        sparePay = 100,            -- vanilla: payment = time left / 100 x level + $100 per item to spare
        packet = 2891, dropRadius = 3.0, outMs = 20000,
    },
}
