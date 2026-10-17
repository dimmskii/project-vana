-- Seeded by tools/seed/seed_interiors.py. Edit freely: this file is ours now.
-- Where a customer stands to shop, per shop interior (enex name). Staffed shops use the vanilla shop
-- scripts' customer spot (see config/keepers.lua); the 24/7s start a few metres inside the door.
-- Refine in game with /shoppoint <name>.
ShopPoints = {
    AMMUN1     = { kind = "weapons", interior = 1, x = 296.51, y = -38.17, z = 1000.55 }, -- vanilla: at the counter
    AMMUN2     = { kind = "weapons", interior = 4, x = 295.74, y = -80.48, z = 1000.53 }, -- vanilla: at the counter
    AMMUN3     = { kind = "weapons", interior = 6, x = 290.24, y = -109.51, z = 1000.55 }, -- vanilla: at the counter
    AMMUN4     = { kind = "weapons", interior = 7, x = 308.15, y = -141.10, z = 998.62 }, -- vanilla: at the counter
    AMMUN5     = { kind = "weapons", interior = 6, x = 312.79, y = -165.95, z = 998.62 }, -- vanilla: at the counter
    FDCHICK    = { kind = "food", interior = 9, x = 368.79, y = -6.86, z = 1000.84 }, -- vanilla: at the till
    FDPIZA     = { kind = "food", interior = 5, x = 374.00, y = -119.64, z = 1000.54 }, -- vanilla: at the till
    FDBURG     = { kind = "food", interior = 10, x = 375.57, y = -68.22, z = 1000.55 }, -- vanilla: at the till
    CSCHP      = { kind = "clothes", interior = 15, x = 217.47, y = -98.19, z = 1004.29 }, -- vanilla: the changing room
    CSSPRT     = { kind = "clothes", interior = 3, x = 201.97, y = -131.41, z = 1002.51 }, -- vanilla: the changing room
    LACS1      = { kind = "clothes", interior = 1, x = 214.62, y = -40.65, z = 1001.03 }, -- vanilla: the changing room
    CLOTHGP    = { kind = "clothes", interior = 18, x = 181.42, y = -86.90, z = 1001.03 }, -- vanilla: the changing room
    CSDESGN    = { kind = "clothes", interior = 5, x = 208.82, y = -3.92, z = 1000.22 }, -- vanilla: the changing room
    CSEXL      = { kind = "clothes", interior = 14, x = 215.82, y = -155.18, z = 999.52 }, -- vanilla: the changing room
    X7_11B     = { kind = "misc", interior = 18, x = -30.95, y = -85.61, z = 1002.55 }, -- 4 m inside the door (no counter found)
    X7_11C     = { kind = "misc", interior = 16, x = -25.13, y = -135.07, z = 1002.55 }, -- 4 m inside the door (no counter found)
    X7_11D     = { kind = "misc", interior = 17, x = -25.88, y = -181.87, z = 1002.55 }, -- 4 m inside the door (no counter found)
    X7_11S     = { kind = "misc", interior = 6, x = -26.69, y = -51.71, z = 1002.55 }, -- 4 m inside the door (no counter found)
    X711S2     = { kind = "misc", interior = 4, x = -27.31, y = -25.28, z = 1002.55 }, -- 4 m inside the door (no counter found)
    X711S3     = { kind = "misc", interior = 10, x = 6.09, y = -25.27, z = 1002.55 }, -- 4 m inside the door (no counter found)
    -- Gym mats (from vana-gym's equipment): each teaches one fighting style.
    GYM1       = { kind = "fighting", style = 5, interior = 5, x = 767.14, y = 12.51, z = 999.70 }, -- Ganton: boxing (vanilla trainer spot)
    GYM2       = { kind = "fighting", style = 6, interior = 6, x = 769.79, y = -42.11, z = 999.69 }, -- Cobra (SF): kung fu (vanilla trainer spot)
    GYM3       = { kind = "fighting", style = 7, interior = 7, x = 763.36, y = -76.76, z = 999.66 }, -- Below the Belt (LV): kickboxing (vanilla trainer spot)
    -- Barbers and tattoo parlours: the customer's chair (vanilla BARB / TATTO, see config/keepers.lua).
    BARBERS    = { kind = "hair", interior = 2, x = 414.30, y = -19.90, z = 1000.81 },
    BARBER2    = { kind = "hair", interior = 3, x = 421.29, y = -81.30, z = 1000.81 },
    BARBER3    = { kind = "hair", interior = 12, x = 414.67, y = -51.32, z = 1000.81 },
    TATTOO     = { kind = "tattoo", interior = 16, x = -203.32, y = -25.33, z = 1001.28 },
    TATTO2     = { kind = "tattoo", interior = 17, x = -203.32, y = -7.06, z = 1001.28 },
    TATTO3     = { kind = "tattoo", interior = 3, x = -203.32, y = -42.38, z = 1001.28 },
}
