-- Mod garages (vanilla CARMOD): stop in a garage's doorway in a vehicle and it's taken inside for
-- upgrades, colours and paintjobs. Stock and prices are shopping.dat's (carmod1 normal cars, carmod2
-- lowriders, carmod3 street racers; CarMods prices); part IDs and the colour palette are seeded
-- (config/carmods_data.lua). Hand-written: edit freely.
GarageConfig = {
    -- Vanilla's doorways (the locate CARMOD stops you in, 4 m, just inside the garage door) and their
    -- garages: the game's garage (`door`: its index, from the map files' grge entries in load order,
    -- for setGarageOpen), the interior and spot the car goes to, and the heading it leaves facing. All
    -- open, doors up (vanilla unlocks the LS and SF ones through the story).
    garages = {
        { name = "Transfender", shop = "carmod1", x = 1042.0129, y = -1019.927, z = 31.127, exit = 0, door = 10,
          interior = 1, inside = { 617.536, -1.99, 999.98, 90 } },          -- Los Santos (Temple)
        { name = "Transfender", shop = "carmod1", x = -1935.528, y = 247.029, z = 33.561, exit = 0, door = 18,
          interior = 1, inside = { 617.536, -1.99, 999.98, 90 } },          -- San Fierro (Doherty)
        { name = "Transfender", shop = "carmod1", x = 2387.075, y = 1050.511, z = 9.812, exit = 0, door = 35,
          interior = 1, inside = { 617.536, -1.99, 999.98, 90 } },          -- Las Venturas (Come-A-Lot)
        { name = "Loco Low Co.", shop = "carmod2", x = 2645.1121, y = -2045.745, z = 12.607, exit = 180, door = 7,
          interior = 2, inside = { 616.783, -74.815, 997.014, 90 } },       -- Los Santos (Willowfield)
        { name = "Wheel Arch Angels", shop = "carmod3", x = -2723.845, y = 217.804, z = 3.585, exit = 90, door = 15,
          interior = 3, inside = { 615.286, -124.239, 996.995, 90 } },      -- San Fierro (Ocean Flats)
    },
    radius = 4,
    marker = { size = 3, colour = { 172, 203, 241, 90 } }, -- where to stop (vanilla draws a sphere there)
    stoppedSpeed = 0.05, -- m per frame-ish (MTA velocity units): "stopped" in the doorway

    -- Ours: every vehicle MTA can upgrade gets in, at any garage (vanilla turns away aircraft, boats,
    -- big and emergency vehicles, sends lowriders to Loco Low Co. and street racers to Wheel Arch
    -- Angels). Each garage shows its whole stock; parts the vehicle can't take are greyed out.
    vehicleTypes = { Automobile = true, ["Monster Truck"] = true, Quad = true },

    -- Ours: sold at every garage on top of its own stock, as MTA fits them to any car: all wheels,
    -- nitro, hydraulics, the stereo, and the spoilers MTA accepts on any car.
    everywhere = {
        "wheel_or1", "wheel_sr6", "wheel_sr3", "wheel_sr2", "wheel_lr4", "wheel_lr1", "wheel_lr3", "wheel_sr1",
        "wheel_sr5", "wheel_sr4", "wheel_gn1", "wheel_lr2", "wheel_gn2", "wheel_gn3", "wheel_gn4", "wheel_gn5",
        "wheel_lr5", "nto_b_s", "nto_b_l", "nto_b_tw", "hydralics", "stereo",
        "spl_b_mar_m", "spl_b_bab_m", "spl_b_bar_m", "spl_b_mab_m", "spl_b_bbr_m", "spl_b_bar_l", "spl_b_bbb_m",
        "spl_b_bbr_l", "spl_a_s_b", "spl_c_s_b", "spl_a_f_r", "spl_c_f_r", "spl_a_l_b", "spl_c_l_b",
        "spl_a_st_r", "spl_c_st_r", "spl_a_j_b", "spl_c_j_b", "spl_a_u_b", "spl_c_u_b",
    },

    -- Vanilla: a colour or a paintjob costs $150. (Which models have paintjobs: vana-vehicles.)
    paintPrice = 150,

    -- One customer per garage at a time: anyone else is told it's busy. Off: each customer gets their
    -- own copy of the garage (a dimension) and any number can be in at once.
    exclusive = true,
    busyText = "Somebody is already in the garage.",
    dimensionBase = 4000, -- customers' dimensions start here
}
