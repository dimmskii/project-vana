-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "wildlifetest", usage = "wildlifetest", console = true, summary = "Self-test: wildlife",
      text = [[Every spawner names a known species, and every species' model, animation and sound files are here.]],
    },
}

function getHelpPages() return HelpPages end
