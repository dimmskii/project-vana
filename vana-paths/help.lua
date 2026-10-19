-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "pathstest", usage = "pathstest", console = true, summary = "Self-test: path nodes",
      text = [[Checks the road and footpath graph.]],
    },
    { name = "lightstest", usage = "lightstest", console = true, summary = "Self-test: light stop rule",
      text = [[Checks the traffic light stop rule.]],
    },
}

function getHelpPages() return HelpPages end
