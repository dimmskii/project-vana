-- The gym: what each piece of equipment trains, and how much. Hand-written: edit freely.
-- Stats are 0-1000: 21 fat, 22 stamina, 23 muscle. Animation lengths (ms) are the retail IFPs'.
Gym = {
    machines = {
        bike = { lib = "GYMNASIUM", geton = "gym_bike_geton", loop = "gym_bike_pedal", fast = "gym_bike_fast",
                 getoff = "gym_bike_getoff", getonMs = 1670, getoffMs = 1670, repMs = 400,
                 stat = 22, statName = "Stamina", gain = 2, fat = -1, name = "Exercise bike" },
        treadmill = { lib = "GYMNASIUM", geton = "gym_tread_geton", loop = "gym_tread_jog", fast = "gym_tread_sprint",
                      getoff = "gym_tread_getoff", getonMs = 2500, getoffMs = 3330, repMs = 670,
                      stat = 22, statName = "Stamina", gain = 2, fat = -1, name = "Treadmill" },
        bench = { lib = "benchpress", geton = "gym_bp_geton", loop = "gym_bp_up_smooth", fast = "gym_bp_up_A",
                  getoff = "gym_bp_getoff", getonMs = 5330, getoffMs = 8670, repMs = 2330,
                  stat = 23, statName = "Muscle", gain = 3, fat = -1, name = "Bench press" },
        -- Vanilla's free weights (GYMDUMB) are the brain on the gym mats.
        mat = { lib = "freeweights", geton = "gym_free_pickup", loop = "gym_free_loop", fast = "gym_free_up_smooth",
                getoff = "gym_free_putdown", getonMs = 3170, getoffMs = 3170, repMs = 1000,
                stat = 23, statName = "Muscle", gain = 2, fat = -1, name = "Dumbbells" },
    },
    -- Where the player stands to get on, relative to the machine (right, forward, up, heading). The get-on
    -- animation carries the root by its inverse onto the machine (measured from the IFPs).
    placement = { bike = { -0.5, 0.034, 1, 0 }, treadmill = { 0.006, -1.575, 1, 0 }, bench = { -0.012, -0.765, 1, 0 },
                  mat = { -0.004, -0.343, 1, 0 } },
    -- Props, as the vanilla gym scripts place them. offset/rest: right, forward, up from the machine, then the
    -- attach rotation (degrees). bone/hold: the hand that carries it and the offset in the bone's frame, between
    -- pickup (fraction of the get-on) and putdown (fraction of the get-off). spin: seconds per turn while in use.
    props = {
        bike = { { model = 3133, rest = { 0, -0.05, 0.15, 0, 0, 0 }, spin = 0.43 } },  -- pedals
        bench = { { model = 2913, rest = { -0.45, 0.45, 0.9, 90, 180, 270 }, bone = 25, hold = { 0, 0, -0.1 }, pickup = 0.75, putdown = 0.26 } },
        mat = {
            { model = 3071, rest = { 0.05, 0.2, 0.3, 0, 90, 90 }, bone = 25, hold = { 0, 0, 0 }, pickup = 0.7789, putdown = 0.3 },
            { model = 3072, rest = { 0.05, -0.2, 0.3, 0, 90, 90 }, bone = 35, hold = { 0, 0, 0 }, pickup = 0.7789, putdown = 0.3 },
        },
    },
    tapsPerRep = 8,          -- sprint-key taps to fill the bar for one rep
    minRepMs = 900,          -- a rep can't be quicker than this (checked on the server)
    maxGainPerHour = 60,     -- stat points one player can gain per real hour (vanilla caps a day's workout)
}
