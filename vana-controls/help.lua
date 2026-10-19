-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "controls", topic = true, summary = "Using things: /use, /interact and the action commands",
      text = [[Two keys do everything that isn't driving or fighting:
  /use (F and Enter): what the box at the top left says, where you stand: order at a counter, play a machine, pick something up. Next to a car with nothing else here, it's the game's own enter/exit.
  /interact (F1): the cursor and a command box. Click a car, a person or a player for what you can do to them, or type a command.

Every action is a command too (/engine, /lights, /givemoney, /buyfood...), so you can type it or bind it to a key (Settings > Binds, or bind <key> <command> in the console). Without a target it uses what you're looking at, else the nearest thing it can; #id (shown in /interact) or a player's name picks one.

Any action needs you close enough, in sight, in the same place. Rebind /use and /interact under vana-controls in Settings > Binds.]],
      see = { "use", "interact", "givemoney" } },
    { name = "use", usage = "/use", summary = "Use what's here (F / Enter)",
      text = [[Does what the help box says, where you stand: order food, buy at Ammu-Nation, play a machine, get off gym equipment, pick up loot. With nothing offered, the key is the game's enter/exit again (cars).

Bound to F and Enter; a third or a pad button can be added in Settings > Binds (vana-controls).]],
      see = { "controls", "interact" } },
    { name = "interact", usage = "/interact", summary = "Pick something with the cursor, or type a command (F1)",
      text = [[Opens the cursor and a command box at the bottom.
  Point at a car, a person or a player: it glows. Click it for its menu (the arrow keys and Enter work too).
  An entry that needs more (an amount) puts its command in the box: type the rest, Enter.
  Typing offers matching commands: Enter takes the highlighted one, Tab completes it.
  Escape closes the menu, then the box; F1 again closes it.]],
      see = { "controls", "use" } },
    { name = "preferences", aliases = { "prefs" }, usage = "/preferences", summary = "Your own settings (F9)",
      text = [[Opens or closes the preferences panel: Up/Down to choose, Left/Right (or Enter, or a click) to change, Backspace to close. Changes apply at once and stay on your computer.
  HUD > Map: the blip size on the map (F11).
  HUD > Minimap: the radar's rotation, blip size, and how far away nearby icons (shops, gas stations) show.]],
      see = { "controls", "map" } },
    { name = "givemoney", aliases = { "pay" }, usage = "/givemoney <amount> [player or #id]", summary = "Give cash to a player beside you",
      text = [[Hands the amount to the player you name, or the one you're looking at. They must be within 4 m and in sight. Both of you are saved at once.]],
      see = { "controls" } },
}

function getHelpPages() return HelpPages end
