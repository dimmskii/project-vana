-- Vehicle registry, persistence, fuel and radio settings.
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

    radio = {
        reportMs = 15000,     -- a station's leader re-reports its position this often (and on every new track)
        outsideRange = 25,    -- a running car's radio is heard this far away, muffled
        outsideVolume = 0.55,
        muffle = { fCenter = 1800, fBandwidth = 36, fGain = -15 }, -- the parameq effect on outside radio
    },
}
