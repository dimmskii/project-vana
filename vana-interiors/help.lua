-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "interiortest", usage = "interiortest", console = true, summary = "Self-test: entrances",
      text = [[Checks the entrance pairs and destinations.]],
    },
}

function getHelpPages() return HelpPages end
