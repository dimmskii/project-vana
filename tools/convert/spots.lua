-- One-time move of the world positions inside rule configs (config/jobs.lua, ...) into `spot`
-- elements of the owner's map resource, rewriting the config to read them back with At / Spots
-- (tools/lib/map_data.lua). Everything that isn't a position stays in the Lua, comments included.
-- Writes nothing unless the rewritten configs, run against the new spots, equal the originals.
-- usage (from the repo root): lua5.1 tools/convert/spots.lua [--write]
dofile("tools/lib/map_data.lua")

-- What moves: Lua patterns over dotted config paths. list: a list of plain positions becomes
-- Spots(path) (the map owns the list); point: one position becomes At(path, { rest }).
-- path: the list is a route. interior: the editor's interior for these spots (display only).
local OWNERS = {
    {
        owner = "vana-activities", map = "[data]/vana-data-activities/activities.map",
        files = { "vana-activities/config/jobs.lua", "vana-activities/config/racing.lua", "vana-activities/config/dating.lua",
                  "vana-activities/config/games.lua", "vana-activities/config/burglary.lua", "vana-activities/config/schools.lua" },
        rules = {
            { "^Jobs%.courier%.cities%.%d+%.drops$", "list" },
            { "^Jobs%.courier%.cities%.%d+%.base$", "point" }, { "^Jobs%.courier%.cities%.%d+%.back$", "point" },
            { "^Jobs%.freight%.stations%.%d+$", "point" },
            { "^Jobs%.paramedic%.hospitals$", "list" },
            { "^Jobs%.quarry%.bombs%.items%.%d+$", "point" }, { "^Jobs%.quarry%.rocks%.items%.%d+$", "point" },
            { "^Jobs%.quarry%.%a+%.items%.%d+%.target$", "point" },
            { "^Jobs%.quarry%.tracks%.items$", "list" },
            { "^Jobs%.quarry%.bodies%.%a+$", "point" }, { "^Jobs%.quarry%.cop%.%a+$", "point" },
            { "^Jobs%.quarry%.thieves%.dumper$", "point" }, { "^Jobs%.quarry%.explosives%.airstrip$", "point" },
            { "^Jobs%.quarry%.depot$", "point" }, { "^Jobs%.quarry%.entrance$", "point" }, { "^Jobs%.quarry%.start$", "point" },
            { "^Jobs%.trucking%.destinations$", "list" },
            { "^Jobs%.trucking%.income%.pickup$", "point" }, { "^Jobs%.trucking%.start$", "point" },
            { "^Jobs%.trucking%.truckSpot$", "point" }, { "^Jobs%.trucking%.trailerSpot$", "point" },
            { "^Racing%.entries%.%d+$", "point" }, { "^Racing%.stadiumCars%.%d+$", "point" },
            { "^Racing%.kickstart%.coronas$", "list", interior = "Racing.kickstart.interior" },
            { "^Racing%.kickstart%.start$", "point", interior = "Racing.kickstart.interior" },
            { "^Racing%.kickstart%.exit$", "point" },
            { "^Racing%.bloodring%.grid$", "list", interior = "Racing.bloodring.interior" },
            { "^Racing%.bloodring%.player$", "point", interior = "Racing.bloodring.interior" },
            { "^Racing%.bloodring%.entry$", "point" }, { "^Racing%.chiliad%.entry$", "point" },
            { "^Racing%.stunts%.%a+%.coronas$", "list" }, { "^Racing%.stunts%.%a+%.start$", "point" },
            { "^Racing%.stunts%.entries%.%a+$", "point" },
            { "^Racing%.triathlon%.%a+%.checkpoints$", "list", path = true }, { "^Racing%.triathlon%.entries%.%a+$", "point" },
            { "^Dating%.girls%.%d+%.home$", "point" },
            { "^Dating%.girls%.%d+%.meet$", "point" }, { "^Dating%.girls%.%d+%.car$", "point" },
            { "^Dating%.venues%.%a+$", "list" },
            { "^Games%.range%.ranges%.%d+%.booth$", "point", interior = "..interior" },
            { "^Games%.range%.ranges%.%d+%.entry$", "point", interior = "..interior" },
            { "^Games%.dance%.floors%.%d+$", "point" }, { "^Games%.lowrider$", "point" },
            { "^Burglary%.lockups%.%d+$", "point" }, { "^Burglary%.lockups%.%d+%.park$", "point" },
            { "^Schools%.%a+%.menu$", "point" }, { "^Schools%.%a+%.start$", "point" },
            { "^Schools%.%a+%.rewards%.%d+$", "point" },
            { "^Schools%.%a+%.tests%.%d+%.from$", "point" }, { "^Schools%.%a+%.tests%.%d+%.via$", "point" },
            { "^Schools%.flight%.tests%.%d+%.target$", "point" },
            { "^Schools%.flight%.tests%.%d+%.rings$", "list", path = true },
            { "^Schools%.flight%.tests%.%d+%.trucks$", "list" },
        },
    },
    {
        owner = "vana-player", map = "[data]/vana-data-player/player.map",
        files = { "vana-player/config/player.lua" },
        rules = { { "^PlayerConfig%.start%.spawn$", "point" } },
    },
}

---------------------------------------------------------------------------------------------------
-- A small parser for config files: table constructors with exact source spans.

local function parser(src)
    local pos = 1
    local P = {}
    local function skip()
        while true do
            local s, e = src:find("^%s+", pos)
            if s then pos = e + 1 end
            if src:sub(pos, pos + 3) == "--[[" then
                local _, ce = src:find("]]", pos + 4, true); pos = ce + 1
            elseif src:sub(pos, pos + 1) == "--" then
                local nl = src:find("\n", pos, true); pos = nl and nl + 1 or #src + 1
            else
                return
            end
        end
    end
    local function stringEnd(at)
        local q = src:sub(at, at)
        local i = at + 1
        while true do
            local c = src:sub(i, i)
            if c == "\\" then i = i + 2 elseif c == q then return i else i = i + 1 end
        end
    end
    -- A value: a table (parsed), or anything up to the next , ; } at depth 0.
    function P.value()
        skip()
        if src:sub(pos, pos) == "{" then return P.table() end
        local s, depth = pos, 0
        while pos <= #src do
            local c = src:sub(pos, pos)
            if c == '"' or c == "'" then pos = stringEnd(pos) + 1
            elseif src:sub(pos, pos + 1) == "--" then break
            elseif c == "(" or c == "[" then depth = depth + 1; pos = pos + 1
            elseif c == ")" or c == "]" then depth = depth - 1; pos = pos + 1
            elseif depth == 0 and (c == "," or c == ";" or c == "}" or c == "\n") then break
            else pos = pos + 1 end
        end
        local e = pos - 1
        while src:sub(e, e):match("%s") do e = e - 1 end
        return { s = s, e = e }
    end
    function P.table()
        local node = { s = pos, fields = {} }
        pos = pos + 1
        local n = 0
        while true do
            skip()
            local c = src:sub(pos, pos)
            if c == "}" then node.e = pos; pos = pos + 1; return node end
            if c == "," or c == ";" then pos = pos + 1
            else
                local fs = pos
                local key
                local name = src:match("^([%a_][%w_]*)%s*=[^=]", pos)
                if name then
                    key = name
                    pos = src:find("=", pos, true) + 1
                elseif c == "[" then
                    local close = src:find("]", pos, true)
                    local inner = src:sub(pos + 1, close - 1)
                    key = tonumber(inner) or inner:match('^"(.*)"$') or inner:match("^'(.*)'$")
                    pos = src:find("=", close, true) + 1
                else
                    n = n + 1
                    key = n
                end
                local v = P.value()
                node.fields[#node.fields + 1] = { key = key, s = fs, e = v.e, value = v }
            end
        end
    end
    -- Top level: Name = { ... }
    function P.chunk()
        local roots = {}
        while true do
            skip()
            if pos > #src then return roots end
            local name = src:match("^([%a_][%w_]*)%s*=", pos)
            if name then
                pos = src:find("=", pos, true) + 1
                local v = P.value()
                if v.fields then roots[name] = v end
            else
                local nl = src:find("\n", pos, true); pos = nl and nl + 1 or #src + 1
            end
        end
    end
    return P
end

-- Every table node with its dotted path.
local function index(roots)
    local nodes = {}
    local function walk(node, path)
        nodes[path] = node
        for _, f in ipairs(node.fields) do
            if f.value.fields then walk(f.value, path .. "." .. tostring(f.key)) end
        end
    end
    for name, node in pairs(roots) do walk(node, name) end
    return nodes
end

local function lookup(env, path)
    local t = env
    for part in path:gmatch("[^%.]+") do
        if type(t) ~= "table" then return nil end
        t = t[tonumber(part) or part]
    end
    return t
end

local function trailingComment(src, e)
    local line = src:sub(e + 1, (src:find("\n", e + 1, true) or #src + 1) - 1)
    return line:match("^%s*,?%s*%-%-%s*(.-)%s*$")
end

local function isArrayPoint(t)
    return type(t) == "table" and type(t[1]) == "number" and type(t[2]) == "number" and type(t[3]) == "number"
end
local function isNamedPoint(t)
    return type(t) == "table" and type(t.x) == "number" and type(t.y) == "number" and type(t.z) == "number"
end

---------------------------------------------------------------------------------------------------

local function same(a, b, path)
    if type(a) == "number" and type(b) == "number" then
        return math.abs(a - b) < 0.00051, path .. (": %s ~= %s"):format(tostring(a), tostring(b))
    end
    if type(a) ~= type(b) then return false, path .. (": %s ~= %s"):format(tostring(a), tostring(b)) end
    if type(a) ~= "table" then return a == b, path .. (": %s ~= %s"):format(tostring(a), tostring(b)) end
    for k, v in pairs(a) do
        local ok, why = same(v, b[k], path .. "." .. tostring(k))
        if not ok then return false, why end
    end
    for k in pairs(b) do if a[k] == nil then return false, path .. "." .. tostring(k) .. ": extra" end end
    return true
end

local function loadEnv(chunk, At, Spots)
    local env = setmetatable({ At = At, Spots = Spots }, { __index = _G })
    setfenv(chunk, env)()
    return env
end

local write = arg[1] == "--write"
local failed = false
for _, o in ipairs(OWNERS) do
    local records, rewritten = {}, {}
    for _, file in ipairs(o.files) do
        local src = assert(io.open(file)):read("*a")
        assert(not src:find("At%(\"") and not src:find("Spots%(\""), file .. " already converted")
        local original = loadEnv(assert(loadstring(src, "@" .. file)))
        local nodes = index(parser(src).chunk())
        -- Selected nodes, outermost first; inner ones inside a converted node are skipped.
        local selected = {}
        for path, node in pairs(nodes) do
            for _, rule in ipairs(o.rules) do
                if path:match(rule[1]) then selected[#selected + 1] = { path = path, node = node, rule = rule } break end
            end
        end
        table.sort(selected, function(a, b) return a.node.s < b.node.s end)
        local byNode = {}
        for _, sel in ipairs(selected) do byNode[sel.node] = sel end

        local function record(t, id, set, idx, note, rule, interior)
            local named = not isArrayPoint(t)
            records[#records + 1] = { id = id, set = set, index = idx, shape = named and "named" or "array", path = rule.path or nil,
                x = named and t.x or t[1], y = named and t.y or t[2], z = named and t.z or t[3],
                w = not named and t[4] or nil, interior = (type(t.interior) == "number" and t.interior) or interior or 0, note = note }
        end

        -- The replacement text for a selected node; selected nodes inside it render as well.
        local function render(sel)
            local path, node, rule = sel.path, sel.node, sel.rule
            local value = lookup(original, path)
            -- "..name": a field of the parent entry (e.g. a range's interior); otherwise a full path.
            local interior = rule.interior and lookup(original, rule.interior:match("^%.%.")
                and (path:match("^(.*)%.[^%.]+$") .. "." .. rule.interior:sub(3)) or rule.interior)
            if rule[2] == "list" then
                for i, f in ipairs(node.fields) do
                    local t = value[f.key]
                    assert(isArrayPoint(t) or isNamedPoint(t), path .. ": not a list of positions")
                    for k in pairs(t) do
                        local positional = isArrayPoint(t) and type(k) == "number" and k <= 4 or (k == "x" or k == "y" or k == "z")
                        assert(positional, path .. "." .. i .. " has more than a position (" .. tostring(k) .. "): make it a point rule")
                    end
                    record(t, path .. "." .. i, path, i, trailingComment(src, f.e), rule, interior)
                end
                return ('Spots("%s")'):format(path)
            end
            assert(isArrayPoint(value) or isNamedPoint(value), path .. ": not a position")
            local named = not isArrayPoint(value)
            record(value, path, nil, nil, nil, rule, interior)
            local rest = {}
            for _, f in ipairs(node.fields) do
                local positional = named and (f.key == "x" or f.key == "y" or f.key == "z")
                    or not named and type(f.key) == "number" and f.key <= 4
                if not positional then
                    local inner = f.value.fields and byNode[f.value]
                    local text = inner and (src:sub(f.s, f.value.s - 1) .. render(inner)) or src:sub(f.s, f.e)
                    -- Positional values after the position keep their place: { x, y, z, h, 14 } -> [5] = 14.
                    if type(f.key) == "number" and src:sub(f.s, f.value.s - 1):match("^%s*$") then
                        text = ("[%d] = %s"):format(f.key, text)
                    end
                    rest[#rest + 1] = text
                end
            end
            return #rest > 0 and ('At("%s", { %s })'):format(path, table.concat(rest, ", ")) or ('At("%s")'):format(path)
        end

        local edits = {}
        local lastEnd = 0
        for _, sel in ipairs(selected) do
            if sel.node.s > lastEnd then -- not inside another selected node (those render with it)
                edits[#edits + 1] = { s = sel.node.s, e = sel.node.e, text = render(sel) }
                lastEnd = sel.node.e
            end
        end
        table.sort(edits, function(a, b) return a.s > b.s end)
        local out = src
        for _, ed in ipairs(edits) do out = out:sub(1, ed.s - 1) .. ed.text .. out:sub(ed.e + 1) end
        rewritten[#rewritten + 1] = { file = file, src = out, original = original, edits = #edits }
    end

    -- The spot elements, written as the map will hold them, and read back.
    local lines = {}
    for _, r in ipairs(records) do
        local attrs = {}
        for _, a in ipairs(MapData.toAttributes(MapData.spotSchema, r)) do
            attrs[#attrs + 1] = ('%s="%s"'):format(a[1], tostring(a[2]):gsub("&", "&amp;"):gsub('"', "&quot;"):gsub("<", "&lt;"))
        end
        lines[#lines + 1] = "    <spot " .. table.concat(attrs, " ") .. " />"
    end
    local back = {}
    for _, line in ipairs(lines) do
        local attr = {}
        for k, v in line:gmatch('([%w_]+)="(.-)"') do attr[k] = v:gsub("&lt;", "<"):gsub("&quot;", '"'):gsub("&amp;", "&") end
        back[#back + 1] = MapData.fromAttributes(MapData.spotSchema, attr)
    end
    local At, Spots = MapData.spotFunctions(back)
    for _, rw in ipairs(rewritten) do
        local env = loadEnv(assert(loadstring(rw.src, "@" .. rw.file)), At, Spots)
        for name, value in pairs(rw.original) do
            if type(value) == "table" then
                local ok, why = same(value, env[name], name)
                if not ok then failed = true print(("FAIL %s: %s"):format(rw.file, why)) end
            end
        end
        print(("%-42s %3d positions moved"):format(rw.file, rw.edits))
    end
    print(("%-42s %3d spot elements"):format(o.map, #records))
    if write and not failed then
        for _, rw in ipairs(rewritten) do assert(io.open(rw.file, "w")):write(rw.src) end
        local map = assert(io.open(o.map)):read("*a")
        map = map:gsub("</map>%s*$", "    <!-- Spot (a position the activity rules use) -->\n" .. table.concat(lines, "\n") .. "\n</map>\n")
        assert(io.open(o.map, "w")):write(map)
    end
end
print(failed and "FAIL" or ("PASS: the rewritten configs equal the originals" .. (write and " (written)" or " (dry run; --write to apply)")))
os.exit(failed and 1 or 0)
