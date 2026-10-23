-- Aircraft (docs/air.md). Times in ms, distances in m, speeds in m/s.
AirConfig = {
    -- Airliners between Los Santos, San Fierro and Las Venturas on vanilla's flight recordings. Ours:
    -- how many of each (the meta.xml settings). More planes than the airports have departure spots
    -- start in the air; the waiting spots are on the runways (the ATP mod's), so a busy airport keeps
    -- planes holding until there's room.
    fleet = {
        { setting = "at400", model = 577, count = 2 },     -- AT-400 (vanilla's ticket-desk plane)
        { setting = "andromada", model = 592, count = 2 },
        { setting = "shamal", model = 519, count = 2 },
        { setting = "nevada", model = 553, count = 2 },
    },
    wait = { 45000, 120000 },  -- at a departure spot before taking off (ours: boarding)
    spotRadius = 30,           -- a spot is crossed by anything rolling this close to it
    margin = 10000,            -- added either side of every runway and spot window
    -- A plane asks to land `join` ms before touchdown; refused, it flies a holding circle there and asks
    -- again each lap, at its own level over that runway: holdStack m higher and holdWiden m wider than
    -- the one below.
    join = 75000, holdRadius = 600, holdSpeed = 55, holdStack = 60, holdWiden = 300,
    pilot = 61,                -- WMYPLT, as the ATP mod (vanilla's ticket desk has no pilot)

    -- Elements only near players (dimension 0, outside interiors).
    spawnRange = 600, despawn = 800, ownerRadius = 600,
    tick = 500,
    abandonedMs = 60000,       -- a plane a player took and left, removed after this once nobody is near

    -- News helicopters (ours): one per city by day, circling one of its heli spots for a while.
    news = { model = 488, perCity = 1, hours = { 7, 22 }, onAir = { 480000, 900000 }, offAir = { 600000, 1200000 },
             speed = 18, crew = { 61, 61 } },
    -- Helicopters passing now and then (ours): checked every `every` for each player, one at a time
    -- around a player. Weights by model.
    ambient = { every = 60000, chance = 0.15, models = { [487] = 50, [469] = 25, [563] = 15, [417] = 10 },
                speed = 35, distance = 900, height = { 110, 180 } },
    -- Airliners passing high overhead, as vanilla's (CPlane::DoPlaneGenerationAndRemoval), none in its
    -- no-plane zones, no big ones in its no-big-plane zones (CPlane::AreWeInNoPlaneZone,
    -- AreWeInNoBigPlaneZone; gta-reversed). The rest is ours.
    overflights = { every = 90000, chance = 0.12, big = { 577, 592 }, small = { 519, 553 },
                    height = { 300, 550 }, speed = 70, distance = 1800 },
    noPlaneZones = { circles = { { -1073, -675, 200 } },
                     boxes = { { -2743, 1300, -2626, 2200 }, { -1668, 541, -1122, 1118 } } },
    noBigPlaneZones = { { 1522, -1237, 800 }, { -1836, 659, 800 } },
}
