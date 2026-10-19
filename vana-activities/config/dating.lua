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
          meet = At("Dating.girls.1.meet", { interior = 0 }), -- met at home (vanilla: Burning Desire)
          home = At("Dating.girls.1.home"),
          likes = 15, selfRespect = 30, appeal = -100, traits = "slim", busy = { 6, 8, 10, 12, 14 },
          dates = { diner = true, restaurant = true, jumps = true, areas = true, beach = true, nightlife = true,
                    driveby = true, radio = 6 },
          car = At("Dating.girls.1.car", { model = 545, rz = 0.6, plate = "HOMEGIRL" }),
          gift = "pimp", reply = { yes = "GF_1C", no = "GF_1B" }, girlfriend = "GF_H000", keys = "GF_H007" },
        { key = "michelle", name = "Michelle", model = 192, stat = "GirlfriendMichelle",
          meet = At("Dating.girls.2.meet", { interior = 3 }), -- the San Fierro driving school
          home = At("Dating.girls.2.home"),
          likes = 0, selfRespect = 45, appeal = 60, traits = "fat", busy = { 12, 14, 16, 18, 20, 22 },
          dates = { restaurant = true, jumps = true, speed = true, areas = true, beach = true, nightlife = true,
                    radio = 6, drives = true },
          car = At("Dating.girls.2.car", { model = 557, rz = 91.9, plate = "__NOS___" }),
          gift = "mechanic", reply = { yes = "GF_1C", no = "GF_1B" }, girlfriend = "GF_H001", keys = "GF_H008",
          perk = "repair" },
        { key = "helena", name = "Helena", model = 191, stat = "GirlfriendHelena",
          meet = At("Dating.girls.3.meet", { interior = 0 }), -- outside the Blueberry Ammu-Nation
          home = At("Dating.girls.3.home"),
          likes = 0, selfRespect = 70, appeal = 70, traits = "slim", busy = { 2, 4, 6, 12 },
          dates = { fastfood = true, parking = true, moderate = true, urban = true, rural = true, radio = 7 },
          car = At("Dating.girls.3.car", { model = 568, rz = 88.9, plate = "FULLAUTO" }),
          gift = "country", reply = { yes = "GF_2C", no = "GF_2B" }, girlfriend = "GF_H002", keys = "GF_H009",
          perk = "stash" },
        { key = "barbara", name = "Barbara", model = 190, stat = "GirlfriendBarbara",
          meet = At("Dating.girls.4.meet", { interior = 0 }), -- El Quebrados
          home = At("Dating.girls.4.home"),
          likes = 0, selfRespect = 60, appeal = 45, traits = "fat", busy = { 6, 8, 10, 12, 14 },
          dates = { bar = true, moderate = true, rural = true, nightlife = true },
          car = At("Dating.girls.4.car", { model = 599, rz = 271.8, plate = "_CUFFS__" }),
          gift = "police", reply = { yes = "GF_3C", no = "GF_3B" }, girlfriend = "GF_H003", keys = "GF_H010",
          perk = "free_busted" },
        { key = "katie", name = "Katie", model = 193, stat = "GirlfriendKatie",
          meet = At("Dating.girls.5.meet", { interior = 0 }), -- the Avispa Country Club park
          home = At("Dating.girls.5.home"),
          likes = 0, selfRespect = 50, appeal = 50, traits = "muscle", busy = { 0, 2, 4, 6, 8, 10 },
          dates = { bar = true, moderate = true, nightlife = true, shopping = true, beach = true, crashes = true },
          car = At("Dating.girls.5.car", { model = 442, rz = 337.8, plate = "_TRAUMA_" }),
          gift = "medic", reply = { yes = "GF_4C", no = "GF_4B" }, girlfriend = "GF_H004", keys = "GF_H011",
          perk = "free_wasted" },
        { key = "millie", name = "Millie", model = 194, stat = "GirlfriendMillie",
          meet = At("Dating.girls.6.meet", { interior = 0 }), -- met at home (vanilla: Key To Her Heart)
          home = At("Dating.girls.6.home"),
          likes = 20, selfRespect = 45, appeal = 60, traits = "muscle", busy = { 22, 0, 2, 4, 6, 8, 10 },
          dates = { fastfood = true, restaurant = true, parking = true, moderate = true, urban = true,
                    shopping = true, nightlife = true, radio = 6, kinky = true },
          car = At("Dating.girls.6.car", { model = 589, rz = 269.0, plate = "_SPANK__" }),
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
        diner = Spots("Dating.venues.diner"),
        bar = Spots("Dating.venues.bar"),
        restaurant = Spots("Dating.venues.restaurant"),
        fastfood = Spots("Dating.venues.fastfood"),
        disco = Spots("Dating.venues.disco"),
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
    -- Dancing: the club rhythm game (games/rhythm_client.lua): beats and their spacing.
    dance = { beats = 16, beatMs = 900, goodShare = 0.6 },
    coffeeMs = 8000,            -- ours: the (censored) visit
    -- Her perks (vanilla help GF_H001-H004): Michelle fixes your car at her place; Helena keeps a stash
    -- of weapons for you (ours: what's in it); Barbara gets you out of jail free, Katie out of hospital.
    stash = { { 9, 1 }, { 18, 10 }, { 37, 500 } },
    repairRadius = 12,
    -- Gift outfit -> its special costume texture (for "wearing what she gave you").
    giftCostumes = { pimp = "pimptr", mechanic = "garageleg", country = "countrytr", police = "policetr", medic = "medictr", gimp = "gimpleg" },
}
