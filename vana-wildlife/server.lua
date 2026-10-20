-- Wildlife: animals at their places ([data]/vana-data-wildlife's spawners, seeded from Myths Maker
-- 2.7's animal pack; species and files in config/species.lua). The spawning itself is still to come
-- (docs/wildlife.md); for now the data and the files are loaded and checked.

-- Console-only: every spawner names a known species, and every species' files are here.
addCommandHandler("wildlifetest", function(source)
    if getElementType(source) ~= "console" then return end
    local ok, bySpecies, unknown = true, {}, 0
    for _, s in ipairs(WildlifeSpawners) do
        if WildlifeSpecies[s.species] then bySpecies[s.species] = (bySpecies[s.species] or 0) + 1 else unknown = unknown + 1 end
    end
    if unknown > 0 then ok = false end
    local missing, files = {}, 0
    for id, sp in pairs(WildlifeSpecies) do
        local list = {}
        for _, v in ipairs(sp.variants) do list[#list + 1] = v[1] list[#list + 1] = v[2] end
        for _, p in ipairs(sp.ifps) do list[#list + 1] = p end
        for _, p in ipairs(sp.sounds.random) do list[#list + 1] = p end
        for _, p in ipairs(sp.sounds.damage) do list[#list + 1] = p end
        if #sp.variants == 0 then missing[#missing + 1] = id .. ": no model" end
        for _, p in ipairs(list) do
            files = files + 1
            if not fileExists(p) then missing[#missing + 1] = p end
        end
    end
    if #missing > 0 then ok = false end
    local counts = {}
    for id, n in pairs(bySpecies) do counts[#counts + 1] = ("%s %d"):format(id, n) end
    table.sort(counts)
    outputServerLog(("[wildlifetest] %d spawners (%s), %d of unknown species"):format(#WildlifeSpawners, table.concat(counts, ", "), unknown))
    outputServerLog(("[wildlifetest] %d files listed, %d missing%s"):format(files, #missing, #missing > 0 and (": " .. table.concat(missing, ", "):sub(1, 300)) or ""))
    outputServerLog("[wildlifetest] " .. (ok and "PASS" or "FAIL"))
end)
