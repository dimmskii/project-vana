-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "carstest", usage = "carstest", console = true, summary = "Self-test: added vehicles",
      text = [[Checks every added vehicle and retexture: a model was made for it, its files are there, it has a name, colours and a credit, and every service variant names one of them.]],
    },
}

function getHelpPages() return HelpPages end
