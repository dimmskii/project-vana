-- Players: what a new player starts with, and what being wasted or busted costs. Edit freely.
PlayerConfig = {
    -- New players (identified by their MTA serial).
    start = {
        money = 250,
        -- Ped stats (0-1000): 21 fat, 22 stamina, 23 muscle, 24 max health (569 = 100 HP, 1000 = 176 HP).
        stats = { [21] = 200, [22] = 0, [23] = 0, [24] = 569 },
        spawn = { x = 2495.3, y = -1687.4, z = 13.5, heading = 0 }, -- Grove Street
    },

    -- Coming back where you left, rather than at the start spawn.
    spawnAtLastPosition = true,

    -- Vanilla: wasted or busted, you lose your weapons and pay $100 (hospital bill or fine).
    wasted = { fee = 100, loseWeapons = true, delayMs = 4000 },
    busted = { fee = 100, loseWeapons = true, delayMs = 4000 },

    saveIntervalMs = 60000,

    -- Rights our admin commands need, granted to the Admin ACL on start (restricted commands).
    adminRights = { "command.traffic", "command.peds", "command.wanted", "command.shoppoint" },

    -- ACL groups players belong to, by MTA serial (their auto-login account is named after it). Applied
    -- to the ACL whenever vana-player starts, so it survives the server rewriting acl.xml.
    groups = {
        Admin = {
            "AD1362C8433B585B0BDF129135370642", -- Dimmskii
        },
    },
}
