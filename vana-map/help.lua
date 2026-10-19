-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "maptest", usage = "maptest", console = true, summary = "Self-test: map points",
      text = [[Checks the map point categories and blips.]],
    },
}

function getHelpPages() return HelpPages end
