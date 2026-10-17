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
}
