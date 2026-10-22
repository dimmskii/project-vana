-- The trains that run (docs/trains.md). Speeds in m/s, times in ms, distances in m.
-- Vanilla runs freight trains and the Brown Streak on the mainland line and trams in San Fierro; the
-- numbers below are ours (vanilla spawns trains around the player instead of keeping a timetable).
TrainConfig = {
    -- Each service: how many trains, on which track (tracks_data.lua), which way (forward: the way rail
    -- distances grow), what they're made of, how fast, and whether they stop at the station stops.
    -- Every train of a track runs the same way, so none ever meets another head on.
    services = {
        freight = { setting = "freight", count = 2, track = 0, forward = true, cruise = 18, stops = false,
                    engine = 537, cars = { 569, 590 }, minCars = 3, maxCars = 6 },
        passenger = { setting = "passenger", count = 2, track = 0, forward = true, cruise = 22, stops = true,
                      engine = 538, cars = { 570 }, minCars = 2, maxCars = 3 },
        tram = { setting = "trams", count = 2, track = 1, forward = true, cruise = 11, stops = false,
                 engine = 449, cars = {}, minCars = 0, maxCars = 0 },
    },
    order = { "freight", "passenger", "tram" }, -- placing them: in this order, spread along each track

    accel = 0.5, decel = 0.8,  -- pulling away, braking for a stop or a train ahead
    emergencyDecel = 2,        -- the most it brakes when something appears closer than that
    dwell = 20000,             -- at a station stop
    gap = 60,                  -- kept to the train ahead, beyond its braking distance
    carSpacing = 20,           -- between carriage positions on the rail (the engine's figure for it)

    -- Elements only near players (dimension 0, outside interiors): made when a player is this close to
    -- any part of a train, removed once none is within despawn.
    spawnRange = 350, despawn = 500,
    ownerRadius = 300,         -- players eligible to simulate a train
    tick = 500,
    abandonedMs = 60000,       -- a train a player took and left: removed after this, once nobody is near

    drivers = { 27, 50, 153, 260 }, -- ours: workmen (WMYCON, WMYMECH, WMYCONB, BMYCON)
}
