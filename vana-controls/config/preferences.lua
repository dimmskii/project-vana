-- The preferences panel (/preferences, prefs_client.lua): sections, headings and each setting, its key
-- (getPreference(key) in any client script), its choices and default. Kept on the player's own machine.
-- Hand-written: add settings freely; a setting nobody reads yet is fine to have early.
local SIZES = { { "Smallest", 0.6 }, { "Smaller", 0.75 }, { "Small", 0.9 }, { "Normal", 1 }, { "Large", 1.2 }, { "Larger", 1.45 }, { "Largest", 1.75 } }
local RANGES = { { "Half", 0.5 }, { "Less", 0.75 }, { "Normal", 1 }, { "More", 1.5 }, { "Double", 2 }, { "Triple", 3 } }

Preferences = {
    { heading = "HUD" },
    { heading = "Map", level = 2 },
    { key = "map.blipSize", label = "Blip size", choices = SIZES, default = 1 },
    { heading = "Minimap", level = 2 },
    { key = "minimap.rotation", label = "Rotation", default = "camera",
      choices = { { "Turns with the camera (vanilla)", "camera" }, { "North up", "north" } } },
    { key = "minimap.blipSize", label = "Blip size", choices = SIZES, default = 1 },
    { key = "minimap.blipRange", label = "Nearby icons' range", choices = RANGES, default = 1 },
}
