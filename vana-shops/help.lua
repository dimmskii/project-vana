-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "buyfood", aliases = { "buyweapons", "buyclothes", "buyitems", "haircut", "tattoo", "learnstyle" },
      usage = "/buyfood, /buyweapons, /buyclothes, /buyitems, /haircut, /tattoo, /learnstyle", summary = "Be served at a shop: walk in, or ask the keeper",
      text = [[Walking onto a shop's counter marker opens its menu, as in the game; F there opens it again after you leave it. Each shop's command does the same from anywhere in the shop where you can see the keeper (who seats you), or at the counter of a shop without one (24/7, the gym trainers):
  /buyfood (Cluckin' Bell, Burger Shot, Well Stacked Pizza), /buyweapons (Ammu-Nation), /buyclothes, /buyitems (24/7), /haircut, /tattoo, /learnstyle (gyms).
In /interact, click the keeper for the same.]],
      see = { "controls", "use" } },
    { name = "spray", topic = true, summary = "Pay 'n' Spray: drive in and stop to get your vehicle fixed ($100)",
      text = [[Ten Pay 'n' Sprays, where vanilla has them (the spray can on the radar). Drive in and stop: the door comes down, the spray hisses, and your vehicle comes out repaired for $100. It only repairs: same colour, and your wanted level stays as it is. Nothing to fix, no charge. Mod garages repair too (Repair, at the top of their menu).]],
      see = { "garages" } },
    { name = "spraytest", console = true, usage = "spraytest", summary = "Self-test: Pay 'n' Sprays",
      text = [[Every spray's box holds its own middle, and a dented car counts as damaged until fixed.]] },
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
