-- The rest of vana-cars' configuration (docs/cars.md); the added vehicles are in vehicles.lua.

-- Where a model's files are: <dir>/<name>.dff, .txd (the added vehicles: the pack's folder).
function CarFiles(def) return (def.dir or "mods/evvpr") .. "/" .. def.name end

-- Retextures of vanilla vehicles, as models of their own (the vanilla one is untouched and keeps its
-- name): the vanilla model's own DFF unless `dff` is given, with the retexture's TXD.
CarSkins = {
    { name = "infernfl", dir = "mods/flame_infernus", parent = 411, dff = true, chance = 0.15,
      credit = "Flame Infernus v4.0: original model and textures by Silver3o5, edited model and new textures by FunGt" },
    { name = "monstbbt", dir = "mods/bigboys_monster", parent = 557, chance = 0.5, credit = "Big Boy's Toys monster truck (gta-modding.it; author not given)" },
}

-- Where the added vehicles take part beside the vanilla ones (from the pack's ModelVariations_Vehicles.ini,
-- ours where it differs): for a vanilla service vehicle, the models picked among it and these, in the
-- given cities (vana-population's city names) or zones (info.zon names), everywhere when neither is set.
-- `replace`: only these there, not the vanilla one (as the pack's Las Venturas Securicar).
CarVariants = {
    [596] = { { models = { "polbrg" } } },                                  -- LSPD cruiser
    [597] = { { models = { "polsol" } } },                                  -- SFPD
    [598] = { { models = { "polbet" } } },                                  -- LVPD
    [599] = { { models = { "ranger", "polpat", "polvel" } } },              -- country police
    [490] = { { models = { "fbistn", "fbibrg", "fbiprm", "cheetuc" } } },   -- FBI
    [427] = { { models = { "enforcr2" } } },                                -- SWAT
    [416] = { { models = { "steeda", "burrita" } } },                       -- ambulance
    [407] = { { models = { "firehk", "oldfire" } },                         -- fire
              { zones = { "LAIR1", "LAIR2a", "LAIR2b", "LBAG1", "LBAG2", "LBAG3", "SFAIR1", "SFAIR2", "SFAIR3", "SFAIR4",
                          "SFAIR5", "VAIR1", "VAIR2", "VAIR3" }, models = { "firebrg" }, replace = true } }, -- airport fire brigade
    [428] = { { cities = { "las_venturas" }, models = { "securic" }, replace = true } },             -- casino Securicar
}

-- The shared vehicle textures (models/generic/vehicle.txd: dirt, lights, tyres, plates, decals), clean
-- and in higher resolution, imported into every vehicle model.
CarBaseTextures = { file = "mods/evvpr/generic/vehicle.txd",
    credit = "Proper Vehicle Retex: Miguel Araújo, Jéssica Natália, Nick Oliveira, Meck, Junior_Djjr, CassadorEterno" }

-- Sirens for added emergency vehicles (the game gives them only to its own models): lights per parent,
-- placed on the roof (ours; positions are a first guess, to be tuned in game).
CarSirens = {
    [596] = { z = 0.95, colours = { { 255, 0, 0 }, { 0, 0, 255 } } }, [597] = { z = 0.95, colours = { { 255, 0, 0 }, { 0, 0, 255 } } },
    [598] = { z = 0.95, colours = { { 255, 0, 0 }, { 0, 0, 255 } } }, [599] = { z = 1.15, colours = { { 255, 0, 0 }, { 0, 0, 255 } } },
    [490] = { z = 1.15, colours = { { 255, 0, 0 }, { 0, 0, 255 } } }, [427] = { z = 1.6, colours = { { 255, 0, 0 }, { 0, 0, 255 } } },
    [416] = { z = 1.5, colours = { { 255, 0, 0 }, { 255, 255, 255 } } }, [407] = { z = 1.7, colours = { { 255, 0, 0 }, { 255, 0, 0 } } },
    [544] = { z = 1.7, colours = { { 255, 0, 0 }, { 255, 0, 0 } } },
}

-- Handling.cfg columns after the name, as setModelHandling properties (SA's order).
CarHandlingColumns = {
    "mass", "turnMass", "dragCoeff", "centerOfMassX", "centerOfMassY", "centerOfMassZ", "percentSubmerged",
    "tractionMultiplier", "tractionLoss", "tractionBias", "numberOfGears", "maxVelocity", "engineAcceleration",
    "engineInertia", "driveType", "engineType", "brakeDeceleration", "brakeBias", "ABS", "steeringLock",
    "suspensionForceLevel", "suspensionDamping", "suspensionHighSpeedDamping", "suspensionUpperLimit",
    "suspensionLowerLimit", "suspensionFrontRearBias", "suspensionAntiDiveMultiplier", "seatOffsetDistance",
    "collisionDamageMultiplier", "monetary", "modelFlags", "handlingFlags", "headLight", "tailLight", "animGroup",
}
