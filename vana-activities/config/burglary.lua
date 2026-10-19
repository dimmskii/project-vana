-- Burglary (vanilla BURGJB / BURG_BRAINS). Values from the mission script unless marked "ours".
Burglary = {
    van = 609,                  -- Boxville: the sub-mission key in it starts a burglary
    startHour = 20, dawnHour = 6, -- burglary runs from 20:00 until 06:00 (game time)
    balaclava = { texture = "balaclava", model = "balaclava", slot = 17 },
    lockupMs = 300000,          -- after dawn: time to get what's in the van to a lock-up
    getOutMs = 10000,           -- after a resident notices you: time to leave before the cops come
    wantedStars = 3,
    payPerItemSquared = 20,     -- a load of n items pays n * n * this
    perkTotal = 10000,          -- total takings for vanilla's reward (BURG54)
    -- Loading: stand this far behind the van's centre (vanilla 6 m) within this radius, holding an item.
    vanBack = 6.0, vanReach = 3.5,
    -- Lock-ups: garage ID (setGarageOpen), where it opens for the van, and where the van parks inside.
    lockups = {
        At("Burglary.lockups.1", { garage = 6, park = At("Burglary.lockups.1.park") }),     -- BURG_LK (LS)
        At("Burglary.lockups.2", { garage = 20, park = At("Burglary.lockups.2.park") }),   -- BRGSFSE (SF)
        At("Burglary.lockups.3", { garage = 33, park = At("Burglary.lockups.3.park") }),     -- VGELOCK (LV)
    },
    openRadius = 20, parkRadius = 3.2,
    -- Noise (stealth bar): per frame, the engine's noise level at the player * scale, minus floor, adds
    -- up and decays (x decay each 1/30 s). At 100 a resident wakes up.
    noise = { scale = 1.6, floor = 20, decay = 0.99 },
    -- Ours: vanilla furnishes houses procedurally and steals from that furniture; MTA can't hand the
    -- engine's furniture to scripts, so we place stealable furniture (models Neon can carry, from
    -- furnitur.dat's stealable groups) on free floor in each house.
    loot = { 2312, 2316, 2317, 2318, 2320, 2322, 1809, 2101, 2102, 2103, 2226, 1783, 1719, 2028 },
    lootPerHouse = { 3, 6 },
    -- Ours: chance a house has someone asleep in it (vanilla's procedural houses spawn residents), and
    -- who. Residents react as BURG_BRAINS does: men fight or give up, women cower, gang members fight.
    residentChance = 0.6,
    residents = {
        { model = 7, kind = "male" }, { model = 14, kind = "male" }, { model = 15, kind = "male" }, { model = 20, kind = "male" },
        { model = 9, kind = "female" }, { model = 12, kind = "female" }, { model = 13, kind = "female" }, { model = 31, kind = "female" },
        { model = 105, kind = "gang" }, { model = 102, kind = "gang" }, { model = 114, kind = "gang" },
    },
    doorRadius = 1.4,           -- ours: how close to a door's trigger to go in
}
