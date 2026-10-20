-- Encounter kinds: what each `encounter` element ([data]/vana-data-encounters) can be, as shop points
-- name their kind. A kind gives the defaults; an element overrides any of them (its health, reward,
-- model, styles, weapon, idle animation, blip) and adds its own name, hours and place. The kind's
-- `script` names its behaviour in server.lua (EncounterScripts); "creature" is the plain one: it
-- stands, or walks to the element's target, and goes for whoever hurts it.
EncounterKinds = {
    -- Bigfoot v1.2 by Tysman (vana-encounters/mods/bigfoot, docs/credits.md): his model, walk, boxing and
    -- 1000 health are the mod's; the rest is ours.
    bigfoot = {
        name = "Bigfoot",
        script = "creature",
        model = 7,                                    -- the server's ped model; clients show his on it
        dff = "mods/bigfoot/bigfoot.dff", txd = "mods/bigfoot/bigfoot.txd",
        health = 1000,                                -- in GTA's units: our clients scale damage to MTA's 100
        fightingStyle = 5,                            -- boxing
        walkingStyle = 120,                           -- OLDMAN
        reward = 5000,                                -- ours: shared by the damage each player did
        blip = "bigfoot",                             -- vana-map category (config/categories.lua there)
    },
}

-- How encounters run (ours).
EncounterRules = {
    tick = 1000,
    bodyMs = 30000,          -- a body stays this long
    chaseGiveUp = 150,       -- an attacker this far away (or gone) and it goes back to what it was doing
    blipMs = 2000,           -- how often its blip follows it
    maxHitLoss = 250,        -- the most one reported hit may count (in its health units), against bad reports
}
