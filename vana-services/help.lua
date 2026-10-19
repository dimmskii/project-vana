-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "wanted", usage = "/wanted <0-6> [player]", right = "command.wanted", summary = "Set a wanted level",
      text = [[Sets your wanted level, or the named player's.]],
    },
    { name = "event", usage = "/event [kind]", right = "command.event", summary = "Start a world event near you",
      text = [[Starts a random world event near you; /event alone lists the kinds.]],
    },
    { name = "wantedtest", usage = "wantedtest", console = true, summary = "Self-test: wanted levels",
      text = [[Checks the wanted rules against vanilla's thresholds and the unit tables.]],
    },
    { name = "eventtest", usage = "eventtest", console = true, summary = "Self-test: world events",
      text = [[Checks every event kind has a weight and a starter.]],
    },
}

function getHelpPages() return HelpPages end
