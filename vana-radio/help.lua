-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "radio", topic = true, summary = "Car radio stations, switching, speakers",
      text = [[Every station plays on the server's clock: everyone tuned in hears the same moment, in cars, from cars outside, and from speakers in clubs.

In a car: the radio keys (mouse wheel by default) switch station; the driver chooses, passengers only when no player drives. The station's name shows at the top.]],
      see = { "radiovolume", "radiodebug" },
    },
    { name = "radiovolume", usage = "/radiovolume [0-100]", summary = "Set (or show) your radio volume",
      text = [[The game's own radio volume can't be read, so this is ours. Saved on your computer.]],
    },
    { name = "radiodebug", usage = "/radiodebug", summary = "Show what the radio is playing (on/off)",
      text = [[On screen: the game's own radio (should be stopped), your clock offset from the server, and each radio you hear: the track, where it should be and where its sound is.]],
    },
    { name = "radiostatus", usage = "radiostatus", console = true, summary = "Every station's current and next segments",
      text = [[Logs each station's segments and how many clients listen.]],
    },
}

function getHelpPages() return HelpPages end
