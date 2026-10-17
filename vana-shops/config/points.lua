-- Seeded by tools/seed/seed_interiors.py. Edit freely: this file is ours now.
-- Where a customer stands to shop, per shop interior (enex name). Found from a counter object where the
-- interior has one, else a few metres inside the door. Refine in game with /shoppoint <name>.
ShopPoints = {
    AMMUN1     = { kind = "weapons", interior = 1, x = 286.15, y = -36.64, z = 1000.57 }, -- 4 m inside the door (no counter found)
    AMMUN2     = { kind = "weapons", interior = 4, x = 292.04, y = -82.32, z = 1000.54 }, -- counter gun_counter09
    AMMUN3     = { kind = "weapons", interior = 6, x = 290.70, y = -104.03, z = 1000.57 }, -- counter mpgun_counter06
    AMMUN4     = { kind = "weapons", interior = 7, x = 315.82, y = -138.43, z = 998.66 }, -- 4 m inside the door (no counter found)
    AMMUN5     = { kind = "weapons", interior = 6, x = 316.52, y = -164.71, z = 998.66 }, -- 4 m inside the door (no counter found)
    FDCHICK    = { kind = "food", interior = 9, x = 367.84, y = -6.29, z = 1000.87 }, -- counter cj_ff_till
    FDPIZA     = { kind = "food", interior = 5, x = 372.93, y = -119.27, z = 1000.45 }, -- counter cj_ff_till
    FDBURG     = { kind = "food", interior = 10, x = 373.67, y = -66.68, z = 1000.55 }, -- counter cj_ff_till
    CSCHP      = { kind = "clothes", interior = 15, x = 207.74, y = -105.02, z = 1004.27 }, -- 4 m inside the door (no counter found)
    CSSPRT     = { kind = "clothes", interior = 3, x = 207.06, y = -134.81, z = 1002.52 }, -- 4 m inside the door (no counter found)
    LACS1      = { kind = "clothes", interior = 1, x = 203.80, y = -43.88, z = 1000.80 }, -- counter cj_urb_counter
    CLOTHGP    = { kind = "clothes", interior = 18, x = 161.36, y = -81.82, z = 1000.81 }, -- counter gap_counter
    CSDESGN    = { kind = "clothes", interior = 5, x = 206.93, y = -9.03, z = 1001.26 }, -- counter shop_counter_1
    CSEXL      = { kind = "clothes", interior = 14, x = 203.43, y = -159.90, z = 999.58 }, -- counter shop_counter_1
    X7_11B     = { kind = "misc", interior = 18, x = -30.95, y = -85.61, z = 1002.55 }, -- 4 m inside the door (no counter found)
    X7_11C     = { kind = "misc", interior = 16, x = -25.13, y = -135.07, z = 1002.55 }, -- 4 m inside the door (no counter found)
    X7_11D     = { kind = "misc", interior = 17, x = -25.88, y = -181.87, z = 1002.55 }, -- 4 m inside the door (no counter found)
    X7_11S     = { kind = "misc", interior = 6, x = -26.69, y = -51.71, z = 1002.55 }, -- 4 m inside the door (no counter found)
    X711S2     = { kind = "misc", interior = 4, x = -27.31, y = -25.28, z = 1002.55 }, -- 4 m inside the door (no counter found)
    X711S3     = { kind = "misc", interior = 10, x = 6.09, y = -25.27, z = 1002.55 }, -- 4 m inside the door (no counter found)
}
