-- Wanted levels and police response. Seeded from CWanted (gta-reversed Wanted.cpp); edit freely.
Wanted = {
    -- Chaos points per crime (CWanted::ReportCrimeNow multipliers; kill_cop is ours).
    crimes = {
        damaged_ped = 5, damaged_cop = 45, stab_ped = 35, stab_cop = 100,
        damage_car = 30, hit_car = 2, damage_cop_car = 80, destroy_vehicle = 70,
        car_steal = 15, kill_ped_with_car = 18, kill_cop_with_car = 80, kill_cop = 100,
        jack_cop = 45, -- ours: dragging a cop out of their car
        holdup = 30, threaten_cop = 45, -- ours: robbing someone at gunpoint, aiming at a cop
    },
    -- Crimes against the police raise the wanted level to at least this many stars at once.
    minStars = { threaten_cop = 1, jack_cop = 1, damaged_cop = 1, stab_cop = 2, damage_cop_car = 2, kill_cop = 2, kill_cop_with_car = 2 },
    -- Chaos needed for 1-6 stars (CWanted::UpdateWantedLevel), and the pursuit each level sends.
    thresholds = { 50, 180, 550, 1200, 2400, 4600 },
    pursuit = {
        { cops = 1, cars = 1 }, { cops = 3, cars = 2 }, { cops = 4, cars = 2 },
        { cops = 6, cars = 2 }, { cops = 8, cars = 3 }, { cops = 10, cars = 3 },
    },
    -- Which units answer at each level (weights; vanilla adds SWAT at 4, FBI at 5, the army at 6).
    units = {
        { police = 1 }, { police = 1 }, { police = 1 },
        { police = 1, swat = 1 },
        { police = 1, swat = 1, fbi = 2 },
        { fbi = 1, army = 2, tank = 1 },
    },
    -- Crew size and weapon per unit (weapon IDs: 22 pistol, 25 shotgun, 29 MP5, 31 M4).
    crews = {
        police = { size = 2, weapon = 22, weaponFrom3Stars = 25 },
        swat = { size = 4, weapon = 29 }, fbi = { size = 4, weapon = 29 },
        army = { size = 4, weapon = 31 }, tank = { size = 1, weapon = 31 },
    },
    -- Police helicopter (Maverick with a pilot and a gunner) from this many stars.
    heliFromStars = 3, heliWeapon = 29, heliHeight = 22, heliOrbit = 28,
    -- From 4 stars a second helicopter: SAN News' Maverick (488), unless one of the player's was shot
    -- down since their level was last below 3; then another police one (vanilla: CWanted::
    -- NumOfHelisRequired, UseNewsHeliInAdditionToPolice). Its crew of two (pilot, camera) is ours.
    newsHeliFromStars = 4, newsHeli = { model = 488, crew = 61 },
    -- Roadblocks ahead of a wanted player in a vehicle: chance per check by stars (CWanted::m_ChanceOnRoadBlock).
    roadblockChance = { 0, 0, 12, 18, 24, 30 }, roadblockEveryMs = 15000, roadblockAhead = { 120, 160 },

    -- Chaos lost per second with no cop within presenceRadius; doubled in the countryside and desert.
    decayPerSecond = 1, presenceRadius = 18,
    -- A crime counts when a cop within witnessRadius sees it (vanilla 14 m), and then gives at least
    -- one star; otherwise a civilian calls it in with reportChance after reportDelay ms. Bumping cars
    -- never gets called in.
    witnessRadius = 14, reportChance = 0.5, reportDelay = 6000,
    -- Walking cops within this distance of a wanted player go for them: at one star they run in to
    -- arrest, from two stars they shoot.
    engageRadius = 40,
    -- Patrol cars in traffic within this distance of a wanted player join the chase.
    recruitRadius = 80,
    -- Busted: a cop within bustRadius for bustMs while the player is on foot and slower than bustMaxSpeed (m/s).
    bustRadius = 1.8, bustMs = 1500, bustMaxSpeed = 1.5,
}

-- Ambulances answering bodies near players.
Medics = {
    callChance = 0.5,       -- a body near a player gets an ambulance this often
    callRadius = 200,       -- players within this distance count as "near"
    cooldownMs = 60000,     -- at most one ambulance per area in this time
    reviveChance = 0.5,     -- treated peds get back up
    cprMs = 8000,
}

-- Fire trucks answering exploded vehicles near players: firefighters hose the wreck down.
Firefighters = {
    callChance = 0.7, callRadius = 200, cooldownMs = 60000, sprayMs = 10000,
}
