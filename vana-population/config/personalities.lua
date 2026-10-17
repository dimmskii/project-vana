-- Personalities and encounters. A ped's personality is its model's pedstats.dat type (via
-- peds.ide), plus the random variance below. Hand-written: edit freely.
Personalities = {
    -- +/- spread applied per ped (fear, temper and lawfulness are 0-100).
    variance = { fear = 15, temper = 15, lawfulness = 10, attackStrength = 0.15 },

    -- Chance a civilian car carries a passenger (gang cars carry 1-3, cop cars 50% a partner).
    civilianPassengerChance = 0.15,

    -- What a car's occupants do when a player hits, kicks or shoots it (or them).
    -- Collision severity is the force divided by forcePerSeverity, 0-100; melee has a fixed severity,
    -- shots count as 100. Gang and cop crews fight back; civilians go by fear and temper.
    collision = {
        ignoreBelow = 15,          -- small bumps go unnoticed
        forcePerSeverity = 20,     -- collision force for one point of severity
        meleeSeverity = 40,        -- kicking or punching the car
        angerSeverity = 60,        -- a hard hit makes even milder tempers (fightTemper - 15) get out
        bailFear = 50,             -- shot at: fear at or above this bails out and runs, below panics and drives
        fleeFear = 60,             -- fear at or above this: drive off in a panic
        fightTemper = 55,          -- temper at or above this (and not fleeing): get out and fight
        jackTemper = 75,           -- temper at or above this may instead drag the player out of their car...
        jackChance = 0.35,         -- ...with this chance
        panicSeconds = 20,
    },

    -- Peds in an encounter: how long it lasts before they go back to walking.
    encounter = { fightSeconds = 25, fleeSeconds = 15, reactSeconds = 15, giveUpDistance = 80 },

    -- Gang members come to each other's aid within this distance.
    gangBackupRadius = 25,
}
