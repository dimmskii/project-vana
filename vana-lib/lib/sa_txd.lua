-- RenderWare texture dictionaries (.txd, GTA:SA PC: D3D8 and D3D9 native textures) to DDS data, which
-- dxCreateTexture takes as is. Compressed textures (DXT1/3/5) are copied; 32/16-bit ones are written
-- with their bit masks; paletted ones are expanded to 32-bit. Needs sa_reader.lua. Copied into
-- resources by tools/sync-libs.sh.
SATxd = SATxd or {}

local u8, u16, u32 = SA.u8, SA.u16, SA.u32
local char, floor, concat = string.char, math.floor, table.concat

local function le32(v)
    v = v % 4294967296
    return char(v % 256, floor(v / 256) % 256, floor(v / 65536) % 256, floor(v / 16777216) % 256)
end

-- Raster formats (the low bits of rasterFormat) and their DDS pixel formats: bits, R, G, B, A masks.
local RASTER = {
    [0x0100] = { 16, 0x7C00, 0x03E0, 0x001F, 0x8000 },             -- 1555
    [0x0200] = { 16, 0xF800, 0x07E0, 0x001F, 0 },                  -- 565
    [0x0300] = { 16, 0x0F00, 0x00F0, 0x000F, 0xF000 },             -- 4444
    [0x0500] = { 32, 0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000 }, -- 8888 (B, G, R, A in memory)
    [0x0600] = { 32, 0x00FF0000, 0x0000FF00, 0x000000FF, 0 },      -- 888 (B, G, R, unused)
}
local FOURCC = { DXT1 = true, DXT2 = true, DXT3 = true, DXT4 = true, DXT5 = true }

local function dds(width, height, levels, pixelFormat, data, linearSize)
    local flags = 0x1 + 0x2 + 0x4 + 0x1000 + 0x80000 + (levels > 1 and 0x20000 or 0) -- caps, h, w, pixelformat, linearsize, mips
    local caps = 0x1000 + (levels > 1 and 0x400008 or 0)
    return "DDS " .. le32(124) .. le32(flags) .. le32(height) .. le32(width) .. le32(linearSize) .. le32(0) .. le32(levels)
        .. string.rep(le32(0), 11) .. pixelFormat .. le32(caps) .. le32(0) .. le32(0) .. le32(0) .. le32(0) .. data
end

local function fourccFormat(code)
    return le32(32) .. le32(0x4) .. code .. le32(0) .. le32(0) .. le32(0) .. le32(0) .. le32(0)
end

local function maskFormat(m)
    return le32(32) .. le32(0x40 + (m[5] ~= 0 and 0x1 or 0)) .. le32(0) .. le32(m[1]) .. le32(m[2]) .. le32(m[3]) .. le32(m[4]) .. le32(m[5])
end

-- One texture native (the chunk's body at offset o): { name, mask, width, height, levels, format, dds }.
local function readNative(s, o)
    local body = o + 12 -- the struct chunk's body
    local platform = u32(s, body)
    local name, mask = SA.fixed(s, body + 8, 32), SA.fixed(s, body + 40, 32)
    local rasterFormat, d3dFormat = u32(s, body + 72), s:sub(body + 76, body + 79)
    local width, height = u16(s, body + 80), u16(s, body + 82)
    local levels, compression = u8(s, body + 85), u8(s, body + 87)
    local p = body + 88
    local tex = { name = name, mask = mask, width = width, height = height, levels = levels }

    local code
    if platform == 9 and FOURCC[d3dFormat] then
        code = d3dFormat
    elseif platform == 8 and compression ~= 0 then
        code = "DXT" .. compression
    end

    local palette
    if rasterFormat % 0x10000 >= 0x2000 then
        local pal8 = floor(rasterFormat / 0x2000) % 2 == 1
        local entries = pal8 and 256 or (platform == 9 and 32 or 16) -- D3D9 PAL4 stores 32 entries
        palette = { s:byte(p, p + entries * 4 - 1) }
        p = p + entries * 4
    end

    local parts, linear = {}, nil
    local w, h = width, height
    for level = 1, levels do
        local size = u32(s, p)
        local data = s:sub(p + 4, p + 3 + size)
        p = p + 4 + size
        if palette then
            -- Index -> RGBA from the palette, written as B, G, R, A (8888).
            local out = {}
            local pal8 = #palette >= 1024
            for i = 1, w * h do
                local index
                if pal8 then index = data:byte(i) or 0 else
                    local b = data:byte(floor((i - 1) / 2) + 1) or 0
                    index = (i - 1) % 2 == 0 and b % 16 or floor(b / 16)
                end
                local q = index * 4
                out[i] = char(palette[q + 3] or 0, palette[q + 2] or 0, palette[q + 1] or 0, palette[q + 4] or 255)
            end
            data = concat(out)
        end
        parts[level] = data
        linear = linear or #data
        w, h = math.max(1, floor(w / 2)), math.max(1, floor(h / 2))
    end

    if code then
        tex.format = code
        tex.dds = dds(width, height, levels, fourccFormat(code), concat(parts), linear)
    elseif palette then
        tex.format = "8888 (from palette)"
        tex.dds = dds(width, height, levels, maskFormat(RASTER[0x0500]), concat(parts), linear)
    else
        local m = RASTER[rasterFormat % 0x1000]
        if not m then return tex end -- unknown format: no dds
        tex.format = ("%x"):format(rasterFormat % 0x1000)
        tex.dds = dds(width, height, levels, maskFormat(m), concat(parts), linear)
    end
    return tex
end

-- Every texture in a TXD file's data: { [name] = texture, ... }, plus the list in file order.
function SATxd.parse(s)
    if not s or u32(s, 1) ~= 0x16 then return nil, "not a texture dictionary" end
    local textures, list = {}, {}
    local o = 13 + 12 + u32(s, 13 + 4) -- past the dictionary's header and its struct
    local stop = 12 + u32(s, 5)
    while o < stop do
        local id, size = u32(s, o), u32(s, o + 4)
        if id == 0x15 then
            local tex = readNative(s, o + 12)
            textures[tex.name:lower()] = tex
            list[#list + 1] = tex
        end
        o = o + 12 + size
    end
    return textures, list
end

-- In MTA (client): textures from a TXD file as dx textures, { [lowercase name] = texture }.
if dxCreateTexture then
    function SATxd.load(path)
        local textures = SATxd.parse(SA.readFile(path))
        if not textures then return nil end
        local out = {}
        for name, tex in pairs(textures) do
            if tex.dds then out[name] = dxCreateTexture(tex.dds) or nil end
        end
        return out
    end
end
