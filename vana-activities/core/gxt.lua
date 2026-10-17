-- Reader for the retail text file (data/american.gxt, see docs/setup.md): vanilla text by
-- GXT key, from MAIN or a mission table (e.g. "BURGLAR"). Keys are stored as JAMCRC32 of the key.
-- Text keeps its formatting tokens (~r~, ~n~, ~k~~PED_SPRINT~); the client renders them.
Gxt = {}

local PATH = "data/american.gxt"
local byte = string.byte
local crcTable = {}
for i = 0, 255 do
    local c = i
    for _ = 1, 8 do
        if bitAnd(c, 1) == 1 then c = bitXor(bitRShift(c, 1), 0xEDB88320) else c = bitRShift(c, 1) end
    end
    crcTable[i] = c
end

local function jamcrc(s)
    local c = 0xFFFFFFFF
    for i = 1, #s do
        c = bitXor(crcTable[bitAnd(bitXor(c, byte(s, i)), 0xFF)], bitRShift(c, 8))
    end
    return c
end

local function u32(s, o)
    local a, b, c, d = byte(s, o, o + 3)
    return a + b * 256 + c * 65536 + d * 16777216
end

local text
local tableAt = {}  -- table name -> offset of its TKEY
local loaded = {}   -- table name -> { [crc] = string }

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

function Gxt.load()
    local f = fileOpen(PATH, true)
    if not f then return false end
    text = fileRead(f, fileGetSize(f))
    fileClose(f)
    if text:sub(5, 8) ~= "TABL" then text = nil return false end
    -- TABL: 12-byte entries of an 8-byte name and an offset. MAIN's offset points at TKEY; mission
    -- tables repeat their 8-byte name first.
    for i = 0, u32(text, 9) / 12 - 1 do
        local entry = 13 + i * 12
        local name = text:sub(entry, entry + 7):gsub("%z.*", "")
        tableAt[name] = u32(text, entry + 8) + 1 + (name == "MAIN" and 0 or 8)
    end
    return readTable("MAIN") ~= nil
end

-- The raw vanilla text for a key, looked up in `tableName` first, then MAIN; nil if missing.
function Gxt.raw(key, tableName)
    if not text or not key then return nil end
    local crc = jamcrc(key:upper())
    local t = tableName and readTable(tableName)
    return t and t[crc] or readTable("MAIN")[crc]
end

-- Fills ~1~ placeholders in order with the given numbers.
function Gxt.format(s, ...)
    local args, i = { ... }, 0
    return (s:gsub("~1~", function()
        i = i + 1
        return tostring(args[i] or "")
    end))
end
