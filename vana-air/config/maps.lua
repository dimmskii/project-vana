-- Map data (vana-lib's map_data): aircraft, in vana-data-air, read by the server from its files
-- (air_data.lua). flights.map is converted from the game's carrec.img by
-- tools/convert/flights_to_maps.lua; airports.map and helis.map are ours.
if not AirData then dofile("vana-air/air_data.lua") end -- the converter (plain Lua)
local types = {}
for _, list in ipairs({ AirData.flightSchemas, AirData.airportSchemas, AirData.heliSchemas }) do
    for _, schema in ipairs(list) do types[#types + 1] = schema end
end
MapDatasets.air = {
    resource = AirData.resource, file = "airports.map", definition = "vana-air", types = types,
    fromRecords = function(t) return t end,
}

-- In the game (not the converter): flights, airports and their spots, taxi routes, circuits, heli spots.
if MapData.load then
    local data = MapData.load(MapDatasets.air)
    Flights = AirData.buildFlights(data.flightpath or {}, data.flightframe or {})
    Airports, AirSpots, TaxiRoutes, Circuits, HeliSpots = {}, {}, {}, {}, {}
    for _, a in ipairs(data.airport or {}) do Airports[a.id] = a end
    for _, s in ipairs(data.airspot or {}) do
        s.departs, s.arrives = AirData.list(s.departs), AirData.list(s.arrives)
        AirSpots[s.id] = s
    end
    for _, r in ipairs(data.taxiroute or {}) do
        r.points = {}
        for _, p in ipairs(MapData.follow(data.taxipoint or {}, r.first)) do r.points[#r.points + 1] = { p.x, p.y, p.z } end
        r.runways = AirData.list(r.runways)
        TaxiRoutes[#TaxiRoutes + 1] = r
    end
    for _, c in ipairs(data.circuit or {}) do
        c.points = {}
        for _, p in ipairs(MapData.follow(data.circuitpoint or {}, c.first)) do c.points[#c.points + 1] = { p.x, p.y, p.z, p.speed, p.ground } end
        Circuits[#Circuits + 1] = c
    end
    for _, h in ipairs(data.helispot or {}) do HeliSpots[#HeliSpots + 1] = h end
end
