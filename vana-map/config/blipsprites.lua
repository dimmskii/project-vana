-- MTA's blip icons (0-63) and the radar sprites in hud.txd (data/hud.txd, copied at setup) that the
-- map (F11, mapview_client.lua) draws for them. 0 and 1 are plain squares (drawn in the blip's colour);
-- 3 (map_here) has no sprite in hud.txd and is drawn as one too.
BlipSprites = {
    [2] = "radar_centre", [4] = "radar_north", [5] = "radar_airyard", [6] = "radar_ammugun", [7] = "radar_barbers",
    [8] = "radar_bigsmoke", [9] = "radar_boatyard", [10] = "radar_burgershot", [11] = "radar_bulldozer",
    [12] = "radar_catalinapink", [13] = "radar_cesarviapando", [14] = "radar_chicken", [15] = "radar_cj",
    [16] = "radar_crash1", [17] = "radar_diner", [18] = "radar_emmetgun", [19] = "radar_enemyattack", [20] = "radar_fire",
    [21] = "radar_girlfriend", [22] = "radar_hostpital", [23] = "radar_locosyndicate", [24] = "radar_maddog",
    [25] = "radar_mafiacasino", [26] = "radar_mcstrap", [27] = "radar_modgarage", [28] = "radar_ogloc", [29] = "radar_pizza",
    [30] = "radar_police", [31] = "radar_propertyg", [32] = "radar_propertyr", [33] = "radar_race", [34] = "radar_ryder",
    [35] = "radar_savegame", [36] = "radar_school", [37] = "radar_qmark", [38] = "radar_sweet", [39] = "radar_tattoo",
    [40] = "radar_thetruth", [41] = "radar_waypoint", [42] = "radar_torenoranch", [43] = "radar_triads",
    [44] = "radar_triadscasino", [45] = "radar_tshirt", [46] = "radar_woozie", [47] = "radar_zero", [48] = "radar_datedisco",
    [49] = "radar_datedrink", [50] = "radar_datefood", [51] = "radar_truck", [52] = "radar_cash", [53] = "radar_flag",
    [54] = "radar_gym", [55] = "radar_impound", [56] = "radar_light", [57] = "radar_runway", [58] = "radar_gangb",
    [59] = "radar_gangp", [60] = "radar_gangy", [61] = "radar_gangn", [62] = "radar_gangg", [63] = "radar_spray",
}
