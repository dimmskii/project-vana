-- How each species behaves and is driven (hand-written; the files are config/species.lua, generated;
-- the levers, how many and how aggressive, are this resource's settings in meta.xml).
--   driver    "ped": a ped wearing the species' model (models rigged to GTA's ped skeleton, as
--             Myths Maker's), walking by its own animations; "object": a plain model moved by the
--             server (for packs whose models aren't rigged as peds; no attacks, it only wanders and
--             flees)
--   walk      the walkcycle IFP and its animation names (`prefix`_idle/_walkstart/_run/_sprint) that
--             take the place of GTA's idle, walk, run and sprint on each of these peds
--   behaviour "prey" flees from people, "predator" may go for people it sees (the aggro settings) and
--             fights back, "neutral" ignores people and fights back when hurt
-- Only species listed here can spawn, and only those named in the `species` setting.
WildlifeKinds = {
    hare = { driver = "ped", behaviour = "prey", walk = { ifp = "mods/myths_maker/hare/hare_anim1.ifp", prefix = "rabit" } },
    deer = { driver = "ped", behaviour = "prey", walk = { ifp = "mods/myths_maker/deer/deer_anim1.ifp", prefix = "deer1" } },
    boar = { driver = "ped", behaviour = "neutral", walk = { ifp = "mods/myths_maker/boar/boar_anim2.ifp", prefix = "Boar" } },
    cat = { driver = "ped", behaviour = "prey", walk = { ifp = "mods/myths_maker/cat/cat_anim1.ifp", prefix = "cat" } },
    dog = { driver = "ped", behaviour = "neutral", walk = { ifp = "mods/myths_maker/dog/dog_anim2.ifp", prefix = "dog" } },
    wolf = { driver = "ped", behaviour = "predator", walk = { ifp = "mods/myths_maker/wolf/wolf_anim2.ifp", prefix = "wolf" } },
    brownbear = { driver = "ped", behaviour = "predator", walk = { ifp = "mods/myths_maker/brownbear/brownbear_anim1.ifp", prefix = "bear" } },
    -- The pack's black bear, puma and leopard walk on the brown bear's and the lioness's animations.
    blackbear = { driver = "ped", behaviour = "predator", walk = { ifp = "mods/myths_maker/brownbear/brownbear_anim1.ifp", prefix = "bear" } },
    puma = { driver = "ped", behaviour = "predator", walk = { ifp = "mods/myths_maker/lioness/lioness_anim1.ifp", prefix = "lion" } },
    leopard = { driver = "ped", behaviour = "predator", walk = { ifp = "mods/myths_maker/lioness/lioness_anim1.ifp", prefix = "lion" } },
}

-- GTA's walkcycle animations each ped's own take the place of (block "ped"), as the pack's animgrp.dat
-- maps them: its "_run" is the walk, its "_sprint" the run.
WildlifeWalkcycle = { walk_civi = "run", run_civi = "sprint", sprint_panic = "sprint", idle_stance = "idle", roadcross = "idle",
                      walk_start = "walkstart", walk_player = "run", run_player = "sprint", sprint_civi = "sprint" }
