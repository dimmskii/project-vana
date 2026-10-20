-- Shopkeepers and where customers are served, from the vanilla shop scripts in main.scm (BARB, TATTO,
-- AMUNAT, JFUD, CLOTH).
-- Each shop type has one layout in interior coordinates; each shop moves it by its offset. Points are
-- { x, y, z, heading } with ground z, as in the scripts. Cameras are { x, y, z, lookX, lookY, lookZ }.
KeeperLayouts = {
    hair = {
        keeper = { 414.273, -18.002, 1000.86, 180 },
        customer = { 414.3, -19.9, 1000.806, 90 },
        camera = { 412.649, -19.7078, 1001.9915, 413.3581, -19.0046, 1002.0428 },
        -- Styles that get the beard-checking animation instead of a hair one.
        beards = { TASH = true, GOATEE = true, BEARD = true, AFROT = true, AFROB = true, AFROGOT = true,
                   BLADBEA = true, BALDTSH = true, BALDGOT = true },
    },
    tattoo = {
        keeper = { -201.668, -6.217, 1001.28, 155 },
        customer = { -203.318, -7.062, 1001.28, 125 },
        camera = { -203.2045, -5.3316, 1002.4316, -202.2993, -5.7376, 1002.3063 },
        kit = { model = 3126, z = 1.0 }, -- TATTOO_KIT above the artist's stool (vanilla animates it; we can't yet)
        -- Body part (clothes slot) -> pose animation group for the customer and the artist.
        parts = { [4] = { "ArmL", "ArmL" }, [5] = { "ArmL", "ArmL" }, [6] = { "ArmR", "ArmR" }, [7] = { "ArmR", "ArmR" },
                  [8] = { "Back", "Back" }, [9] = { "Che", "Che" }, [10] = { "Che", "Che" }, [11] = { "Che", "Bel" },
                  [12] = { "Back", "Back" } },
    },
    weapons = {
        keeper = { 296.506, -40.35, 1000.54, 0 },
        customer = { 296.506, -38.168, 1000.547, 180 },
        camera = { 296.585, -38.345, 1002.236, 296.501, -39.298, 1001.943 },
        -- Weapon ID (or "armour") -> the model the clerk lifts, and vanilla's lift animation group for
        -- it (SHP_<group>_Lift); anything not listed is one-handed.
        models = { [22] = 346, [23] = 347, [24] = 348, [16] = 342, [25] = 349, [27] = 351, [26] = 350, [28] = 352,
                   [32] = 372, [29] = 353, [30] = 355, [31] = 356, [33] = 357, [34] = 358, [35] = 359, [36] = 360,
                   [37] = 361, [38] = 362, [39] = 363, armour = 373 },
        lifts = { [349] = "2H", [350] = "2H", [351] = "2H", [355] = "2H", [356] = "2H", [357] = "2H", [358] = "2H", [373] = "Ar" },
    },
    food = {
        keeper = { 374.0, -117.141, 1000.539, 180 },
        customer = { 374.0, -119.641, 1000.539, 0 }, -- 2.5 m in front of the keeper
        camera = { 374.0, -119.1869, 1002.019, 373.9532, -118.189, 1001.9753 },
        -- Food item -> the meal model the server lifts on its tray.
        models = { burgerhigh = 2212, burgerlow = 2213, burgermed = 2214, burger_healthy = 2354,
                   clucklow = 2215, cluckmed = 2216, cluckhigh = 2217, cluck_healthy = 2353,
                   pizzalow = 2218, pizzamed = 2219, pizzahigh = 2220, pizza_healthy = 2355 },
    },
    clothes = {
        customer = { 214.622, -40.652, 1001.033, 90 }, -- in front of the changing room
        camera = { 212.8715, -42.8156, 1002.1159, 213.4791, -42.0238, 1002.0531 },
        hatCamera = { 214.5148, -41.6106, 1002.4937, 214.5367, -40.6175, 1002.6089 },
        hatCategories = { [15] = true, [16] = true },
        door = { 213.874, -39.811, 1002.2, 0 }, -- the changing room door (vanilla animates it; we hide it as CJ passes)
        -- Apparel category -> CLO_Pose_<pose>.
        poses = { [0] = "Torso", [2] = "Legs", [3] = "Shoes", [13] = "Torso", [14] = "Watch", [15] = "Hat", [16] = "Hat" },
    },
    -- Ours: 24/7 counters. Each shop gives its own keeper point (the stores' counters differ); you
    -- shop standing, so there's no customer seat or camera.
    convenience = {},
}

-- 24/7 clerks (ours), by where the store is: the locals you see on its streets. A store's `models`
-- is one of these (or its own list); one is picked each time a clerk is spawned.
ClerkModels = {
    city = { 229 },                 -- SOMOST
    country = { 158, 161, 196, 198 }, -- CWMOFR, CWMYFR, CWFOFR, CWFYFR1: the farmers you see out of town
}

-- Shops with staff: layout, keeper model (vanilla's) and the shop's offset from the layout. A `keeper`
-- point here replaces the layout's (clothes clerks stand at each chain's own counter).
Keepers = {
    BARBERS = { layout = "hair", model = 156, offset = { 0, 0, 0 } },
    BARBER2 = { layout = "hair", model = 177, offset = { 6.987, -61.401, 0 } },
    BARBER3 = { layout = "hair", model = 176, offset = { 0.371, -31.421, 0 } },
    TATTOO = { layout = "tattoo", model = 180, offset = { 0, -18.266, 0 } },
    TATTO2 = { layout = "tattoo", model = 180, offset = { 0, 0, 0 } },
    TATTO3 = { layout = "tattoo", model = 180, offset = { 0, -35.32, 0 } },
    AMMUN1 = { layout = "weapons", model = 179, offset = { 0, 0, 0 } },
    AMMUN2 = { layout = "weapons", model = 179, offset = { -0.765, -42.311, -0.013 } },
    AMMUN3 = { layout = "weapons", model = 179, offset = { -6.264, -71.34, -0.002 } },
    AMMUN4 = { layout = "weapons", model = 179, offset = { 11.642, -102.936, -1.929 } },
    AMMUN5 = { layout = "weapons", model = 179, offset = { 16.285, -127.781, -1.929 } },
    FDPIZA = { layout = "food", model = 155, offset = { 0, 0, 0 }, eat = "EAT_Pizza" },
    FDCHICK = { layout = "food", model = 167, offset = { -5.211, 112.784, 0.3 }, eat = "EAT_Chicken" },
    FDBURG = { layout = "food", model = 205, offset = { 1.566, 51.419, 0.01 }, eat = "EAT_Burger" },
    LACS1 = { layout = "clothes", model = 211, offset = { 0, 0, 0 }, keeper = { 203.528, -41.644, 1000.852, 180 }, door = 2873 },
    CSCHP = { layout = "clothes", model = 211, offset = { 2.85, -57.534, 3.26 }, keeper = { 208.806, -98.713, 1004.297, 180 }, door = 2877 },
    CSSPRT = { layout = "clothes", model = 217, offset = { -12.653, -90.758, 1.477 }, keeper = { 207.018, -127.782, 1002.555, 180 }, door = 2876 },
    CLOTHGP = { layout = "clothes", model = 211, offset = { -33.204, -46.245, 0 }, keeper = { 161.56, -81.369, 1000.859, 180 }, door = 2875 },
    CSDESGN = { layout = "clothes", model = 211, offset = { -5.806, 36.733, -0.815 }, keeper = { 204.836, -7.328, 1000.258, 270 }, door = 2878 },
    -- 24/7s (ours): the clerk's point is where the store's counter is (in-game positions). X711I1 and
    -- X711I2 are Idlewood copies of the Vinewood store (X711S2) in dimensions of their own; X711FC
    -- (Fort Carson) and X711AP (Angel Pine) country copies of X7_11S (Commerce and LV).
    X711S2 = { layout = "convenience", models = ClerkModels.city, keeper = { -30.54, -30.78, 1002.56, 8 } },
    X7_11B = { layout = "convenience", models = ClerkModels.city, keeper = { -28.19, -91.64, 1002.55, 5 } },
    X711I1 = { layout = "convenience", models = ClerkModels.city, keeper = { -30.54, -30.78, 1002.56, 8 } },
    X711I2 = { layout = "convenience", models = ClerkModels.city, keeper = { -30.54, -30.78, 1002.56, 8 } },
    X7_11S = { layout = "convenience", models = ClerkModels.city, keeper = { -23.67, -57.31, 1002.55, 359 } },
    X711FC = { layout = "convenience", models = ClerkModels.country, keeper = { -23.67, -57.31, 1002.55, 359 } },
    X711AP = { layout = "convenience", models = ClerkModels.country, keeper = { -23.67, -57.31, 1002.55, 359 } },
    CSEXL = { layout = "clothes", model = 217, offset = { 1.2, -114.524, -1.51 }, keeper = { 204.366, -157.789, 999.563, 180 }, door = 2879 },
}
