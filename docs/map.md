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
| `vana-activities` | Race entries, stadium events, the Chiliad Challenge, triathlons, schools (bike, boat, flight), trucking, the quarry, courier pick-ups, the lowrider contest |

`maptest` (console) counts the points by category.

## Client

`vana-map/client.lua` draws each point as a local blip (so each player can see a different set) in
its interior only. `Map.setHidden(category, true)` hides a category for this player: the hook for a
legend / filter screen.

## Not yet

Legend and filter UI, GPS routes, saving a player's filters, and places whose features don't exist
yet (Pay 'n' Spray, mod garages, safehouses and properties).
