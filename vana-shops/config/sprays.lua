-- Pay 'n' Spray (vanilla's respray garages, the map files' grge entries of type 5): drive in, stop, and
-- the door closes, the car is fixed, the door opens. Ours: it only repairs (no new colour, no change
-- to your wanted level), and only when there's something to fix. Hand-written: edit freely.
SprayConfig = {
    price = 100,          -- vanilla's
    stoppedSpeed = 0.05,  -- MTA velocity units: "stopped" inside
    closeMs = 1500,       -- the door coming down before the spray
    sprayMs = 2500,       -- the spray (vanilla's respray sound) before the door goes up again
    -- The garages: `door` is the game's garage index (setGarageOpen); the box is the grge one: a
    -- corner, its two sides (a, b) and the roof height.
    garages = {
        { door = 8, name = "Idlewood, LS", corner = { 2056.60, -1835.90, 12.54 }, a = { 14.70, 0.00 }, b = { 0.00, 8.93 }, top = 18.54 },
        { door = 11, name = "Temple, LS", corner = { 1021.81, -1018.71, 30.91 }, a = { 0.00, -10.82 }, b = { 6.12, 0.00 }, top = 36.91 },
        { door = 12, name = "Santa Maria Beach, LS", corner = { 491.10, -1747.55, 9.46 }, a = { 1.61, 11.78 }, b = { -9.13, 1.25 }, top = 17.57 },
        { door = 19, name = "Downtown, SF", corner = { -1908.93, 292.35, 40.04 }, a = { 0.00, -14.36 }, b = { 8.82, 0.00 }, top = 45.54 },
        { door = 29, name = "Juniper Hollow, SF", corner = { -2430.13, 1013.71, 49.34 }, a = { 8.93, 0.00 }, b = { 0.00, 14.05 }, top = 55.34 },
        { door = 34, name = "Old Venturas Strip, LV", corner = { 2389.60, 1483.26, 9.82 }, a = { 8.51, 0.00 }, b = { 0.00, 14.58 }, top = 15.68 },
        { door = 38, name = "Redsands East, LV", corner = { 1968.23, 2157.88, 9.60 }, a = { 15.09, 0.00 }, b = { 0.00, 9.15 }, top = 16.24 },
        { door = 42, name = "El Quebrados", corner = { -1424.11, 2576.61, 54.82 }, a = { 7.26, 0.00 }, b = { 0.00, 14.23 }, top = 60.87 },
        { door = 43, name = "Fort Carson", corner = { -103.64, 1112.42, 18.70 }, a = { 7.27, 0.00 }, b = { 0.00, 13.37 }, top = 24.55 },
        { door = 49, name = "Dillimore", corner = { 715.81, -462.40, 14.96 }, a = { 8.49, 0.00 }, b = { 0.00, 15.11 }, top = 21.44 },
    },
    repairedText = "Repaired: $%d",
    nothingText = "Nothing to fix.",
}
