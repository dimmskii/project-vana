-- Shopkeepers and where customers are served, from the vanilla shop scripts in main.scm (BARB, TATTO).
-- Each shop type has one layout in interior coordinates; each shop moves it by its offset. Points are
-- { x, y, z, heading } with ground z, as in the scripts. Cameras are { x, y, z, lookX, lookY, lookZ }.
KeeperLayouts = {
    hair = {
        keeper = { 414.273, -18.002, 1000.86, 180 },
        customer = { 414.3, -19.9, 1000.806, 90 },
        camera = { 412.649, -19.7078, 1001.9915, 413.3581, -19.0046, 1002.0428 },
        -- Styles that get the beard-checking animation instead of a hair one.
        beards = { TASH = true, GOATEE = true, BEARD = true, AFROT = true, AFROB = true, AFROGOT = true,
                   BLADBEA = true, BALDTSH = true, BALDGOT = true },
    },
    tattoo = {
        keeper = { -201.668, -6.217, 1001.28, 155 },
        customer = { -203.318, -7.062, 1001.28, 125 },
        camera = { -203.2045, -5.3316, 1002.4316, -202.2993, -5.7376, 1002.3063 },
        kit = { model = 3126, z = 1.0 }, -- TATTOO_KIT above the artist's stool (vanilla animates it; we can't yet)
        -- Body part (clothes slot) -> pose animation group for the customer and the artist.
        parts = { [4] = { "ArmL", "ArmL" }, [5] = { "ArmL", "ArmL" }, [6] = { "ArmR", "ArmR" }, [7] = { "ArmR", "ArmR" },
                  [8] = { "Back", "Back" }, [9] = { "Che", "Che" }, [10] = { "Che", "Che" }, [11] = { "Che", "Bel" },
                  [12] = { "Back", "Back" } },
    },
}

-- Shops with staff: layout, keeper model (vanilla's) and the shop's offset from the layout.
Keepers = {
    BARBERS = { layout = "hair", model = 156, offset = { 0, 0, 0 } },
    BARBER2 = { layout = "hair", model = 177, offset = { 6.987, -61.401, 0 } },
    BARBER3 = { layout = "hair", model = 176, offset = { 0.371, -31.421, 0 } },
    TATTOO = { layout = "tattoo", model = 180, offset = { 0, -18.266, 0 } },
    TATTO2 = { layout = "tattoo", model = 180, offset = { 0, 0, 0 } },
    TATTO3 = { layout = "tattoo", model = 180, offset = { 0, -35.32, 0 } },
}
