-- One-time conversion of placement config (Lua tables) into MTA map resources, plus each owning
-- resource's EDF (Map Editor definition), generated from its dataset schema (config/maps.lua).
-- Checks the result: every table rebuilt from the written .map must equal the original.
-- The placement configs it converted are gone (the .map files are canonical now); it's kept for
-- re-seeding: a seed writes the old-style Lua table into a folder, this turns it into the .map
-- (replacing every element of that dataset, hand edits included).
-- usage (from the repo root): lua5.1 tools/convert/to_maps.lua --from <folder with the .lua files> [dataset ...]
dofile("vana-lib/lib/map_data.lua")

local DATASETS = {
    restarts = { owner = "vana-player", configs = { "vana-player/config/restarts.lua" } },
    cargens = { owner = "vana-parked", configs = { "vana-parked/config/cargens.lua" } },
    entrances = { owner = "vana-interiors", configs = { "vana-interiors/config/entrances.lua" } },
    shops = { owner = "vana-shops", configs = { "vana-shops/config/points.lua", "vana-shops/config/vendors.lua" }, notes = true },
    gym = { owner = "vana-gym", configs = { "vana-gym/config/equipment.lua" } },
    wildlife = { owner = "vana-wildlife", configs = { "bigfoot.lua" } },
    activities = { owner = "vana-activities", configs = { "vana-activities/config/minigames.lua",
        "vana-activities/config/burglary_houses.lua", "vana-activities/config/races.lua" }, notes = true },
}
local DATA_DIR = "[data]"

-- Trailing comments on entries become their `note`: keyed lines (NAME = { ... }, -- note) by name,
-- list lines ({ ... }, -- note) by position.
local function attachNotes(file, env)
    local keyed, listed = {}, {}
    for line in io.lines(file) do
        local name, note = line:match("^%s*([%w_]+)%s*=%s*{.*}%s*,?%s*%-%-%s*(.-)%s*$")
        if name then keyed[name] = note end
        local entry = line:match("^%s*{.*}%s*,?%s*%-%-%s*(.-)%s*$")
        if line:match("^%s*{") then listed[#listed + 1] = entry or false end
    end
    for _, t in pairs(env) do
        if type(t) == "table" then
            for k, v in pairs(t) do
                if type(v) == "table" and type(k) == "string" and keyed[k] then v.note = keyed[k] end
            end
            if #listed == #t and #t > 0 then
                for i, v in ipairs(t) do if type(v) == "table" and listed[i] then v.note = listed[i] end end
            end
        end
    end
end

local function xml(s)
    return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end
local function unxml(s)
    return (s:gsub("&quot;", '"'):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&"))
end

local function writeFile(path, text)
    os.execute(("mkdir -p %q"):format(path:match("^(.*)/")))
    local f = assert(io.open(path, "w"))
    f:write(text)
    f:close()
end

local function writeMap(dataset, records)
    local out = { '<map edf:definitions="' .. dataset.definition .. '">' }
    -- Spots (positions the rule configs use) come from no seed: keep the ones the map has.
    local dir = DATA_DIR .. "/" .. dataset.resource
    local keep = {}
    local existing = io.open(dir .. "/" .. dataset.file)
    if existing then
        for line in existing:lines() do
            local tag = line:match("^%s*<([%w_]+)%s")
            if tag and not records[tag] then
                for _, schema in ipairs(dataset.types) do
                    if schema.element == tag then keep[tag] = keep[tag] or {}; table.insert(keep[tag], line) end
                end
            end
        end
        existing:close()
    end
    for _, schema in ipairs(dataset.types) do
        out[#out + 1] = ("    <!-- %s -->"):format(schema.friendly)
        for _, line in ipairs(keep[schema.element] or {}) do out[#out + 1] = line end
        for _, rec in ipairs(records[schema.element] or {}) do
            local attrs = {}
            for _, a in ipairs(MapData.toAttributes(schema, rec)) do attrs[#attrs + 1] = ('%s="%s"'):format(a[1], xml(a[2])) end
            out[#out + 1] = ("    <%s %s />"):format(schema.element, table.concat(attrs, " "))
        end
    end
    out[#out + 1] = "</map>\n"
    writeFile(dir .. "/" .. dataset.file, table.concat(out, "\n"))
    writeFile(dir .. "/meta.xml", ([[
<meta>
    <info type="map" name="%s" author="ProjectVana" description="Placement data for %s: open it in the Map Editor (definitions: %s)" version="1.0.0" edf:definitions="%s" />
    <map src="%s" dimension="0" />
</meta>
]]):format(dataset.resource, dataset.definition, dataset.definition, dataset.definition, dataset.file))
    return dir .. "/" .. dataset.file
end

-- EDF data types for our field types.
local EDF_TYPES = { number = "number", int = "integer", bool = "selection:true,false", string = "string",
                    numbers = "string", ints = "string" }

local function writeEdf(owner, datasets)
    local out = { ('<def name="%s">'):format(owner) }
    local lines = false
    for _, dataset in ipairs(datasets) do
        for _, schema in ipairs(dataset.types) do
            out[#out + 1] = ('    <element name="%s" friendlyname="%s">'):format(schema.element, schema.friendly)
            out[#out + 1] = '        <data name="position" type="coord3d" default="0,0,0" />'
            if schema.rotation then out[#out + 1] = '        <data name="rotation" type="coord3d" default="0,0,0" />' end
            for _, f in ipairs(schema.fields) do
                local kind = f[2] == "ref" and ("element:" .. f[5]) or EDF_TYPES[f[2]]
                local default = f[3] == nil and "" or (type(f[3]) == "boolean" and tostring(f[3]) or tostring(f[3]))
                if f[2] == "ref" or f[1] == "ex" then lines = true end
                out[#out + 1] = ('        <data name="%s" type="%s" default="%s" required="false" description="%s" />')
                    :format(f[1], kind, xml(default), xml(f[4] or ""))
            end
            out[#out + 1] = "        " .. schema.rep
            out[#out + 1] = "    </element>"
        end
    end
    if lines then out[#out + 1] = '    <script src="edf/edf_lines_client.lua" type="client" />' end
    out[#out + 1] = "</def>\n"
    writeFile(owner .. "/edf/" .. owner .. ".edf", table.concat(out, "\n"))
    return lines
end

-- Reads a .map written above back into { [element] = records }, as the game will.
local function readMap(dataset, path)
    local byType = {}
    for _, schema in ipairs(dataset.types) do byType[schema.element] = {} end
    local schemas = {}
    for _, schema in ipairs(dataset.types) do schemas[schema.element] = schema end
    for line in io.lines(path) do
        local tag, body = line:match("^%s*<([%w_]+)%s(.-)/>%s*$")
        if tag and schemas[tag] then
            local attr = {}
            for k, v in body:gmatch('([%w_:]+)="(.-)"') do attr[k] = unxml(v) end
            table.insert(byType[tag], MapData.fromAttributes(schemas[tag], attr))
        end
    end
    return byType
end

local function same(a, b, path)
    if type(a) == "number" and type(b) == "number" then
        if math.abs(a - b) > 0.00051 then return false, path .. (": %s ~= %s"):format(a, b) end
        return true
    end
    if type(a) ~= type(b) then return false, path .. (": %s ~= %s"):format(tostring(a), tostring(b)) end
    if type(a) ~= "table" then
        if a ~= b then return false, path .. (": %s ~= %s"):format(tostring(a), tostring(b)) end
        return true
    end
    for k, v in pairs(a) do
        local ok, why = same(v, b[k], path .. "." .. tostring(k))
        if not ok then return false, why end
    end
    for k in pairs(b) do
        if a[k] == nil then return false, path .. "." .. tostring(k) .. ": extra" end
    end
    return true
end

local wanted, from = {}, nil
local i = 1
while arg[i] do
    if arg[i] == "--from" then from, i = arg[i + 1], i + 1 else wanted[arg[i]] = true end
    i = i + 1
end
if arg[1] == "--edf" then
    -- Only regenerate the EDFs from the datasets' schemas (after changing a config/maps.lua).
    local owners = {}
    for name, d in pairs(DATASETS) do
        dofile(d.owner .. "/config/maps.lua")
        owners[d.owner] = owners[d.owner] or {}
        table.insert(owners[d.owner], MapDatasets[name])
    end
    for owner, datasets in pairs(owners) do writeEdf(owner, datasets) print("edf/" .. owner .. ".edf") end
    os.exit(0)
end
assert(from, "usage: lua5.1 tools/convert/to_maps.lua --from <folder> [dataset ...] | --edf")
local owners, failed = {}, false
for name, d in pairs(DATASETS) do
    if not next(wanted) or wanted[name] then
        dofile(d.owner .. "/config/maps.lua")
        local dataset = MapDatasets[name]
        local original = {}
        for _, path in ipairs(d.configs) do
            local file = from .. "/" .. path:match("[^/]+$")
            local env = setmetatable({}, { __index = _G })
            setfenv(assert(loadfile(file)), env)()
            if d.notes then attachNotes(file, env) end
            for k, v in pairs(env) do original[k] = v end
        end
        local records = dataset.toRecords(original)
        local path = writeMap(dataset, records)
        local rebuilt = dataset.fromRecords(readMap(dataset, path))
        local count = 0
        for _, list in pairs(records) do count = count + #list end
        for global, value in pairs(rebuilt) do
            local ok, why = same(original[global], value, global)
            if not ok then failed = true print(("FAIL %s: %s"):format(name, why)) end
        end
        print(("%-10s %5d elements -> %s"):format(name, count, path))
        owners[d.owner] = owners[d.owner] or {}
        table.insert(owners[d.owner], dataset)
    end
end
for owner, datasets in pairs(owners) do
    local lines = writeEdf(owner, datasets)
    print(("%-16s edf/%s.edf%s"):format(owner, owner, lines and " (with path lines)" or ""))
end
print(failed and "FAIL" or "PASS: every table rebuilt from its .map equals the original")
os.exit(failed and 1 or 0)
