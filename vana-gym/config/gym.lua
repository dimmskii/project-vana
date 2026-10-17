-- The gym: what each piece of equipment trains, and how much. Hand-written: edit freely.
-- Stats are 0-1000: 21 fat, 22 stamina, 23 muscle.
Gym = {
    machines = {
        bike = { lib = "GYMNASIUM", geton = "gym_bike_geton", loop = "gym_bike_pedal", fast = "gym_bike_fast",
                 getoff = "gym_bike_getoff", stat = 22, gain = 2, fat = -1, name = "Exercise bike" },
        treadmill = { lib = "GYMNASIUM", geton = "gym_tread_geton", loop = "gym_tread_jog", fast = "gym_tread_sprint",
                      getoff = "gym_tread_getoff", stat = 22, gain = 2, fat = -1, name = "Treadmill" },
        bench = { lib = "benchpress", geton = "gym_bp_geton", loop = "gym_bp_up_smooth", fast = "gym_bp_up_A",
                  getoff = "gym_bp_getoff", stat = 23, gain = 3, fat = -1, name = "Bench press" },
    },
    -- Where the player goes relative to the machine's position, and their heading relative to it.
    placement = { bike = { 0, 0, 1, 0 }, treadmill = { 0, 0, 1, 0 }, bench = { 0, 0, 1, 0 } },
    tapsPerRep = 8,          -- sprint-key taps to fill the bar for one rep
    minRepMs = 900,          -- a rep can't be quicker than this (checked on the server)
    maxGainPerHour = 60,     -- stat points one player can gain per real hour (vanilla caps a day's workout)
}
