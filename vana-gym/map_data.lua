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

-- A dataset (each owning resource's config/maps.lua): its element schemas, where they live, and
-- the conversion between element records and the tables the code uses:
--   { resource, file, definition, types = { schema, ... },
--     toRecords = fn(globals) -> { [element] = records },   -- for the converter and seeds
--     fromRecords = fn({ [element] = records }) -> globals } -- e.g. { CarGenerators = {...} }
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

    -- The dataset's tables, built from its map resource's elements (e.g. { CarGenerators = {...} }).
    function MapData.load(dataset)
        local byType = {}
        for _, schema in ipairs(dataset.types) do byType[schema.element] = MapData.read(schema, dataset.resource) end
        return dataset.fromRecords(byType)
    end
end
