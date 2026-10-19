-- Low-level readers for GTA:SA's game files, shared by the format modules (sa_gxt.lua, sa_ide.lua,
-- sa_dat.lua, sa_txd.lua). Bytes are 1-based offsets into a Lua string; numbers are little-endian.
-- Runs in MTA and in plain Lua 5.1 (tools, tests). Copied into resources by tools/sync-libs.sh.
SA = SA or {}

local byte, floor = string.byte, math.floor

-- The whole file as a string, or nil.
function SA.readFile(path)
    if fileOpen then
        if not fileExists(path) then return nil end
        local f = fileOpen(path, true)
        if not f then return nil end
        local s = fileRead(f, fileGetSize(f))
        fileClose(f)
        return s
    end
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

function SA.u8(s, o) return byte(s, o) end
function SA.u16(s, o) local a, b = byte(s, o, o + 1) return a + b * 256 end
function SA.u32(s, o) local a, b, c, d = byte(s, o, o + 3) return a + b * 256 + c * 65536 + d * 16777216 end
function SA.i16(s, o) local v = SA.u16(s, o) return v >= 32768 and v - 65536 or v end
function SA.i32(s, o) local v = SA.u32(s, o) return v >= 2147483648 and v - 4294967296 or v end

-- IEEE 754 single.
function SA.f32(s, o)
    local v = SA.u32(s, o)
    local sign = v >= 2147483648 and -1 or 1
    local exponent = floor(v / 8388608) % 256
    local mantissa = v % 8388608
    if exponent == 0 then return sign * mantissa * 2 ^ -149 end
    if exponent == 255 then return mantissa == 0 and sign * math.huge or 0 / 0 end
    return sign * (1 + mantissa / 8388608) * 2 ^ (exponent - 127)
end

-- A zero-padded fixed-length string field.
function SA.fixed(s, o, length) return (s:sub(o, o + length - 1):gsub("%z.*", "")) end

-- Bit operations: MTA's, or arithmetic ones in plain Lua.
SA.band = bitAnd or function(a, b)
    local r, bit = 0, 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then r = r + bit end
        a, b, bit = floor(a / 2), floor(b / 2), bit * 2
    end
    return r
end
SA.bxor = bitXor or function(a, b)
    local r, bit = 0, 1
    while a > 0 or b > 0 do
        if a % 2 ~= b % 2 then r = r + bit end
        a, b, bit = floor(a / 2), floor(b / 2), bit * 2
    end
    return r
end
SA.rshift = bitRShift or function(a, n) return floor(a / 2 ^ n) end

-- Text files: lines (CR stripped), a line without its comment (# or //) and trimmed, fields split on
-- commas and/or whitespace (the engine's loaders treat commas as whitespace).
function SA.lines(s) return (s:gsub("\r", "")):gmatch("([^\n]*)\n?") end
function SA.code(line) return (line:gsub("#.*", ""):gsub("//.*", ""):gsub("^%s+", ""):gsub("%s+$", "")) end
function SA.fields(line)
    local out = {}
    for field in line:gsub(",", " "):gmatch("%S+") do out[#out + 1] = field end
    return out
end
