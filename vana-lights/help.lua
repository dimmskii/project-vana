-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "lightcycletest", usage = "lightcycletest", console = true, summary = "Self-test: traffic light cycle",
      text = [[Checks the traffic light cycle.]],
    },
}

function getHelpPages() return HelpPages end
