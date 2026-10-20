-- Encounters: creatures and NPCs you may run into at their spots ([data]/vana-data-encounters,
-- `encounter` elements by creature). Bigfoot is from a community mod (docs/credits.md): values from the
-- mod's script unless marked "ours".
EncounterRules = {
    -- Bigfoot v1.2 by Tysman (vana-encounters/mods/bigfoot): appears in the south-west countryside
    -- (Back o' Beyond, Whetstone) out of sight of the player, walks to a spot (in fog) and stands; hurt
    -- him and he goes for you. One at a time.
    bigfoot = {
        area = { -2815.2, -2911.9, 7.9, -748.38 }, -- x1, y1, x2, y2: a player in here can meet him
        fogWeathers = { [9] = true },               -- vanilla weather 9 (foggy) uses the fog spots
        checkMs = 250,
        spawnAway = 160,          -- he appears only this far from the player
        despawnFromSpawn = 400,   -- and fades away beyond this from where he appeared...
        despawnFromPlayer = 350,  -- ...or this far from every player
        health = 1000,            -- vanilla 1000: damage to him is divided by health / 100 (ours: MTA ped health is 100)
        fightingStyle = 5,        -- boxing
        walkingStyle = 120,       -- OLDMAN
        baseModel = 7,            -- ours: the server's ped model; clients show the Bigfoot model on it
        respawnMs = 60000,        -- ours: after he dies or fades, the next chance comes no sooner
        chance = 0.02,            -- ours: chance per check that he appears (the mod: whenever possible)
    },
}
