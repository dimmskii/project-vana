-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "engine", usage = "/engine", summary = "Turn your engine on or off (driver)",
      text = [[From the driver's seat: the engine off, or back on. An empty tank won't start. Getting back in starts it again, as in the game.]],
      see = { "lights", "controls" } },
    { name = "lights", usage = "/lights", summary = "Lights on, off or automatic, in turn (driver)",
      text = [[From the driver's seat, each press moves the lights on: on, off, then back to automatic (the game's own: on at night and in tunnels). The car keeps the setting.]],
      see = { "engine", "controls" } },
    { name = "lock", usage = "/lock", summary = "Lock or unlock the doors",
      text = [[From the driver's seat, or standing beside a car you hold (one you drove last, see the vehicle registry): locks the doors, or unlocks them. Nobody gets into a locked car, and its doors can't be opened from outside.]],
      see = { "doorfrontleft", "controls" } },
    { name = "doorfrontleft", aliases = { "doorfl", "doorfrontright", "doorfr", "doorrearleft", "doorrl", "doorrearright", "doorrr", "hood", "bonnet", "trunk", "boot" },
      usage = "/doorfrontleft, /doorfrontright, /doorrearleft, /doorrearright, /hood, /trunk", summary = "Open or close a door, the hood or the trunk",
      text = [[Opens that door, or closes it if it's open. Sitting in a car: only that car, and only your own seat's door; the hood and trunk are the driver's. On foot: the car you're beside and looking at, when it isn't locked. Rear doors only on cars with four seats or more; a door that's come off is gone.]],
      see = { "lock", "controls" } },
    { name = "performance", topic = true, summary = "Performance parts: engine stages, turbo, brakes, suspension...",
      text = [[Sold at every mod garage after the vanilla parts, for any car: Engine stage 1-3, Turbo, Brakes (sport, race with ABS), Suspension (sport, race), Tyres (sport, race), Armour (armour, heavy), Lightweight kit, AWD conversion. Each one scales your car's own stats (torque, top speed, grip, braking, damage taken, weight...), so every car stays itself, only better. Levels in a category replace each other; categories stack.

They stay with the car like its colours and parts. A turbo also whines on top of the engine, rising with speed and throttle (/turbosound off silences it for you).]],
      see = { "garages", "turbosound" } },
    { name = "turbosound", usage = "/turbosound [bank sound | off]", summary = "Turbo whine: audition another sound, or switch it off",
      text = [[The turbo's whine is a looped game sound (GENRL bank 131, sound 10: the Hydra's jet). Give another bank and sound to hear it on turbo cars near you, or off to silence the whine for you. Only you hear the change; the default is in vana-vehicles' config.]] },
    { name = "performancetest", console = true, usage = "performancetest", summary = "Self-test: performance parts",
      text = [[Tunes a car fully and back: the levels multiply as configured, and stock gives back the model's own handling.]] },
    { name = "car", usage = "/car <vehicle> [player]", right = "command.car", summary = "Put yourself (or a player) in a new vehicle",
      text = [[A new vehicle where you (or the named player) stand, with you in the driver's seat, engine running and a full tank. It replaces the last one /car gave that player (wherever it is); in someone else's car, you get out and the new one appears alongside. It isn't kept like the cars you drive (the registry), and goes when its player leaves.

The vehicle: a model ID (400-611), its name (Infernus, NRG-500, Police LS...: spaces and dashes don't matter), or a short name (police, cop, tank, nrg, pcj, heli, jet, plane, boat...). A unique start is enough (inf); several matches are listed.]],
      see = { "spawncar", "cleanvehicles" } },
    { name = "spawncar", usage = "/spawncar <vehicle> [player]", right = "command.spawncar", summary = "A new vehicle in front of you (or a player)",
      text = [[A new vehicle, empty, a few metres in front of you or the named player (further for boats and aircraft), with a full tank. An ordinary vehicle: drive it and it's kept like any other; /cleanvehicles takes it away if nobody does. Vehicles are named as for /car.]],
      see = { "car", "cleanvehicles" } },
    { name = "cleanvehicles", usage = "/cleanvehicles [all | player] [force]", right = "command.cleanvehicles", summary = "Remove empty vehicles",
      text = [[With nothing: every empty vehicle nobody keeps (abandoned traffic, parked cars, dropped cars).
all: every empty vehicle, kept ones too.
A player: that player's kept vehicles.

Never a vehicle with anyone in any seat (player or ped), or a trailer an occupied vehicle tows, unless you add force: then those go too, everyone in them put out first. Never mission and reward cars, or trains. Parked cars come back from their generators.]],
    },
    { name = "vehicletest", usage = "vehicletest [keep | check]", console = true, summary = "Self-test: the vehicle registry",
      text = [[Snapshot round trip, list rules, persistence, rebuilding, fuel, radio picks and cleanup. keep, then restart vana-vehicles, then check: one kept car survives the restart.]],
    },
    { name = "tuningtest", usage = "tuningtest", console = true, summary = "Self-test: ambient cars' random parts",
      text = [[Tunes 400 each of a Voodoo, a taxi, an Elegy and an Admiral and logs the rates.]],
    },
}

function getHelpPages() return HelpPages end
