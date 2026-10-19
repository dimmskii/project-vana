-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "traffic", usage = "/traffic on|off|clear|density <percent>|debug on|off", right = "command.traffic", summary = "Control road traffic",
      text = [[on / off: start or stop traffic. clear: remove the traffic now. density: percent of vanilla's density. debug: traffic debug drawing.]],
    },
    { name = "traffictest", usage = "traffictest [seed]", console = true, summary = "Self-test: traffic",
      text = [[Runs the traffic planner checks (with a seed to repeat a run).]],
    },
}

function getHelpPages() return HelpPages end
