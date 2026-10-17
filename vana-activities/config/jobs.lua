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
}
