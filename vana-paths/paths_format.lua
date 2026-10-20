-- Reader for retail GTA:SA data/Paths/NODES<area>.DAT: the converter's (tools/convert/paths_to_maps.lua);
-- the game reads the graph from map data (paths_data.lua).
-- Layout checked against all 64 retail files: sections 5-7 are each one entry per link,
-- followed by a 384-byte trailer.
PathsFormat = {}

local byte, floor = string.byte, math.floor

local function u16(s, o) local a, b = byte(s, o, o + 1) return a + b * 256 end
local function i16(s, o) local v = u16(s, o) return v >= 32768 and v - 65536 or v end
local function u32(s, o) local a, b, c, d = byte(s, o, o + 3) return a + b * 256 + c * 65536 + d * 16777216 end
local function i8(s, o) local v = byte(s, o) return v >= 128 and v - 256 or v end

-- Returns an area table of 0-based parallel arrays (indices match the game's node/navi/link IDs).
function PathsFormat.parse(areaId, s)
    local nodeCount, vehCount, pedCount = u32(s, 1), u32(s, 5), u32(s, 9)
    local naviCount, linkCount = u32(s, 13), u32(s, 17)

    local s1 = 21
    local s2 = s1 + 28 * nodeCount
    local s3 = s2 + 14 * naviCount
    local s5 = s3 + 4 * linkCount + 768
    local s6 = s5 + 2 * linkCount
    local s7 = s6 + linkCount
    if s7 + linkCount + 384 - 1 ~= #s then
        return false, ("NODES%d.DAT: size %d does not match header"):format(areaId, #s)
    end

    local area = {
        id = areaId, nodeCount = nodeCount, vehCount = vehCount, pedCount = pedCount,
        naviCount = naviCount, linkCount = linkCount,
        x = {}, y = {}, z = {}, width = {}, flood = {}, flags = {}, linkStart = {},
        naviX = {}, naviY = {}, naviArea = {}, naviNode = {}, naviDirX = {}, naviDirY = {}, naviFlags = {},
        linkArea = {}, linkNode = {}, linkNavi = {}, linkLength = {}, linkFlags = {},
    }

    for i = 0, nodeCount - 1 do
        local o = s1 + 28 * i
        area.x[i], area.y[i], area.z[i] = i16(s, o + 8) / 8, i16(s, o + 10) / 8, i16(s, o + 12) / 8
        area.linkStart[i] = u16(s, o + 16)
        area.width[i] = byte(s, o + 22) / 8
        area.flood[i] = byte(s, o + 23)
        area.flags[i] = u32(s, o + 24)
    end

    for i = 0, naviCount - 1 do
        local o = s2 + 14 * i
        area.naviX[i], area.naviY[i] = i16(s, o) / 8, i16(s, o + 2) / 8
        area.naviArea[i], area.naviNode[i] = u16(s, o + 4), u16(s, o + 6)
        area.naviDirX[i], area.naviDirY[i] = i8(s, o + 8) / 100, i8(s, o + 9) / 100
        area.naviFlags[i] = u32(s, o + 10)
    end

    for i = 0, linkCount - 1 do
        area.linkArea[i], area.linkNode[i] = u16(s, s3 + 4 * i), u16(s, s3 + 4 * i + 2)
        area.linkNavi[i] = u16(s, s5 + 2 * i)
        area.linkLength[i] = byte(s, s6 + i)
        area.linkFlags[i] = byte(s, s7 + i)
    end

    area.trailer = s:sub(s7 + linkCount, s7 + linkCount + 383) -- 384 bytes, mostly zero (kept by the converter)
    return area
end

-- Navi link word: bits 0-9 navi index within its file, bits 10-15 area.
function PathsFormat.splitNaviLink(v)
    return floor(v / 1024), v % 1024
end
