-- Vehicle registry, persistence and fuel settings.
VehicleConfig = {
    registrySize = 10,       -- each player's remembered cars, most recently used first
    saveIntervalMs = 30000,  -- remembered cars are saved this often (and on exit, quit and stop)
    dropRadius = 250,        -- a car no longer remembered goes once empty with no player this close

    -- Fuel, after gasoline.cs (a CLEO mod): a 30000-unit tank, burnt per frame at 25 fps by speed
    -- band (m/s) while a player drives; nothing standing still. Bicycles, boats, aircraft and trains
    -- don't use fuel.
    fuel = {
        enabled = true,
        tank = 30000,
        fps = 25,
        bands = { { 1, 45, 1 }, { 45, 85, 2 }, { 85, 110, 3 }, { 110, 140, 4 }, { 140, math.huge, 5 } },
        inAir = 1,
        low = 5000,                  -- the gauge turns red below this
        start = { 0.1, 1 },          -- a car first driven by a player has this share of a tank
        types = { Automobile = true, Bike = true, ["Monster Truck"] = true, Quad = true },
        -- Pumps: drive up to one (within 1.5 m, 3 m in height) with less than refillBelow in the tank.
        refillBelow = 29000, refillTo = 29700,
        step = 300, stepPrice = 1, stepMs = 40, -- $1 per 300 units: a full tank is about $100
        pumpRadius = 1.5, pumpHeight = 3, pumpSpeed = 3, -- m/s: rolling up to the pump, not driving past
        pumps = {
            { 1945.0, -1770.0, 13.01 }, { 2210.0, 2482.0, 10.82 }, { 604.9, 1705.0, 6.541 },
            { -2414.0, 982.1, 45.3 }, { -2245.0, -2562.0, 31.92 }, { -1328.0, 2678.0, 50.06 },
            { -95.15, -1174.0, 1.928 }, { -1680.0, 408.9, 7.236 }, { 652.0, -571.3, 16.34 },
            { -1606.0, -2714.0, 48.53 }, { -1471.0, 1864.0, 32.64 }, { 1596.0, 2199.0, 10.83 },
            { 2146.0, 2748.0, 10.83 }, { 2642.0, 1107.0, 10.83 }, { 2117.0, 920.4, 10.83 },
            { 1382.0, 456.3, 19.91 },
        },
    },

    -- Ambient cars (traffic, parked, random events) as they're made: tuneRandomly (tuning.lua).
    tuning = {
        -- Vanilla (CAutomobile's constructor): a model whose handling has HYDRAULIC_GEOM (0x10000:
        -- the lowriders) gets hydraulics one time in four.
        hydraulicGeom = 0.25,
        -- Ours: some taxis have nitro (after vanilla's "all taxis have nitro" cheat).
        taxis = { models = { [420] = true, [438] = true }, chance = 0.15, nitro = { 1009, 1008, 1010 } },
        -- Ours: tuned cars, by model group: the chance one is tuned, how many of its slots get a random
        -- part it fits (wheels, spoilers, skirts, bumpers... never nitro, hydraulics or the stereo),
        -- and the chance of a random paintjob where the model has them.
        tuned = {
            { models = { [558] = true, [559] = true, [560] = true, [561] = true, [562] = true, [565] = true }, -- street racers
              chance = 0.35, slots = { 2, 6 }, paintjob = 0.4 },
            { models = { [412] = true, [534] = true, [535] = true, [536] = true, [566] = true, [567] = true,
                         [575] = true, [576] = true }, -- lowriders
              chance = 0.3, slots = { 1, 4 }, paintjob = 0.4 },
            { chance = 0.03, slots = { 1, 1 }, wheelsOnly = true }, -- anything else: now and then, other wheels
        },
    },

    -- Paintjobs by model (the ones with paintjob textures): how many (setVehiclePaintjob 0..n-1).
    paintjobs = { [483] = 1, [534] = 3, [535] = 3, [536] = 3, [558] = 3, [559] = 3, [560] = 3, [561] = 3,
                  [562] = 3, [565] = 3, [567] = 3, [575] = 2, [576] = 3 },
}
