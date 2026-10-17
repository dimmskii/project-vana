-- What dead ambient peds leave behind. Hand-written: edit freely.
-- Vanilla drops each carried weapon, and cash from a ped's pocket money.
Drops = {
    lifetimeSeconds = 30,  -- uncollected pickups disappear after this
    maxAmmo = 60,          -- ammo in a dropped weapon pickup at most
    -- Cash by population kind: chance of dropping any, and the amount range.
    money = {
        civilian = { chance = 0.6, min = 1, max = 30 },
        gang     = { chance = 0.8, min = 10, max = 60 },
        dealer   = { chance = 1.0, min = 50, max = 250 },
        cop      = { chance = 0.5, min = 5, max = 40 },
    },
}
