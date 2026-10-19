-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "parkedtest", usage = "parkedtest", console = true, summary = "Self-test: parked cars",
      text = [[Checks the car generators.]],
    },
}

function getHelpPages() return HelpPages end
