-- Dating (vanilla GFINIT / GFAGNT / GF_MEETING / GF_DATE / GF_SEX). Personalities, places, cars and
-- rewards are vanilla's; tuning marked "ours" is where vanilla's per-frame logic had to be condensed.
-- likes: vanilla's GF "likes player" (relationship progress, -100..100). selfRespect: she only warms to
-- you past this. appeal: desired sex appeal (0-100) to give you her number.
-- traits: what she likes in a body ("muscle", "fat" or "slim"). busy: even hours that start her busy
-- 2-hour blocks. dates: what she enjoys (vanilla's LikesOnDate bits: food places, cruising areas,
-- driving style, radio station...).
Dating = {
    girls = {
        { key = "denise", name = "Denise", model = 195, stat = "GirlfriendDenise",
          meet = { 2401.96, -1723.22, 12.60, 180, interior = 0 }, -- met at home (vanilla: Burning Desire)
          home = { 2401.96, -1723.22, 12.60, 180 },
          likes = 15, selfRespect = 30, appeal = -100, traits = "slim", busy = { 6, 8, 10, 12, 14 },
          dates = { diner = true, restaurant = true, jumps = true, areas = true, beach = true, nightlife = true,
                    driveby = true, radio = 6 },
          car = { model = 545, x = 2408.16, y = -1719.46, z = 13.67, rz = 0.6, plate = "HOMEGIRL" },
          gift = "pimp", reply = { yes = "GF_1C", no = "GF_1B" }, girlfriend = "GF_H000", keys = "GF_H007" },
        { key = "michelle", name = "Michelle", model = 192, stat = "GirlfriendMichelle",
          meet = { -2027.58, -118.70, 1034.0, 3.4, interior = 3 }, -- the San Fierro driving school
          home = { -1799.5, 1195.5, 24.11, 180 },
          likes = 0, selfRespect = 45, appeal = 60, traits = "fat", busy = { 12, 14, 16, 18, 20, 22 },
          dates = { restaurant = true, jumps = true, speed = true, areas = true, beach = true, nightlife = true,
                    radio = 6, drives = true },
          car = { model = 557, x = -1778.18, y = 1207.07, z = 25.12, rz = 91.9, plate = "__NOS___" },
          gift = "mechanic", reply = { yes = "GF_1C", no = "GF_1B" }, girlfriend = "GF_H001", keys = "GF_H008",
          perk = "repair" },
        { key = "helena", name = "Helena", model = 191, stat = "GirlfriendHelena",
          meet = { 257.67, -154.75, 4.08, 268.8, interior = 0 }, -- outside the Blueberry Ammu-Nation
          home = { -377.40, -1438.69, 24.72, 270 },
          likes = 0, selfRespect = 70, appeal = 70, traits = "slim", busy = { 2, 4, 6, 12 },
          dates = { fastfood = true, parking = true, moderate = true, urban = true, rural = true, radio = 7 },
          car = { model = 568, x = -379.5, y = -1443.12, z = 25.73, rz = 88.9, plate = "FULLAUTO" },
          gift = "country", reply = { yes = "GF_2C", no = "GF_2B" }, girlfriend = "GF_H002", keys = "GF_H009",
          perk = "stash" },
        { key = "barbara", name = "Barbara", model = 190, stat = "GirlfriendBarbara",
          meet = { -1410.10, 2648.73, 54.69, 130, interior = 0 }, -- El Quebrados
          home = { -1398.10, 2636.87, 54.70, 75 },
          likes = 0, selfRespect = 60, appeal = 45, traits = "fat", busy = { 6, 8, 10, 12, 14 },
          dates = { bar = true, moderate = true, rural = true, nightlife = true },
          car = { model = 599, x = -1399.72, y = 2628.59, z = 55.78, rz = 271.8, plate = "_CUFFS__" },
          gift = "police", reply = { yes = "GF_3C", no = "GF_3B" }, girlfriend = "GF_H003", keys = "GF_H010",
          perk = "free_busted" },
        { key = "katie", name = "Katie", model = 193, stat = "GirlfriendKatie",
          meet = { -2291.71, -233.02, 41.72, 360, interior = 0 }, -- the Avispa Country Club park
          home = { -2576.81, 1144.74, 54.74, 164 },
          likes = 0, selfRespect = 50, appeal = 50, traits = "muscle", busy = { 0, 2, 4, 6, 8, 10 },
          dates = { bar = true, moderate = true, nightlife = true, shopping = true, beach = true, crashes = true },
          car = { model = 442, x = -2572.04, y = 1148.56, z = 55.73, rz = 337.8, plate = "_TRAUMA_" },
          gift = "medic", reply = { yes = "GF_4C", no = "GF_4B" }, girlfriend = "GF_H004", keys = "GF_H011",
          perk = "free_wasted" },
        { key = "millie", name = "Millie", model = 194, stat = "GirlfriendMillie",
          meet = { 2035.36, 2732.41, 9.82, 0, interior = 0 }, -- met at home (vanilla: Key To Her Heart)
          home = { 2035.36, 2732.41, 9.82, 0 },
          likes = 20, selfRespect = 45, appeal = 60, traits = "muscle", busy = { 22, 0, 2, 4, 6, 8, 10 },
          dates = { fastfood = true, restaurant = true, parking = true, moderate = true, urban = true,
                    shopping = true, nightlife = true, radio = 6, kinky = true },
          car = { model = 589, x = 2028.45, y = 2731.10, z = 10.53, rz = 269.0, plate = "_SPANK__" },
          gift = "gimp", reply = { yes = "GF_1C", no = "GF_1B" }, keys = "GF_H012" }, -- no vanilla "girlfriend now" help: ours
    },
    -- Population zone types she enjoys cruising through (vanilla bits 15, 17-20).
    areas = {
        urban = { business = true, residential_rich = true, residential_average = true, residential_poor = true,
                  industry = true, residential_rich_secluded = true, out_of_town_factory = true, airport_runway = true },
        beach = { beach = true, park = true, golf_club = true },
        rural = { desert = true, countryside = true },
        shopping = { shopping = true, shopping_busy = true, shopping_posh = true },
        nightlife = { entertainment = true, entertainment_busy = true },
    },
    -- Date places (vanilla GF_DATE radar spots), by kind; fast food is any Cluckin' Bell, Burger Shot or
    -- Well Stacked Pizza door.
    venues = {
        diner = { { 2862, -1439, 10 }, { 384.66, -1819.53, 6.84 }, { -1699, 1380, 6 }, { -2524, 1216, 37 },
                  { 1376.89, 2327.79, 9.82 }, { 2368.06, 1983.19, 10.0 }, { 681.54, -473.49, 15.59 },
                  { -1941.52, 2379.67, 48.49 }, { -53.87, 1189.30, 18.41 } },
        bar = { { 2317, -1645, 13 }, { 1837, -1682, 14 }, { -2241, -88, 35 }, { -2551.12, 193.66, 5.2 },
                { 2441.15, 2065.15, 9.85 }, { 292.87, -195.47, 0.85 }, { -85.26, 1378.99, 9.28 } },
        restaurant = { { 415.39, -1431.02, 31.51 }, { -2463, 132, 34 }, { -1885, 747, 44 }, { 1693, 2208, 9.8 },
                       { 2490.67, 2065.15, 9.85 }, { -857.14, 1537.28, 21.59 } },
        fastfood = { { 172.73, 1176.68, 13.77 }, { -1213.71, 1830.46, 40.93 }, { -2155.03, -2460.28, 29.85 },
                     { 1367.27, 248.39, 18.62 }, { 2333.43, 75.05, 25.73 }, { 203.33, -202.53, 0.60 },
                     { 2105.32, -1806.49, 12.69 }, { 2419.95, -1509.80, 23.16 }, { 2397.83, -1898.65, 12.71 },
                     { 811.98, -1616.02, 12.62 }, { 1199.13, -918.07, 42.32 }, { 928.53, -1352.77, 12.43 },
                     { -1808.69, 945.86, 23.87 }, { -1721.13, 1359.01, 6.20 }, { -1912.27, 828.03, 34.56 },
                     { -1815.84, 618.68, 34.30 }, { -2671.53, 258.34, 3.65 }, { -2336.95, -166.65, 34.36 },
                     { -2356.48, 1008.01, 49.90 }, { 2638.58, 1671.18, 10.02 }, { 2638.58, 1849.97, 10.02 },
                     { 2366.74, 2071.02, 9.82 }, { 2393.18, 2041.66, 9.85 }, { 2472.68, 2033.88, 9.82 },
                     { 2756.01, 2477.05, 10.06 }, { 2838.43, 2407.26, 10.06 }, { 2351.89, 2532.19, 9.82 },
                     { 2169.86, 2795.79, 9.90 }, { 1872.24, 2072.07, 9.82 }, { 1158.43, 2072.02, 9.82 },
                     { 2083.49, 2224.20, 10.06 }, { 2102.69, 2228.76, 10.06 } },
        disco = { { 1837, -1682, 14 }, { -2551.12, 193.66, 5.2 }, { 2507.44, 1242.31, 9.83 } },
    },
    blips = { diner = 17, bar = 49, restaurant = 50, fastfood = 50, disco = 48, home = 21 },
    venueRadius = 8,           -- ours: stop this close to a place to go in
    pickupRadius = 10,         -- ours: stop your car this close to her door to pick her up
    abandonRadius = 70,        -- vanilla: leave her further than this and the date is over
    -- Liking changes (vanilla): a good date +5, a bad one -4, abandoning her -10; at -15 she dumps you.
    goodDate = 5, badDate = -4, abandoned = -10, dumped = -15,
    keysAt = 50, giftAt = 100, coffeeAt = 50, -- coffeeAt is ours (vanilla: her mood bits at the end)
    favouriteOutfitBonus = 25,  -- vanilla: wearing the outfit she gave you (country, police)
    -- Cruise "fun" meter (vanilla starts at 30 and ends the date at 0 or 100). Per second (ours: vanilla
    -- adds these per check): liked area +0.5 (after 30 s there), speed +1.5 / -2.5, moderate speed
    -- +0.5 / -2.5, jumps +1.5, crashes +1.5 / damage -1, her radio station +1.5, parked at night where
    -- she likes it +4, and boredom -0.4.
    fun = { start = 30, area = 0.5, speed = 1.5, slow = -2.5, moderate = 0.5, jump = 1.5, crash = 1.5, damage = -1,
            radio = 1.5, parking = 4, boredom = -0.4, fastSpeed = 22, moderateMin = 8, moderateMax = 20 },
    -- Dancing (ours until the DANCE minigame is ported): hit the shown direction in time.
    dance = { beats = 16, beatMs = 900, goodShare = 0.6 },
    coffeeMs = 8000,            -- ours: the (censored) visit
    -- Her perks (vanilla help GF_H001-H004): Michelle fixes your car at her place; Helena keeps a stash
    -- of weapons for you (ours: what's in it); Barbara gets you out of jail free, Katie out of hospital.
    stash = { { 9, 1 }, { 18, 10 }, { 37, 500 } },
    repairRadius = 12,
    -- Gift outfit -> its special costume texture (for "wearing what she gave you").
    giftCostumes = { pimp = "pimptr", mechanic = "garageleg", country = "countrytr", police = "policetr", medic = "medictr", gimp = "gimpleg" },
}
