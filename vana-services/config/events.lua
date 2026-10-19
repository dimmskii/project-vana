-- Random world events around players (ours: vanilla has the ingredients, not the scenes). Edit freely.
WorldEvents = {
    checkEveryMs = 30000,   -- each player gets a chance at an event this often...
    chance = 0.35,          -- ...with this probability
    maxActive = 4,          -- events running at once, server-wide
    distance = { 60, 150 }, -- events happen this far from the player, never closer than minToAnyone to anyone
    minToAnyone = 45,
    kindCooldownMs = 120000, -- the same kind of event at most this often per player
    lifetimeMs = 240000,    -- an event's leftovers (fires, chases) end after this

    -- How often each kind comes up.
    weights = { mugging = 3, carTheft = 2, shootout = 1, carFire = 1, streetFire = 1, collapse = 2, chase = 2 },

    mugging = { weapons = { 4, 5, 0 }, copRadius = 60 },  -- knife, bat or fists; cops this close step in
    carTheft = { searchRadius = 70, copRadius = 60 },
    shootout = { perSide = { 2, 3 }, apart = 16 },
    streetFire = { size = 3, rekindleMs = 20000 },        -- GTA fires burn out; kept going until hosed down
    collapse = { searchRadius = 60 },                     -- someone collapses: an ambulance always comes
    chase = {
        cars = { 402, 411, 415, 429, 451, 477, 480, 506, 541, 559, 560, 562, 565, 587, 589, 602, 603 },
        weapons = { 22, 28 },
        stopSpeed = 2, stopMs = 3000, -- the chased car counts as stopped below this speed for this long
        giveUp = 300,                 -- cops give up beyond this distance
        timeoutMs = 180000,
    },
}
