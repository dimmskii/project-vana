-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "performance", topic = true, summary = "Performance parts: engine stages, turbo, brakes, suspension...",
      text = [[Sold at every mod garage after the vanilla parts, for any car: Engine stage 1-3, Turbo, Brakes (sport, race with ABS), Suspension (sport, race), Tyres (sport, race), Armour (armour, heavy), Lightweight kit, AWD conversion. Each one scales your car's own stats (torque, top speed, grip, braking, damage taken, weight...), so every car stays itself, only better. Levels in a category replace each other; categories stack.

They stay with the car like its colours and parts. A turbo also whines on top of the engine, rising with speed and throttle (/turbosound off silences it for you).]],
      see = { "garages", "turbosound" } },
    { name = "turbosound", usage = "/turbosound [bank sound | off]", summary = "Turbo whine: audition another sound, or switch it off",
      text = [[The turbo's whine is a looped game sound (GENRL bank 131, sound 10: the Hydra's jet). Give another bank and sound to hear it on turbo cars near you, or off to silence the whine for you. Only you hear the change; the default is in vana-vehicles' config.]] },
    { name = "performancetest", console = true, usage = "performancetest", summary = "Self-test: performance parts",
      text = [[Tunes a car fully and back: the levels multiply as configured, and stock gives back the model's own handling.]] },
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
