-- Reader for the retail text file (data/american.gxt): vanilla display names by GXT key, e.g.
-- shopping.dat's nametag "VESTA" -> "Black Tank". Keys are stored as JAMCRC32 (CRC32 without the
-- final XOR) of the key; only the MAIN table is read.
Gxt = {}

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

local text, dataStart
local offsets = {} -- crc -> offset into TDAT

function Gxt.load(path)
    local f = fileOpen(path, true)
    if not f then return false end
    text = fileRead(f, fileGetSize(f))
    fileClose(f)
    -- Header (version, bits per char), then TABL: 12-byte entries of an 8-byte name and an offset.
    if text:sub(5, 8) ~= "TABL" then return false end
    local mainOffset = u32(text, 9 + 4 + 8) + 1 -- the first table is MAIN; its offset points at TKEY
    if text:sub(mainOffset, mainOffset + 3) ~= "TKEY" then return false end
    local keyBytes = u32(text, mainOffset + 4)
    for i = 0, keyBytes / 8 - 1 do
        local entry = mainOffset + 8 + i * 8
        offsets[u32(text, entry + 4)] = u32(text, entry)
    end
    local tdat = mainOffset + 8 + keyBytes
    if text:sub(tdat, tdat + 3) ~= "TDAT" then return false end
    dataStart = tdat + 8
    return true
end

-- The vanilla text for a key, without GXT formatting tokens (~r~ and the like), or nil.
function Gxt.get(key)
    if not text or not key then return nil end
    local offset = offsets[jamcrc(key:upper())]
    if not offset then return nil end
    local s = dataStart + offset
    local e = text:find("\0", s, true)
    return (text:sub(s, (e or s) - 1):gsub("~%a~", ""))
end
