-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "peds", usage = "/peds on|off|clear|density <percent>", right = "command.peds", summary = "Control pedestrians",
      text = [[on / off: start or stop pedestrians. clear: remove them now. density: percent of vanilla's density.]],
    },
    { name = "pedtest", usage = "pedtest [seed]", console = true, summary = "Self-test: pedestrians",
      text = [[Runs the pedestrian planner checks (with a seed to repeat a run).]],
    },
}

function getHelpPages() return HelpPages end
