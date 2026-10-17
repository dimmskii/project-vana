-- The race tournament (vanilla CPRACE): where races are entered, prizes and race rules. The races
-- themselves (checkpoints, cars) are seeded into config/races.lua.
Racing = {
    -- Entry points (vanilla's on-foot markers) and the races each offers.
    entries = {
        { x = 1766.13, y = -1704.23, z = 12.47, races = { 0, 1, 2, 3, 4, 5, 6, 7, 8 } },        -- Los Santos
        { x = -1922.92, y = 282.72, z = 40.04, races = { 9, 10, 11, 12, 13, 14 } },            -- San Fierro
        { x = 1636.92, y = 912.95, z = 9.69, races = { 15, 16, 17, 18 } },                     -- Las Venturas
        { x = 1701.69, y = 1649.19, z = 9.63, races = { 19, 20, 21, 22, 23, 24 } },            -- LV airport: air races
        { x = 2695.62, y = -1704.69, z = 10.84, races = { 25 } },                               -- LS stadium: 8-Track
        { x = 1099.55, y = 1601.50, z = 11.55, races = { 26 }, also = "kickstart" },            -- LV stadium: Dirt Track
    },
    names = { [25] = "STAD_03", [26] = "STAD_01" },
    interiors = { [25] = 7, [26] = 4 },
    -- First win pays (vanilla): $10000 a race, except these; every race won pays $1000000.
    prize = 10000, prizes = { [0] = 1000, [7] = 5000, [25] = 10000, [26] = 25000 }, allRaces = 1000000,
    -- The 8-Track's first win also parks vanilla's reward cars at the LS stadium.
    stadiumCars = { { model = 556, x = 2692.03, y = -1674.02, z = 9.47, rz = 178.8 }, { model = 494, x = 2676.70, y = -1673.76, z = 9.40, rz = 178.8 } },
    drivers = { 34, 60, 69, 96, 100, 101, 112, 121, 122, 123, 124, 133, 143, 170, 180, 181, 185, 188, 202, 222, 223, 227, 230, 233, 234, 235, 240, 241, 242, 247, 248, 250 },
    outMs = 10000,           -- vanilla: seconds to get back in before disqualification
    radius = 12, airRadius = 20,
    gridBack = 7, gridSide = 3, -- ours: grid rows and columns
    aiSpeed = 48,            -- ours: opponents' cruise speed
    -- Stadium events (vanilla KICKSTA, BLOOD).
    kickstart = {
        interior = 14, bike = 468, start = { -1472.38, 1563.58, 1051.42, 0 }, exit = { 1105.21, 1604.65, 12.05 },
        timeMs = 240000, payPerPoint = 100,       -- vanilla: score x $100
        -- Coronas: position and colour (1 green = 1 point, 2 amber = 2, 3 red = 3).
        coronas = {
            { -1376.44, 1562.29, 1059.0, 1 }, { -1354.84, 1585.2, 1057.89, 1 }, { -1408.02, 1568.74, 1055.84, 1 },
            { -1451.73, 1571.07, 1059.0, 2 }, { -1487.55, 1564.28, 1056.46, 2 }, { -1466.29, 1595.36, 1057.33, 3 },
            { -1387.6, 1572.13, 1053.93, 1 }, { -1362.58, 1614.62, 1055.33, 2 }, { -1359.51, 1638.22, 1056.03, 3 },
            { -1371.35, 1623.27, 1054.66, 2 }, { -1369.52, 1634.02, 1055.77, 3 }, { -1384.62, 1603.55, 1053.6, 1 },
            { -1399.0, 1603.27, 1055.16, 1 }, { -1403.91, 1645.16, 1071.46, 2 }, { -1443.39, 1648.55, 1054.29, 1 },
            { -1457.0, 1648.71, 1054.94, 1 }, { -1486.93, 1630.23, 1056.63, 1 }, { -1482.81, 1642.21, 1060.7, 3 },
            { -1484.81, 1597.12, 1061.38, 2 }, { -1431.4, 1598.06, 1054.75, 1 }, { -1420.68, 1598.27, 1054.96, 1 },
            { -1408.11, 1585.36, 1055.69, 1 }, { -1408.22, 1593.3, 1055.62, 1 }, { -1462.24, 1622.42, 1054.31, 2 },
            { -1461.74, 1635.75, 1054.01, 2 }, { -1453.89, 1636.03, 1056.18, 2 }, { -1454.06, 1628.6, 1054.3, 3 },
            { -1454.07, 1617.64, 1056.0, 3 }, { -1450.03, 1620.47, 1056.42, 3 }, { -1407.73, 1617.42, 1054.8, 2 },
            { -1414.16, 1607.16, 1054.84, 2 }, { -1388.31, 1620.99, 1054.95, 3 }, { -1431.09, 1580.83, 1055.76, 2 },
        },
    },
    bloodring = {
        entry = { x = -2120.04, y = -444.28, z = 34.53 }, interior = 15, car = 504, opponents = 11,
        startMs = 30000, perCheckpointMs = 15000, targetMs = 60000, targetStepMs = 60000, prize = 10000,
        player = { -1398.46, 995.64, 1024.46, 0 },
        grid = { { -1280.9, 994.8, 1037.0 }, { -1285.77, 1014.54, 1036.5 }, { -1299.5, 1030.74, 1036.8 }, { -1319.3, 1042.82, 1037.1 },
                 { -1349.33, 1054.47, 1037.3 }, { -1384.33, 1058.55, 1037.5 }, { -1296.7, 960.2, 1035.6 }, { -1418.77, 1057.54, 1037.5 },
                 { -1460.3, 1050.3, 1037.5 }, { -1499.77, 1029.54, 1037.2 }, { -1513.77, 986.54, 1036.5 } },
        -- Checkpoints fall at random on the arena floor (vanilla's box).
        area = { -1530, -1384, 923, 995, 1024.1 },
    },
}
