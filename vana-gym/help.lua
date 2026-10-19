-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "gymtest", usage = "gymtest", console = true, summary = "Self-test: the gym",
      text = [[Checks the gym equipment and its stats.]],
    },
}

function getHelpPages() return HelpPages end
