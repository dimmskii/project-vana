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
        -- The mod's 16 spots, exactly as its script checks them (mods/gasoline/gasoline.txt,
        -- locate_char_in_car_3d): where a car stands at the pump.
        pumps = {
            { 1944.8521, -1769.554, 13.0125 }, { 2209.8159, 2481.9341, 10.8203 }, { 604.8804, 1705.2729, 6.541 },
            { -2414.49, 982.081, 45.2969 }, { -2244.623, -2561.8279, 31.9219 }, { -1327.512, 2678.1069, 50.0625 },
            { -95.1488, -1174.303, 1.9281 }, { -1679.9821, 408.9051, 7.2365 }, { 652.03, -571.34, 16.34 },
            { -1605.897, -2714.252, 48.5335 }, { -1471.48, 1864.3101, 32.64 }, { 1596.5, 2199.1001, 10.83 },
            { 2145.8999, 2748.1599, 10.83 }, { 2642.1101, 1106.53, 10.83 }, { 2117.4199, 920.42, 10.83 },
            { 1381.6801, 456.26, 19.91 },
        },
        -- Each pump's marker, as the mod garages' and Pay 'n' Sprays' (vana-shops) but white, with the
        -- gas station icon standing in it (icons/radar_gasstn.png, pumps_client.lua).
        pumpMarker = { size = 4, colour = { 255, 255, 255, 90 }, icon = "icons/radar_gasstn.png" },
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
              chance = 0.35, slots = { 2, 6 }, paintjob = 0.4,
              -- and performance parts: the chance of each category, and the levels it's drawn from
              performance = { engine = { 0.6, 1, 2 }, turbo = { 0.12, 1, 1 }, tyres = { 0.3, 1, 2 }, brakes = { 0.2, 1, 1 } } },
            { models = { [412] = true, [534] = true, [535] = true, [536] = true, [566] = true, [567] = true,
                         [575] = true, [576] = true }, -- lowriders
              chance = 0.3, slots = { 1, 4 }, paintjob = 0.4 },
            { chance = 0.03, slots = { 1, 1 }, wheelsOnly = true }, -- anything else: now and then, other wheels
        },
    },

    -- Performance parts (ours; performance.lua): sold at the mod garages next to vanilla's parts, kept
    -- with the car (`vana:tune`: category -> level). A level's `mul` scales the model's own handling
    -- (getOriginalHandling), so every car stays itself, only better; `set` replaces a value. Levels in
    -- a category replace each other; categories stack (mass from armour and the lightweight kit
    -- multiply).
    performance = {
        order = { "engine", "turbo", "brakes", "suspension", "tyres", "armour", "lightweight", "drivetrain" },
        categories = {
            engine = { name = "Engine", levels = {
                { name = "Engine stage 1", price = 2500, mul = { engineAcceleration = 1.10, maxVelocity = 1.04, engineInertia = 0.95 } },
                { name = "Engine stage 2", price = 6000, mul = { engineAcceleration = 1.20, maxVelocity = 1.08, engineInertia = 0.90 } },
                { name = "Engine stage 3", price = 12000, mul = { engineAcceleration = 1.32, maxVelocity = 1.12, engineInertia = 0.85 } },
            } },
            turbo = { name = "Turbo", levels = {
                { name = "Turbo", price = 20000, mul = { engineAcceleration = 1.25, maxVelocity = 1.06 } },
            } },
            brakes = { name = "Brakes", levels = {
                { name = "Sport brakes", price = 2000, mul = { brakeDeceleration = 1.20 } },
                { name = "Race brakes (ABS)", price = 5000, mul = { brakeDeceleration = 1.40 }, set = { ABS = true } },
            } },
            suspension = { name = "Suspension", levels = {
                { name = "Sport suspension", price = 3000, mul = { suspensionForceLevel = 1.15, suspensionDamping = 1.25,
                  suspensionHighSpeedDamping = 1.2, suspensionAntiDiveMultiplier = 0.8 } },
                { name = "Race suspension", price = 7000, mul = { suspensionForceLevel = 1.3, suspensionDamping = 1.5,
                  suspensionHighSpeedDamping = 1.4, suspensionAntiDiveMultiplier = 0.6, steeringLock = 1.05 } },
            } },
            tyres = { name = "Tyres", levels = {
                { name = "Sport tyres", price = 2500, mul = { tractionMultiplier = 1.08, tractionLoss = 1.04 } },
                { name = "Race tyres", price = 6000, mul = { tractionMultiplier = 1.16, tractionLoss = 1.08 } },
            } },
            armour = { name = "Armour", levels = {
                { name = "Armour", price = 8000, mul = { collisionDamageMultiplier = 0.7, mass = 1.05 } },
                { name = "Heavy armour", price = 18000, mul = { collisionDamageMultiplier = 0.45, mass = 1.12, turnMass = 1.1 } },
            } },
            lightweight = { name = "Lightweight", levels = {
                { name = "Lightweight kit", price = 7000, mul = { mass = 0.88, turnMass = 0.9, dragCoeff = 0.95 } },
            } },
            drivetrain = { name = "Drivetrain", levels = {
                { name = "AWD conversion", price = 9000, set = { driveType = "awd" } },
            } },
        },
        -- The turbo's whine (turbo_client.lua): a looped game sound on top of the engine, pitched with
        -- speed and throttle. GENRL bank 131 is the vehicle generic bank (global 138); sound 10 is the
        -- Hydra's (Harrier's) front jet, 29 a generic whine. /turbosound auditions others.
        -- Off the throttle (experiment): a player's car fades to offThrottle (0: silent) over releaseMs
        -- and comes back within attackMs; a ped's (traffic: no controls to read) only drops to
        -- pedOffThrottle. Only with a driver in the car.
        whine = { bank = 131, sound = 10, volume = 0.4, range = 60, pitch = { 0.75, 1.6 },
                  offThrottle = 0, pedOffThrottle = 0.45, attackMs = 60, releaseMs = 125 },
    },

    -- Paintjobs by model (the ones with paintjob textures): how many (setVehiclePaintjob 0..n-1).
    paintjobs = { [483] = 1, [534] = 3, [535] = 3, [536] = 3, [558] = 3, [559] = 3, [560] = 3, [561] = 3,
                  [562] = 3, [565] = 3, [567] = 3, [575] = 2, [576] = 3 },
}
