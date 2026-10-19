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

    -- Every player counts as a member of this gang (vanilla CJ: Grove Street). Its members defend
    -- players attacked near them and help in fights with rival gangs; rivals start fights.
    playerGang = "grove",
    -- Who is hostile to whom (vanilla: Grove against Ballas and Vagos, Vagos against the Aztecas,
    -- the San Fierro Triads against the Da Nang Boys; the Rifa side with no one).
    rivals = {
        grove = { ballas = true, vagos = true },
        ballas = { grove = true, vagos = true },
        vagos = { grove = true, ballas = true, aztecas = true },
        aztecas = { vagos = true },
        triad = { da_nang = true },
        da_nang = { triad = true },
    },
    -- Rival gang members within initiateRadius of a player on foot (or barely moving in a car) start
    -- a fight with this chance per second, then leave that player alone for initiateCooldown seconds.
    initiateRadius = 14, initiateChance = 0.08, initiateCooldown = 60, initiateMaxCarSpeed = 4,

    -- Aiming a gun at someone (ours, after vanilla's aimed-at responses): cops and gangs fight back
    -- (fellow gang members ignore it), civilians put their hands up (fear at or above handsUpFear),
    -- fight (temper at or above fightTemper, armed), or run. Hold the aim on a hands-up victim for
    -- cashSeconds and they drop cash; stop aiming for releaseMs and they run.
    holdup = {
        handsUpFear = 35, fightTemper = 75, cashSeconds = 2.5, releaseMs = 2500, maxSeconds = 30,
        cash = { civilian = { 10, 150 }, gang = { 20, 200 }, cop = { 0, 0 } },
        maxDistance = 30,
    },
}
