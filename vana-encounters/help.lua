-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "encountertest", usage = "encountertest", console = true, summary = "Self-test: encounters",
      text = [[Every encounter has a known kind, a unique id and its model files; lists each one's hours and whether it's out, waiting or killed today.]],
    },
}

function getHelpPages() return HelpPages end
