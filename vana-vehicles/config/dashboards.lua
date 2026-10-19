-- Dashboards: each vehicle's gauges, drawn from a skin's textures (a TXD) while you're in it. The
-- server picks a vehicle's skin (vana:dashboard): by model, else the default; a kept car keeps its own.
-- Positions are vanilla's 640 x 448 HUD space (the CLEO mods' coordinates), anchored to the bottom
-- right and scaled evenly with the screen height. Angles are degrees clockwise from the needle
-- texture's own direction.
Dashboards = {
    default = "gasoline",
    models = {},            -- [model] = skin name
    none = { [481] = true, [509] = true, [510] = true, [449] = true, [537] = true, [538] = true, [569] = true, [570] = true,
             [590] = true }, -- bicycles and trains: no dashboard (as the mod)

    skins = {
        -- gasoline.cs's speedometer and fuel gauge (author unconfirmed, see docs/credits.md).
        gasoline = {
            txd = "mods/gasoline/gasoline.txd",
            parts = {
                { kind = "image", texture = "speedom", at = { 506.5, 385 }, size = { 242.5, 218 } },
                -- Speed: the dial reads 0..260 km/h clockwise from about 8 o'clock (measured on the
                -- texture; tune in game). zero: the needle's angle at 0; per: degrees per km/h.
                { kind = "needle", value = "speed", texture = "strelk", at = { 548, 379 }, size = { 241, 205 }, zero = -152, per = 1.04 },
                { kind = "text", value = "speed", at = { 548, 425 }, scale = 0.9, colour = { 220, 220, 220 } },
                -- Fuel: the small dial on the left, empty..full over about 110 degrees.
                { kind = "needle", value = "fuel", texture = "arrow", at = { 438.5, 412 }, size = { 109, 109 }, zero = -58.6, per = 110 },
                { kind = "lamp", value = "fuel", textures = { "scalef", "scalee" }, at = { 414, 414 }, size = { 65.5, 53.5 }, below = 5000 },
                { kind = "image", value = "locked", texture = "lock", at = { 459, 432.3 }, size = { 14, 14 } },
                -- Nitro, when fitted: its own dial left of the speedometer, E..F.
                { kind = "image", value = "nitro", texture = "nitro", at = { 213.5, 339 }, size = { 128, 111 } },
                { kind = "needle", value = "nitro", texture = "arrown", at = { 213.5, 339 }, size = { 128, 128 }, zero = -59, per = 118 },
            },
        },
    },
}
