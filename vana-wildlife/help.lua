-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "bigfoot", usage = "/bigfoot", right = "command.bigfoot", summary = "Bigfoot in front of you, now",
      text = [[Spawns Bigfoot 20 m in front of you (replacing the current one).]],
    },
    { name = "wildlifetest", usage = "wildlifetest", console = true, summary = "Self-test: wildlife",
      text = [[The spots, the area and the model files are in place.]],
    },
}

function getHelpPages() return HelpPages end
