-- GTA:SA text (american.gxt): TABL lists the tables (MAIN and the mission tables); each table's TKEY
-- maps JAMCRC32(key) to an offset into its TDAT strings. Tables are read when first used.
-- Needs sa_reader.lua. Copied into resources by tools/sync-libs.sh.
Gxt = Gxt or {}

local u32, band, bxor, rshift = SA.u32, SA.band, SA.bxor, SA.rshift

local crcTable = {}
for i = 0, 255 do
    local c = i
    for _ = 1, 8 do
        if band(c, 1) == 1 then c = bxor(rshift(c, 1), 0xEDB88320) else c = rshift(c, 1) end
    end
    crcTable[i] = c
end

-- CRC32 without the final XOR, as the game hashes GXT keys.
function Gxt.jamcrc(s)
    local c = 0xFFFFFFFF
    for i = 1, #s do c = bxor(crcTable[band(bxor(c, s:byte(i)), 0xFF)], rshift(c, 8)) end
    return c
end

local text
local tableAt = {} -- table name -> offset of its TKEY
local loaded = {}  -- table name -> { [crc] = string }

local function readTable(name)
    if loaded[name] then return loaded[name] end
    local at = tableAt[name]
    if not at or text:sub(at, at + 3) ~= "TKEY" then return nil end
    local keyBytes = u32(text, at + 4)
    local tdat = at + 8 + keyBytes
    if text:sub(tdat, tdat + 3) ~= "TDAT" then return nil end
    local strings = {}
    for i = 0, keyBytes / 8 - 1 do
        local entry = at + 8 + i * 8
        local s = tdat + 8 + u32(text, entry)
        local e = text:find("\0", s, true)
        strings[u32(text, entry + 4)] = text:sub(s, (e or s) - 1)
    end
    loaded[name] = strings
    return strings
end

-- Loads the file (default data/american.gxt). False if it's missing or not a GXT.
function Gxt.load(path)
    text, tableAt, loaded = SA.readFile(path or "data/american.gxt"), {}, {}
    if not text or text:sub(5, 8) ~= "TABL" then text = nil return false end
    -- 12-byte entries: an 8-byte name and an offset. MAIN's offset points at its TKEY; mission tables
    -- repeat their 8-byte name first.
    for i = 0, u32(text, 9) / 12 - 1 do
        local entry = 13 + i * 12
        local name = SA.fixed(text, entry, 8)
        tableAt[name] = u32(text, entry + 8) + 1 + (name == "MAIN" and 0 or 8)
    end
    return readTable("MAIN") ~= nil
end

-- The table names in the file.
function Gxt.tables()
    local list = {}
    for name in pairs(tableAt) do list[#list + 1] = name end
    table.sort(list)
    return list
end

-- Every key's crc and text in a table (for tools and tests).
function Gxt.entries(tableName) return readTable(tableName or "MAIN") or {} end

-- The text for a key as stored (formatting tokens like ~r~, ~k~~PED_SPRINT~ kept), from `tableName`
-- first, then MAIN; nil if missing.
function Gxt.raw(key, tableName)
    if not text or not key then return nil end
    local crc = Gxt.jamcrc(key:upper())
    local t = tableName and readTable(tableName)
    return t and t[crc] or readTable("MAIN")[crc]
end

-- The text without its colour tokens (~r~ and the like): for plain display, e.g. item names.
function Gxt.get(key, tableName)
    local s = Gxt.raw(key, tableName)
    return s and (s:gsub("~%a~", ""))
end

-- Fills ~1~ placeholders in order with the given values.
function Gxt.format(s, ...)
    local args, i = { ... }, 0
    return (s:gsub("~1~", function()
        i = i + 1
        return tostring(args[i] or "")
    end))
end
