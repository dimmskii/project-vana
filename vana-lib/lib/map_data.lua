-- Map data: placement data lives in MTA map files (.map, editable in the Map Editor through each
-- resource's EDF) inside vana-data-* map resources; this turns their elements back into the Lua
-- tables the code uses. A schema describes one element type:
--   { element = "cargen", friendly = "Car generator",
--     position = true,          -- posX/posY/posZ <-> x, y, z
--     rotation = "heading",     -- rotZ <-> this key (degrees)
--     interior = "interior",    -- the element's interior <-> this key
--     id = "name",              -- the element's id <-> this key (and keyed results, see MapData.read)
--     fields = { { "model", "int", -1, "description" }, ... } }
-- Field types: number, int, bool, string, numbers / ints (comma lists), ref (another element's id;
-- the field's 5th entry names the element type it points at, for the editor).
-- Copied into each resource that reads map data (tools/sync-libs.sh); keep the copies identical.
MapData = MapData or {}

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function decode(kind, raw)
    if raw == nil or raw == false or raw == "" then return nil end
    raw = tostring(raw)
    if kind == "number" or kind == "int" then return tonumber(raw)
    elseif kind == "bool" then return raw == "true"
    elseif kind == "numbers" or kind == "ints" then
        local list = {}
        for part in raw:gmatch("[^,]+") do list[#list + 1] = tonumber(trim(part)) end
        return list
    end
    return raw -- string, ref
end

local function encode(kind, value)
    if value == nil then return nil end
    if kind == "numbers" or kind == "ints" then
        local parts = {}
        for i, v in ipairs(value) do parts[i] = MapData.number(v) end
        return table.concat(parts, ",")
    elseif kind == "number" or kind == "int" then return MapData.number(value)
    elseif kind == "bool" then return value and "true" or "false"
    end
    return tostring(value)
end

-- Numbers as short as they can be without losing what the configs held (4 decimals).
function MapData.number(v)
    if v == math.floor(v) and math.abs(v) < 1e15 then return string.format("%d", v) end
    return (string.format("%.4f", v):gsub("0+$", ""):gsub("%.$", ""))
end

-- One element's attributes (name -> string) -> the Lua record the code expects.
function MapData.fromAttributes(schema, attr)
    local rec = {}
    if schema.position then
        rec.x, rec.y, rec.z = tonumber(attr.posX), tonumber(attr.posY), tonumber(attr.posZ)
    end
    if schema.rotation then rec[schema.rotation] = tonumber(attr.rotZ) or 0 end
    if schema.interior then rec[schema.interior] = tonumber(attr.interior) or 0 end
    if schema.id then rec[schema.id] = attr.id end
    for _, f in ipairs(schema.fields) do
        local value = decode(f[2], attr[f[1]])
        if value == nil and f[3] ~= nil then value = decode(f[2], f[3]) end
        rec[f[1]] = value
    end
    return rec
end

-- A Lua record -> attributes (for the converter and seeds), in schema order.
function MapData.toAttributes(schema, rec)
    local list = {}
    local function add(name, value) if value ~= nil then list[#list + 1] = { name, value } end end
    if schema.id then add("id", rec[schema.id]) end
    if schema.position then
        add("posX", MapData.number(rec.x)); add("posY", MapData.number(rec.y)); add("posZ", MapData.number(rec.z))
    end
    if schema.rotation then add("rotX", "0"); add("rotY", "0"); add("rotZ", MapData.number(rec[schema.rotation] or 0)) end
    if schema.interior then add("interior", MapData.number(rec[schema.interior] or 0)) end
    for _, f in ipairs(schema.fields) do add(f[1], encode(f[2], rec[f[1]])) end
    return list
end

-- Records of a linked path: from the record with id `firstId`, following each one's `nextid`.
function MapData.follow(records, firstId)
    local byId = {}
    for _, rec in ipairs(records) do if rec.id then byId[rec.id] = rec end end
    local list, seen, rec = {}, {}, byId[firstId]
    while rec and not seen[rec] do
        seen[rec] = true
        list[#list + 1] = rec
        rec = rec.nextid and byId[rec.nextid]
    end
    return list
end

-- Spots: world positions the rule configs (config/jobs.lua, ...) use, kept as `spot` elements so the
-- editor can move them, while everything else about them stays in the Lua config:
--   At("Jobs.trucking.start")                      -> { x, y, z }        (array spots, plus [4] = w if any)
--   At("Jobs.freight.stations.1", { forward = ... }) -> the given table with the position filled in
--   At("Dating.girls.1.car", { model = 400, ... })  -> named spots fill x, y, z instead
--   Spots("Jobs.trucking.destinations")            -> every spot of that set, in index order
MapData.spotSchema = { element = "spot", friendly = "Spot (a position the activity rules use)", position = true,
    interior = "interior", id = "id",
    fields = {
        { "set", "string", nil, "the list it belongs to (e.g. Jobs.trucking.destinations); empty for a single spot" },
        { "index", "int", nil, "its place in the set's list" },
        { "shape", "string", "array", "array: { x, y, z } in Lua; named: x =, y =, z =" },
        { "w", "number", nil, "a 4th value after x, y, z (a heading, radius or points, as the rules use it)" },
        { "path", "bool", false, "the set is a route (the editor draws it in index order)" },
        { "note", "string", nil, "free-form note" },
    },
    rep = '<marker type="corona" size="1.2" color="#B060FFA0" />' }

-- The At / Spots functions over a list of spot records.
function MapData.spotFunctions(records)
    local byId, sets = {}, {}
    for _, r in ipairs(records) do
        byId[r.id] = r
        if r.set then
            sets[r.set] = sets[r.set] or {}
            table.insert(sets[r.set], r)
        end
    end
    for _, list in pairs(sets) do table.sort(list, function(a, b) return (a.index or 0) < (b.index or 0) end) end
    local function fill(r, t)
        t = t or {}
        if r.shape == "named" then
            t.x, t.y, t.z = r.x, r.y, r.z
        else
            t[1], t[2], t[3] = r.x, r.y, r.z
            if r.w then t[4] = r.w end
        end
        return t
    end
    local function At(id, extras)
        local r = byId[id]
        if not r then error("no spot " .. tostring(id) .. " in the map data", 2) end
        return fill(r, extras)
    end
    local function Spots(set)
        local out = {}
        for i, r in ipairs(sets[set] or {}) do out[i] = fill(r) end
        if #out == 0 then error("no spots in set " .. tostring(set) .. " in the map data", 2) end
        return out
    end
    return At, Spots
end

-- A dataset (each owning resource's config/maps.lua): its element schemas, where they live, and
-- the conversion between element records and the tables the code uses:
--   { resource, file, definition, types = { schema, ... }, clients = true?,
--     toRecords = fn(globals) -> { [element] = records },   -- for the converter and seeds
--     fromRecords = fn({ [element] = records }) -> globals } -- e.g. { CarGenerators = {...} }
-- Where the game reads it from (MapData.load): a dataset clients read too (`clients`: its tables on
-- both sides, as the client scripts load) is a running map resource, read from its elements; any
-- other is read by the server straight from the resource's .map files, the resource never started,
-- so nothing of it goes to players.
MapDatasets = MapDatasets or {}

-- In MTA: every element of the schema's type in the dataset's map resource, as records. keyed: by id.
if getElementsByType then
    local ATTRIBUTES = { "id", "posX", "posY", "posZ", "rotZ", "interior" }

    local function attributesOf(element, schema)
        local attr = {}
        for _, name in ipairs(ATTRIBUTES) do attr[name] = getElementData(element, name) end
        attr.id = getElementID(element) ~= "" and getElementID(element) or attr.id
        if not attr.posX then
            local x, y, z = getElementPosition(element)
            attr.posX, attr.posY, attr.posZ = x, y, z
        end
        if not attr.interior then attr.interior = getElementInterior(element) end
        for _, f in ipairs(schema.fields) do attr[f[1]] = getElementData(element, f[1]) end
        return attr
    end

    function MapData.elements(schema, resourceName)
        local res = getResourceFromName(resourceName)
        local root = res and getResourceRootElement(res)
        if not root then
            outputDebugString(("[MapData] %s is not running: no %s data"):format(tostring(resourceName), schema.element), 1)
            return {}
        end
        return getElementsByType(schema.element, root)
    end

    function MapData.read(schema, resourceName, keyed)
        local out = {}
        for _, element in ipairs(MapData.elements(schema, resourceName)) do
            local rec = MapData.fromAttributes(schema, attributesOf(element, schema))
            if keyed then out[rec[schema.id]] = rec else out[#out + 1] = rec end
        end
        return out
    end

    -- A map resource's elements read from its .map files (it needn't run): element name -> list
    -- of attribute tables (strings, as written), in file order. Server only: clients can't read
    -- another resource's files. False when the resource or its files are missing. Reading another
    -- resource's files takes general.ModifyOtherObjects, so vana-lib alone holds it and reads for
    -- everyone (its mapFileElements export, server.lua).
    function MapData.readMapFiles(resourceName)
        if localPlayer then return false end
        if not getResourceFromName(resourceName) then
            outputServerLog(("[MapData] WARNING: no resource %s: its data is missing (see docs/setup.md)"):format(tostring(resourceName)))
            return false
        end
        local meta = xmlLoadFile(":" .. resourceName .. "/meta.xml", true)
        if not meta then
            outputServerLog(("[MapData] WARNING: can't read %s/meta.xml: its data is missing"):format(resourceName))
            return false
        end
        local files = {}
        for _, node in ipairs(xmlNodeGetChildren(meta)) do
            if xmlNodeGetName(node) == "map" then files[#files + 1] = xmlNodeGetAttribute(node, "src") end
        end
        xmlUnloadFile(meta)
        local byName = {}
        for _, path in ipairs(files) do
            local root = xmlLoadFile(":" .. resourceName .. "/" .. path, true)
            if not root then
                outputServerLog(("[MapData] WARNING: %s/%s is missing or unreadable: its data is missing"):format(resourceName, path))
            else
                for _, node in ipairs(xmlNodeGetChildren(root)) do
                    local name = xmlNodeGetName(node)
                    byName[name] = byName[name] or {}
                    table.insert(byName[name], xmlNodeGetAttributes(node))
                end
                xmlUnloadFile(root)
            end
        end
        return byName
    end

    function MapData.fileElements(resourceName)
        if localPlayer then return false end
        if getResourceName(getThisResource()) == "vana-lib" then return MapData.readMapFiles(resourceName) end
        local lib = getResourceFromName("vana-lib")
        if not lib or getResourceState(lib) ~= "running" then
            outputServerLog(("[MapData] WARNING: vana-lib isn't running: no data from %s"):format(tostring(resourceName)))
            return false
        end
        return exports["vana-lib"]:mapFileElements(resourceName)
    end

    -- The schema's records from a resource's .map files (see fileElements).
    function MapData.readFile(schema, resourceName, keyed, elements)
        elements = elements or MapData.fileElements(resourceName) or {}
        local out = {}
        for _, attr in ipairs(elements[schema.element] or {}) do
            local rec = MapData.fromAttributes(schema, attr)
            if keyed then out[rec[schema.id]] = rec else out[#out + 1] = rec end
        end
        return out
    end

    -- The dataset's tables (e.g. { CarGenerators = {...} }): from its running map resource's
    -- elements if clients read it too, else from its .map files on the server.
    function MapData.load(dataset)
        local byType = {}
        local elements = not dataset.clients and MapData.fileElements(dataset.resource)
        for _, schema in ipairs(dataset.types) do
            if dataset.clients then byType[schema.element] = MapData.read(schema, dataset.resource)
            else byType[schema.element] = MapData.readFile(schema, dataset.resource, false, elements or {}) end
        end
        return dataset.fromRecords(byType)
    end
end
