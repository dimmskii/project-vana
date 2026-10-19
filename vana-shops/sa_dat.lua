-- GTA:SA's line-based data files. Needs sa_reader.lua. Copied into resources by tools/sync-libs.sh.
SADat = SADat or {}

-- Every non-empty line without its comment, as fields (commas and whitespace separate them).
function SADat.rows(text)
    local out = {}
    for line in SA.lines(text) do
        local l = SA.code(line)
        if l ~= "" then out[#out + 1] = SA.fields(l) end
    end
    return out
end

-- popcycle.dat: sections named by "// NAME" comment lines, each a list of rows of integers.
-- names: the section names to recognise (other comment lines are just comments), upper case.
-- { [NAME] = { { n, ... }, ... } }
function SADat.popcycle(text, names)
    local out, rows = {}, nil
    local known = {}
    for _, name in ipairs(names) do known[name] = true end
    for line in SA.lines(text) do
        local header = line:match("^//%s*([%u_]+)")
        if header and known[header] then
            rows = {}
            out[header] = rows
        elseif rows then
            local l = SA.code(line)
            if l ~= "" then
                local n = {}
                for v in l:gmatch("%-?%d+") do n[#n + 1] = tonumber(v) end
                rows[#rows + 1] = n
            end
        end
    end
    return out
end

-- info.zon / map.zon: { name, type, x1, y1, z1, x2, y2, z2 (each pair ordered), level, text } boxes.
function SADat.zones(text)
    local out = {}
    for _, f in ipairs(SADat.rows(text)) do
        local x1, y1, z1, x2, y2, z2 = tonumber(f[3]), tonumber(f[4]), tonumber(f[5]), tonumber(f[6]), tonumber(f[7]), tonumber(f[8])
        if #f >= 9 and x1 then
            out[#out + 1] = { name = f[1], type = tonumber(f[2]), x1 = math.min(x1, x2), y1 = math.min(y1, y2), z1 = math.min(z1, z2),
                              x2 = math.max(x1, x2), y2 = math.max(y1, y2), z2 = math.max(z1, z2), level = tonumber(f[9]), text = f[10] }
        end
    end
    return out
end

-- shopping.dat-style nesting: "section NAME" ... "end" blocks. { name = "", sections = { [lowercase
-- name] = node }, order = { node, ... }, rows = { fields, ... } } per node, the file being the root.
function SADat.sections(text)
    local root = { name = "", sections = {}, order = {}, rows = {} }
    local stack = { root }
    for line in SA.lines(text) do
        local l = SA.code(line)
        local f = l ~= "" and SA.fields(l)
        local top = stack[#stack]
        if f and f[1] == "section" then
            local node = { name = f[2]:lower(), sections = {}, order = {}, rows = {} }
            top.sections[node.name] = node
            top.order[#top.order + 1] = node
            stack[#stack + 1] = node
        elseif f and f[1] == "end" then
            if #stack > 1 then stack[#stack] = nil end
        elseif f then
            top.rows[#top.rows + 1] = f
        end
    end
    return root
end
