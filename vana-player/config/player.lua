-- Players: what a new player starts with, and what being wasted or busted costs. Edit freely.
PlayerConfig = {
    -- New players (identified by their MTA serial).
    start = {
        money = 250,
        -- Ped stats (0-1000): 21 fat, 22 stamina, 23 muscle, 24 max health (569 = 100 HP, 1000 = 176 HP).
        stats = { [21] = 200, [22] = 0, [23] = 0, [24] = 569 },
        spawn = At("PlayerConfig.start.spawn", { heading = 0 }), -- Grove Street
    },

    -- Coming back where you left, rather than at the start spawn.
    spawnAtLastPosition = true,

    -- Vanilla: wasted or busted, you lose your weapons and pay $100 (hospital bill or fine).
    wasted = { fee = 100, loseWeapons = true, delayMs = 4000 },
    busted = { fee = 100, loseWeapons = true, delayMs = 4000 },

    saveIntervalMs = 60000,

    -- Rights our admin commands need, granted to the Admin ACL on start (restricted commands).
    adminRights = { "command.traffic", "command.peds", "command.wanted", "command.shoppoint",
                    "command.setmoney", "command.addmoney", "command.setstat", "command.event",
                    "command.warp", "command.warphere", "command.warps", "command.cleanvehicles", "command.vanadebug",
                    "command.vanaset", "command.animal", "command.pos",
                    "command.car", "command.spawncar", "command.trains" },

    -- Admin warps (/warp, /warphere, /warps; docs/player.md). Places come from the map data (spots by
    -- id, hospitals and police stations, interior entrances by vanilla's names); these are extra names
    -- for them: a name -> another place's name, or { x, y, z [, interior] }.
    warps = {
        start = "playerconfig.start.spawn", spawn = "playerconfig.start.spawn",
        cj = "carls", home = "carls", -- CJ's house on Grove Street (vanilla's entrance CARLS)
        -- Inside only: vanilla's missions open these houses' front doors.
        sweet = "sweets.in", ryder = "ryders.in", ogloc = "oglocs.in",
        binco = "clothgp", ammu = "ammun1", gym = "gym1",
        -- The mod garages' doorways (vana-shops' config/garages.lua): stop there in a vehicle to go in.
        transfender = { 1042.01, -1019.93, 31.13 }, ["transfender.sf"] = { -1935.53, 247.03, 33.56 },
        ["transfender.lv"] = { 2387.08, 1050.51, 9.81 }, locolow = { 2645.11, -2045.75, 12.61 },
        waa = { -2723.85, 217.8, 3.59 },
        -- The Pay 'n' Sprays (vana-shops' config/sprays.lua), inside each.
        ["spray.idlewood"] = { 2063.95, -1831.44, 12.54 }, ["spray.temple"] = { 1024.87, -1024.12, 30.91 },
        ["spray.santamariabeach"] = { 487.34, -1741.03, 9.46 }, ["spray.downtown"] = { -1904.52, 285.17, 40.04 },
        ["spray.juniperhollow"] = { -2425.66, 1020.74, 49.34 }, ["spray.oldventurasstrip"] = { 2393.86, 1490.55, 9.82 },
        ["spray.redsandseast"] = { 1975.78, 2162.45, 9.60 }, ["spray.elquebrados"] = { -1420.48, 2583.72, 54.82 },
        ["spray.fortcarson"] = { -100.00, 1119.11, 18.70 }, ["spray.dillimore"] = { 720.05, -454.84, 14.96 },
    },

    -- ACL groups players belong to, by MTA serial (their auto-login account is named after it). Applied
    -- to the ACL whenever vana-player starts, so it survives the server rewriting acl.xml.
    groups = {
        Admin = {
            "AD1362C8433B585B0BDF129135370642", -- Dimmskii
        },
    },
}
