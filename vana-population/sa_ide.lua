-- GTA:SA item definitions (.ide): sections (objs, tobj, cars, peds, weap, ...) of comma-separated
-- fields, each closed by "end". Like the engine's loader, commas count as whitespace (a few retail
-- lines miss them). Needs sa_reader.lua. Copied into resources by tools/sync-libs.sh.
SAIde = SAIde or {}

-- { [section] = { fields, ... } } for the wanted sections (all when nil), in file order.
function SAIde.parse(text, wanted)
    local out, section = {}, nil
    local want = {}
    for _, name in ipairs(wanted or {}) do want[name] = true end
    for line in SA.lines(text) do
        local l = SA.code(line)
        local word = l:lower()
        if section == nil and l ~= "" and not l:find("[%s,]") then
            section = word
            if not wanted or want[section] then out[section] = out[section] or {} end
        elseif word == "end" then
            section = nil
        elseif section and l ~= "" and out[section] then
            table.insert(out[section], SA.fields(l))
        end
    end
    return out
end

-- Rows keyed by their numeric id (field 1), and a lowercase model name (field 2) -> id map.
function SAIde.index(rows)
    local byId, byName, count = {}, {}, 0
    for _, f in ipairs(rows or {}) do
        local id = tonumber(f[1])
        if id then byId[id], byName[(f[2] or ""):lower()], count = f, id, count + 1 end
    end
    return byId, byName, count
end
