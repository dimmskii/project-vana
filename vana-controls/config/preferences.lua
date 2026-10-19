-- The preferences panel (/preferences, prefs_client.lua): sections, headings and each setting, its key
-- (getPreference(key) in any client script), its choices and default. Kept on the player's own machine.
-- Hand-written: add settings freely; a setting nobody reads yet is fine to have early.
-- Blip sizes: the extra over the smallest grows twice as fast as it once did (Largest is 0.6 + 2 x 1.15).
local SIZES = { { "Smallest", 0.6 }, { "Smaller", 0.9 }, { "Small", 1.2 }, { "Normal", 1.4 }, { "Large", 1.8 }, { "Larger", 2.3 }, { "Largest", 2.9 } }
local RANGES = { { "Half", 0.5 }, { "Less", 0.75 }, { "Normal", 1 }, { "More", 1.5 }, { "Double", 2 }, { "Triple", 3 } }

Preferences = {
    { heading = "HUD" },
    { heading = "Map", level = 2 },
    { key = "map.blipSize", label = "Blip size", choices = SIZES, default = 1.4 },
    { heading = "Minimap", level = 2 },
    { key = "minimap.rotation", label = "Rotation", default = "camera",
      choices = { { "Turns with the camera (vanilla)", "camera" }, { "North up", "north" } } },
    { key = "minimap.blipSize", label = "Blip size", choices = SIZES, default = 1.4 },
    { key = "minimap.blipRange", label = "Nearby icons' range", choices = RANGES, default = 1 },
}
