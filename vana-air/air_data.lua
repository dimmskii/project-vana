-- Aircraft data as map data in [data]/vana-data-air, and back. Plain Lua: the converter
-- (tools/convert/flights_to_maps.lua) and the game share it.
--   flights.map   vanilla's flight recordings (data/Paths/carrec.img; the airport ticket desk's,
--                 main.scm PLANES): flightpath (one per recording) and its flightframes, converted
--   airports.map  ours, seeded from the ATP airport-traffic CLEO mod: airports, the spots planes wait
--                 at, taxi routes between them; Verdant Meadows' training circuit (the flight
--                 school's rings)
--   helis.map     ours: where news helicopters circle
AirData = {}

AirData.resource = "vana-data-air"

local fields = {
    flightpath = {
        { "from", "string", nil, "the airport it takes off from (airport id)" },
        { "to", "string", nil, "the airport it lands at" },
        { "gearUp", "int", nil, "ms into the flight the landing gear goes up" },
        { "gearDown", "int", nil, "ms into the flight it goes down for landing" },
        { "duration", "int", nil, "ms, wheels rolling to wheels stopped" },
    },
    flightframe = {
        { "path", "string", nil, "its flightpath id" },
        { "t", "int", 0, "ms into the flight" },
        { "fwd", "numbers", nil, "the plane's forward vector (x,y,z)" },
        { "right", "numbers", nil, "its right vector" },
        { "vel", "numbers", nil, "velocity, m/s (x,y,z)" },
    },
    airport = {
        { "name", "string", nil, "for logs and /air" },
    },
    airspot = {
        { "airport", "string", nil, "its airport (id)" },
        { "runway", "string", nil, "the runway it's on (one plane moves on a runway at a time)" },
        { "departs", "string", nil, "flightpaths that start here, comma-separated" },
        { "arrives", "string", nil, "flightpaths that end here, comma-separated" },
    },
    taxiroute = {
        { "from", "string", nil, "the airspot it leaves" },
        { "to", "string", nil, "the airspot it reaches" },
        { "first", "string", nil, "its first taxipoint (each links to the next with nextid)" },
        { "runways", "string", nil, "runways it rolls along, comma-separated (held while it taxis)" },
    },
    taxipoint = {
        { "nextid", "string", nil, "the next taxipoint, none at the end" },
    },
    circuit = {
        { "airport", "string", nil, "its airstrip (airport id)" },
        { "first", "string", nil, "its first circuitpoint" },
        { "models", "ints", nil, "the planes that fly it, one each (repeat a model for more)" },
    },
    circuitpoint = {
        { "nextid", "string", nil, "the next point, none at the end (the circuit starts over)" },
        { "speed", "number", 30, "m/s reaching it" },
        { "ground", "bool", false, "on the runway (wheels down)" },
    },
    helispot = {
        { "kind", "string", "news", "news: a news helicopter circles it" },
        { "radius", "number", 150, "m, the circle's radius" },
        { "city", "string", nil, "LS, SF or LV" },
    },
}

local function schema(element, friendly, extra, rep)
    local s = { element = element, friendly = friendly, position = true, id = "id", fields = fields[element], rep = rep }
    for k, v in pairs(extra or {}) do s[k] = v end
    return s
end

AirData.flightSchemas = {
    schema("flightpath", "Flight path (a vanilla flight recording)", nil, '<marker type="corona" size="3" color="#4080FFA0" />'),
    schema("flightframe", "Flight frame", nil, '<marker type="corona" size="0.8" color="#4080FF60" />'),
}
AirData.airportSchemas = {
    schema("airport", "Airport", nil, '<marker type="corona" size="4" color="#FFFFFF60" />'),
    schema("airspot", "Air spot (a plane waits here)", { rotation = "heading" }, '<marker type="corona" size="3" color="#40FF40A0" />'),
    schema("taxiroute", "Taxi route", nil, '<marker type="corona" size="1.5" color="#FFD040A0" />'),
    schema("taxipoint", "Taxi point", nil, '<marker type="corona" size="1" color="#FFD04080" />'),
    schema("circuit", "Circuit (planes fly it round and round)", nil, '<marker type="corona" size="3" color="#FF8040A0" />'),
    schema("circuitpoint", "Circuit point", nil, '<marker type="corona" size="2" color="#FF804080" />'),
}
AirData.heliSchemas = {
    schema("helispot", "Heli spot (a news helicopter circles it)", nil, '<marker type="corona" size="4" color="#FF40FFA0" />'),
}

-- "a,b,c" -> { "a", "b", "c" }
function AirData.list(s)
    local out = {}
    for part in tostring(s or ""):gmatch("[^,%s]+") do out[#out + 1] = part end
    return out
end

-- flightpath and flightframe records -> { [id] = { id, from, to, gearUp, gearDown, duration, frames } },
-- frames in time order: { t, x, y, z, fx, fy, fz, rx, ry, rz, vx, vy, vz, gear }.
function AirData.buildFlights(paths, frames)
    local out = {}
    for _, p in ipairs(paths) do
        out[p.id] = { id = p.id, from = p.from, to = p.to, gearUp = p.gearUp, gearDown = p.gearDown, duration = p.duration, frames = {} }
    end
    for _, f in ipairs(frames) do
        local flight = out[f.path]
        if flight and f.fwd and f.right then
            local v = f.vel or { 0, 0, 0 }
            table.insert(flight.frames, { t = f.t, x = f.x, y = f.y, z = f.z, fx = f.fwd[1], fy = f.fwd[2], fz = f.fwd[3],
                rx = f.right[1], ry = f.right[2], rz = f.right[3], vx = v[1], vy = v[2], vz = v[3] })
        end
    end
    for _, flight in pairs(out) do
        table.sort(flight.frames, function(a, b) return a.t < b.t end)
        for _, fr in ipairs(flight.frames) do
            fr.gear = not (flight.gearUp and fr.t >= flight.gearUp and (not flight.gearDown or fr.t < flight.gearDown))
        end
    end
    return out
end
