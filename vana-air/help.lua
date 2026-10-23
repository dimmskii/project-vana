-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "air", usage = "/air [on|off|reset|at400|andromada|shamal|nevada <count>|pass|debug on|off]", right = "command.air", summary = "Control the aircraft",
      text = [[Alone: every aircraft, what it's doing and where. on / off: aircraft appear near players, or stay out of the world (the airliners keep their timetable). reset: start everything over. at400 / andromada / shamal / nevada <count>: how many airliners of each (kept; resets them). pass: a helicopter flies past you now. debug: aircraft lines in the server log (the same switch as /vanadebug air sync).]],
    },
    { name = "airtest", usage = "airtest [seed]", console = true, summary = "Self-test: aircraft",
      text = [[Runs hours of the airliners' timetable and the circuit and checks them: planes keep flying, never jump, never meet on the ground or in a hold, nobody waits for ever.]],
    },
}

function getHelpPages() return HelpPages end
