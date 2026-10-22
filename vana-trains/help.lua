-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "trains", usage = "/trains [on|off|reset|freight|passenger|tram <count>|debug on|off]", right = "command.trains", summary = "Control the trains",
      text = [[Alone: every train, where it is and what it's doing. on / off: trains appear near players, or stay out of the world (they keep running on the timetable). reset: every train back at its start. freight / passenger / tram <count>: how many of each run (kept; the trains reset). debug: train lines in the server log (the same switch as /vanadebug trains sync).]],
    },
    { name = "traintest", usage = "traintest [seed]", console = true, summary = "Self-test: trains",
      text = [[Runs hours of the train timetable and checks it: no train runs into another, the Brown Streak stops at every station, a train left on the line holds the ones behind it.]],
    },
}

function getHelpPages() return HelpPages end
