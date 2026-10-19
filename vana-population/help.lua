-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "poptest", usage = "poptest", console = true, summary = "Self-test: population",
      text = [[Checks the popcycle, groups and zones.]],
    },
}

function getHelpPages() return HelpPages end
