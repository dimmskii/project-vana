# Map (`vana-map`)

One place for everything on the map. Resources publish permanent points; `vana-map` turns them into
radar blips with vanilla's icons, and is where legends, category filters and GPS will live.

## Publishing points

- Import `map_points` from `vana-lib` (see [libraries.md](libraries.md)). Then
  `MapPoints.set(id, point)` and `MapPoints.remove(id)`.
- A point is `{ category = "...", x, y, z, interior = 0, label = "..." }`, or `{ tag = "<enex name>", ... }`
  for doors: `vana-map` decides the category from the tag (`MapEntranceCategories`) and ignores tags
  it has no category for.
- It doesn't matter which starts first: points are kept by the provider and published whenever
  `vana-map` starts; a provider that stops takes its points with it.
- Personal, temporary blips (an activity's targets, a player's girlfriends' homes) stay with the
  activity; the map is for the world's permanent places.

## Categories (`config/categories.lua`)

Icon (vanilla radar sprite), legend name, and short range (shows within `MapShortRange` metres, as
vanilla's shop icons do) or map-wide.

| From | Points |
| --- | --- |
| `vana-interiors` (street doors) | Ammu-Nation, barbers, tattoo parlours, clothes shops, Burger Shot, Cluckin' Bell, Well Stacked Pizza, restaurants, diners, bars, clubs, gyms, casinos, the driving school |
| `vana-vehicles` | Gas stations (the 16 pumps) |
| `vana-shops` | Mod garages, Pay 'n' Sprays |
| `vana-activities` | Race entries, stadium events, the Chiliad Challenge, triathlons, schools (bike, boat, flight), trucking, the quarry, courier pick-ups, the lowrider contest |

`maptest` (console) counts the points by category.

## Client

`vana-map/client.lua` draws each point as a local blip (so each player can see a different set) in
its interior only. `Map.setHidden(category, true)` hides a category for this player: the hook for a
legend / filter screen.

## The map (F11, `mapview_client.lua`)

Ours, in place of MTA's: MTA's map is switched off and its key commands (`radar`, `radar_zoom_in/out`,
`radar_move_north/south/east/west`, `radar_attach`, `radar_help`) are taken over. They're MTA "mod
commands": disabled with `toggleControl`, they reach script command handlers instead, so whatever the
player binds to them (F11, the numpad) opens and drives ours. `radar_opacity_*` aren't: ours is opaque.

- **Imagery:** GTA's 144 radar tiles (`radar00`–`radar143`, 500 m squares, `radar00` the north-west
  corner) read with `sa_txd`, and the blip sprites from `hud.txd`, both in `data/` (extracted at setup:
  `tools/seed/extract_radar.py`). Full screen, opaque.
- **On it:** every blip in your dimension and interior (all of them, short-range or not: filters will
  come from the legend), at a smaller size than MTA's; radar areas; you (the radar's arrow, turned your
  way); north; the GPS route. Squares (icon 0 and 1) in the blip's colour. Hovering a blip names it.
- **Moving around:** the cursor starts in the middle of the screen. The move keys pan while held and put
  the cursor back in the middle (the view follows the spot it was on); the mouse takes it anywhere. Left
  drag moves the map; the wheel (or the zoom keys, held) zooms on the cursor, so you can creep across
  the map by zooming. `radar_attach` follows you.
- **Legend:** top right: you, the destination, and each category with points (its icon and name).
- **GPS:** right click or Space asks the server for a route (`vana-map:route`) from you to the road
  nearest the spot, along the vehicle paths (vana-paths' `findRoute`: weighted A*, about 75 ms for the
  longest routes across the map). The route is drawn on the map, and a waypoint blip (41) of your own
  marks the end, on the radar too; it goes when you're within 30 m, or when you right-click the
  destination again. `routetest` (console) routes across the map.

## Our icons on the radar

MTA blips only take vanilla's 64 icons. A category with an `image` of ours borrows an icon the game
never shows (the story's contacts: 18 is Emmet's gun) and each client replaces that sprite with the
image (`texreplace.fx`, a shader on the sprite's texture), so the radar shows ours; the map draws the
image itself. Gas stations (`gasstation`, from vana-vehicles' pumps) are the first:
`vana-vehicles/icons/radar_gasstn.png`.

## Not yet

Filters from the legend (and saving them per player), a radar of our own drawn the same way (smaller
blips, the route on it), Neon's extended world (radar tiles past the vanilla square: the map covers
only the vanilla 6000 m), and places whose features don't exist yet (safehouses and properties).
