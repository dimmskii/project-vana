-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "map", topic = true, summary = "The map (F11): legend, zoom, GPS",
      text = [[F11 (or whatever you bind to the map in Settings > Binds) opens the map; F11 again or Escape closes it.
  Mouse: move the cursor, drag with the left button to move the map, wheel to zoom on the cursor.
  Right click, or Space: plan a route to the road nearest that spot (the line on the map, a waypoint on your radar). Again on the destination: no route.
  Numpad 8/4/2/6: move (the cursor goes back to the middle); +/-: zoom; 0: follow yourself; 1: the help line.
The legend lists what's on the map. Every point shows on the map; shops, gas stations and the like only show on the radar nearby.]],
      see = { "controls" } },
    { name = "maptest", usage = "maptest", console = true, summary = "Self-test: map points",
      text = [[Checks the map point categories and blips.]],
    },
}

function getHelpPages() return HelpPages end
