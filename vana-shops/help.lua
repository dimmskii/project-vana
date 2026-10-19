-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "garages", topic = true, summary = "Mod garages: Transfender, Loco Low Co., Wheel Arch Angels",
      text = [[Drive in and stop on the marker inside a mod garage's door to go in. Any car, monster truck or quad, at any garage. Parts that don't fit your car are greyed out; the highlighted one is tried on, and leaving takes off what you didn't buy. Colours and paintjobs are $150. After the vanilla parts come our performance parts (engine, turbo, brakes, suspension, tyres, armour, lightweight, AWD).

Up/Down choose, Enter buys or opens, Backspace goes back or drives out.]],
      see = { "warp" },
    },
    { name = "shoppoint", usage = "/shoppoint <shop name, e.g. AMMUN1>", right = "command.shoppoint", summary = "Move a shop's point to where you stand",
      text = [[Puts the shop's customer point where you stand and prints the map element to keep (or move it in the Map Editor: vana-data-shops).]],
    },
    { name = "shoptest", usage = "shoptest", console = true, summary = "Self-test: shops",
      text = [[Every shop point has a stock, every item a price.]],
    },
    { name = "garagetest", usage = "garagetest", console = true, summary = "Self-test: mod garages",
      text = [[The stock resolves, a Blade's menu builds, a police car takes the universal parts.]],
    },
}

function getHelpPages() return HelpPages end
