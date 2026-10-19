-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "cleanvehicles", usage = "/cleanvehicles [all | player]", right = "command.cleanvehicles", summary = "Remove empty vehicles",
      text = [[With nothing: every empty vehicle nobody keeps (abandoned traffic, parked cars, dropped cars).
all: every empty vehicle, kept ones too.
A player: that player's kept vehicles.

Never a vehicle with anyone in any seat (player or ped), a trailer an occupied vehicle tows, mission and reward cars, or trains. Parked cars come back from their generators.]],
    },
    { name = "vehicletest", usage = "vehicletest [keep | check]", console = true, summary = "Self-test: the vehicle registry",
      text = [[Snapshot round trip, list rules, persistence, rebuilding, fuel, radio picks and cleanup. keep, then restart vana-vehicles, then check: one kept car survives the restart.]],
    },
    { name = "tuningtest", usage = "tuningtest", console = true, summary = "Self-test: ambient cars' random parts",
      text = [[Tunes 400 each of a Voodoo, a taxi, an Elegy and an Admiral and logs the rates.]],
    },
}

function getHelpPages() return HelpPages end
