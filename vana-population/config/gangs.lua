-- Origin: CGangs::Initialise (gta_sa.exe) plus main.scm's set_gang_weapons (RYDER2), extracted 2026-10. Canonical: edit freely; nothing regenerates this file.
-- weapons: weapon IDs a member may carry (CGangs::Initialise defaults; Grove from the RYDER2 mission.
-- Spraying all 100 tags upgrades Grove to desert eagle, mp5, knife in main.scm's COLLS script).
-- armedChance: chance a spawned member carries one of them (CPopulation::AddPed: 33%).
-- drawnChance: chance the weapon starts in hand rather than holstered (ours; vanilla varies).
Gangs = {
    ballas   = { id = 0, weapons = { 22, 28, 0 }, armedChance = 0.33, drawnChance = 0.5 }, -- pistol, micro smg, unarmed
    grove    = { id = 1, weapons = { 22, 32, 0 }, armedChance = 0.33, drawnChance = 0.5 }, -- pistol, tec9, unarmed
    vagos    = { id = 2, weapons = { 22, 0, 0 }, armedChance = 0.33, drawnChance = 0.5 }, -- pistol, unarmed, unarmed
    rifa     = { id = 3, weapons = { 22, 28, 0 }, armedChance = 0.33, drawnChance = 0.5 }, -- pistol, micro smg, unarmed
    da_nang  = { id = 4, weapons = { 22, 28, 0 }, armedChance = 0.33, drawnChance = 0.5 }, -- pistol, micro smg, unarmed
    mafia    = { id = 5, weapons = { 24, 0, 0 }, armedChance = 0.33, drawnChance = 0.5 }, -- desert eagle, unarmed, unarmed
    triad    = { id = 6, weapons = { 22, 30, 0 }, armedChance = 0.33, drawnChance = 0.5 }, -- pistol, ak47, unarmed
    aztecas  = { id = 7, weapons = { 22, 28, 0 }, armedChance = 0.33, drawnChance = 0.5 }, -- pistol, micro smg, unarmed
}
