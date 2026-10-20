-- Map data (tools/lib/map_data.lua), in vana-data-activities: minigame objects, burglary houses and
-- doors, the race tournament's races and the Chiliad Challenge routes. Races and routes are paths:
-- each checkpoint links to the next (nextid), as in MTA race maps, and the editor draws them.
MapDatasets.activities = {
    -- clients: client scripts read it too, so it runs as a map resource (vana-lib's map_data)
    resource = "vana-data-activities", clients = true, file = "activities.map", definition = "vana-activities",
    types = {
        { element = "minigamespot", friendly = "Minigame object", position = true, rotation = "heading", interior = "interior",
          fields = {
              { "kind", "string", "slot", "the minigame (slot, videopoker, roulette, blackjack, wheel, betting, arcade, basketball, pool)" },
              { "model", "string", "", "the map object it belongs to" },
          },
          rep = '<marker type="corona" size="0.8" color="#00FF8080" />' },
        { element = "burglaryhouse", friendly = "Burglary house", position = true, interior = "interior", id = "name",
          fields = {
              { "ex", "number", 0, "arrival point x inside" }, { "ey", "number", 0, "arrival point y" },
              { "ez", "number", 0, "arrival point z" }, { "heading", "number", 0, "facing on arrival" },
          },
          rep = '<marker type="arrow" size="1" color="#FFAA00AA" />' },
        { element = "burglarydoor", friendly = "Burglary door", position = true,
          fields = {
              { "house", "ref", "", "the burglaryhouse it leads into", "burglaryhouse" },
              { "ex", "number", 0, "where you come back out x" }, { "ey", "number", 0, "y" }, { "ez", "number", 0, "z" },
              { "heading", "number", 0, "facing coming out" },
              { "note", "string", nil, "free-form note (seeded: the map model the door belongs to)" },
          },
          rep = '<marker type="arrow" size="0.8" color="#FFDC0080" />' },
        { element = "race", friendly = "Race", position = true, id = "id",
          fields = {
              { "index", "int", 0, "vanilla's race number (name: GXT RACE00..)" },
              { "racers", "int", 6, "racers, you included" },
              { "laps", "int", 1, "laps" },
              { "cars", "ints", "", "your car, then the opponents'" },
              { "grid", "bool", false, "this element is the starting grid (stadium races); else the start is the first checkpoint" },
              { "gridHeading", "number", 0, "facing on the grid" },
              { "first", "ref", "", "the first racecheckpoint", "racecheckpoint" },
          },
          rep = '<marker type="cylinder" size="4" color="#FFC80080" />' },
        { element = "racecheckpoint", friendly = "Race checkpoint", position = true, id = "id",
          fields = {
              { "race", "ref", "", "the race it belongs to", "race" },
              { "nextid", "ref", "", "the next checkpoint (none: the finish)", "racecheckpoint" },
          },
          rep = '<marker type="checkpoint" size="6" color="#FFD200A0" />' },
        { element = "chiliadroute", friendly = "Chiliad Challenge route", position = true, id = "id",
          fields = {
              { "index", "int", 1, "route number (1-3)" },
              { "first", "ref", "", "the first routepoint", "routepoint" },
          },
          rep = '<marker type="cylinder" size="4" color="#80FF0080" />' },
        { element = "routepoint", friendly = "Route point", position = true, id = "id",
          fields = {
              { "route", "ref", "", "the route it belongs to", "chiliadroute" },
              { "nextid", "ref", "", "the next point (none: the finish)", "routepoint" },
          },
          rep = '<marker type="checkpoint" size="6" color="#80FF00A0" />' },
        MapData.spotSchema,
    },

    toRecords = function(g)
        local spots, houses, doors = {}, {}, {}
        for _, m in ipairs(g.MinigameSpots) do
            spots[#spots + 1] = { kind = m.kind, model = m.model, interior = m.interior, x = m.x, y = m.y, z = m.z, heading = m.heading }
        end
        local names = {}
        for name in pairs(g.BurglaryHouses) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do
            local h = g.BurglaryHouses[name]
            houses[#houses + 1] = { name = name, interior = h.interior, x = h.x, y = h.y, z = h.z, ex = h.ex, ey = h.ey, ez = h.ez, heading = h.heading }
        end
        for _, d in ipairs(g.BurglaryDoors) do
            doors[#doors + 1] = { house = d.house, note = d.note, x = d.x, y = d.y, z = d.z, ex = d.ex, ey = d.ey, ez = d.ez, heading = d.heading }
        end

        local races, checkpoints = {}, {}
        for index = 0, 99 do
            local r = g.RaceTable[index]
            if r then
                local id = "race" .. index
                local first = r.checkpoints[1]
                local at = r.start or first
                races[#races + 1] = { id = id, index = index, racers = r.racers, laps = r.laps, cars = r.cars,
                    grid = r.start ~= nil, gridHeading = r.start and r.start[4] or nil,
                    first = id .. "cp1", x = at[1], y = at[2], z = at[3] }
                for i, cp in ipairs(r.checkpoints) do
                    checkpoints[#checkpoints + 1] = { id = id .. "cp" .. i, race = id,
                        nextid = r.checkpoints[i + 1] and (id .. "cp" .. (i + 1)) or nil, x = cp[1], y = cp[2], z = cp[3] }
                end
            end
        end
        local routes, points = {}, {}
        for index, route in ipairs(g.ChiliadRoutes) do
            local id = "chiliad" .. index
            routes[#routes + 1] = { id = id, index = index, first = id .. "p1", x = route[1][1], y = route[1][2], z = route[1][3] }
            for i, p in ipairs(route) do
                points[#points + 1] = { id = id .. "p" .. i, route = id,
                    nextid = route[i + 1] and (id .. "p" .. (i + 1)) or nil, x = p[1], y = p[2], z = p[3] }
            end
        end
        return { minigamespot = spots, burglaryhouse = houses, burglarydoor = doors,
                 race = races, racecheckpoint = checkpoints, chiliadroute = routes, routepoint = points }
    end,

    fromRecords = function(t)
        local spots, houses, doors = {}, {}, {}
        for _, r in ipairs(t.minigamespot) do
            spots[#spots + 1] = { kind = r.kind, model = r.model, interior = r.interior, x = r.x, y = r.y, z = r.z, heading = r.heading }
        end
        for _, r in ipairs(t.burglaryhouse) do
            houses[r.name] = { interior = r.interior, x = r.x, y = r.y, z = r.z, ex = r.ex, ey = r.ey, ez = r.ez, heading = r.heading }
        end
        for _, r in ipairs(t.burglarydoor) do
            doors[#doors + 1] = { house = r.house, note = r.note, x = r.x, y = r.y, z = r.z, ex = r.ex, ey = r.ey, ez = r.ez, heading = r.heading }
        end
        local races = {}
        for _, r in ipairs(t.race) do
            local checkpoints = {}
            for i, cp in ipairs(MapData.follow(t.racecheckpoint, r.first)) do checkpoints[i] = { cp.x, cp.y, cp.z } end
            races[r.index] = { racers = r.racers, laps = r.laps, cars = r.cars, checkpoints = checkpoints,
                start = r.grid and { r.x, r.y, r.z, r.gridHeading } or nil }
        end
        local routes = {}
        for _, r in ipairs(t.chiliadroute) do
            local list = {}
            for i, p in ipairs(MapData.follow(t.routepoint, r.first)) do list[i] = { p.x, p.y, p.z } end
            routes[r.index] = list
        end
        return { MinigameSpots = spots, BurglaryHouses = houses, BurglaryDoors = doors, RaceTable = races, ChiliadRoutes = routes,
                 SpotRecords = t.spot or {} }
    end,
}

-- In the game (not the converter): the tables the code uses.
if MapData.load then
    local data = MapData.load(MapDatasets.activities)
    MinigameSpots = data.MinigameSpots
    BurglaryHouses = data.BurglaryHouses
    BurglaryDoors = data.BurglaryDoors
    RaceTable = data.RaceTable
    ChiliadRoutes = data.ChiliadRoutes
    -- Positions the rule configs (jobs.lua, racing.lua, ...) take from the map: At(id), Spots(set).
    At, Spots = MapData.spotFunctions(data.SpotRecords)
end
