-- Map Editor helper (loaded by our EDF definitions): draws how placed elements connect. Paths
-- (each point's nextid) as arrows, links to another element (a burglary door's house) and exit
-- points (ex, ey, ez: where an entrance or door puts you) as lines. Only near the camera.
-- /vanalines toggles it. Copied into each resource whose EDF links elements (tools/sync-libs.sh).
local LINKS = { -- element type -> { property, colour, arrow }
    racecheckpoint = { { "nextid", tocolor(255, 210, 0, 230), true } },
    routepoint = { { "nextid", tocolor(128, 255, 0, 230), true } },
    burglarydoor = { { "house", tocolor(255, 170, 0, 140), false } },
}
local EXITS = { entrance = tocolor(255, 220, 0, 200), burglarydoor = tocolor(255, 120, 0, 200), burglaryhouse = tocolor(255, 120, 0, 200) }
local RANGE = 300
local shown = true

addCommandHandler("vanalines", function()
    shown = not shown
    outputChatBox("Vana editor lines " .. (shown and "on" or "off"))
end)

local function edf(fn, ...)
    local ok, a, b, c = pcall(function(...) return exports.edf[fn](exports.edf, ...) end, ...)
    if ok then return a, b, c end
end

local function positionOf(element)
    local x, y, z = edf("edfGetElementPosition", element)
    if not x then x, y, z = getElementPosition(element) end
    return x, y, z
end

local function arrow(sx, sy, sz, dx, dy, dz, colour)
    dxDrawLine3D(sx, sy, sz + 1, dx, dy, dz + 1, colour, 3)
    local vx, vy = dx - sx, dy - sy
    local len = math.sqrt(vx * vx + vy * vy)
    if len < 1 then return end
    vx, vy = vx / len, vy / len
    local bx, by = dx - vx * 3, dy - vy * 3
    dxDrawLine3D(dx, dy, dz + 1, bx + vy * 1.5, by - vx * 1.5, dz + 1, colour, 3)
    dxDrawLine3D(dx, dy, dz + 1, bx - vy * 1.5, by + vx * 1.5, dz + 1, colour, 3)
end

addEventHandler("onClientRender", root, function()
    if not shown then return end
    local cx, cy, cz = getCameraMatrix()
    local function near(x, y, z) return x and getDistanceBetweenPoints3D(cx, cy, cz, x, y, z) < RANGE end
    for elementType, links in pairs(LINKS) do
        for _, element in ipairs(getElementsByType(elementType)) do
            local sx, sy, sz = positionOf(element)
            if near(sx, sy, sz) then
                for _, link in ipairs(links) do
                    local target = edf("edfGetElementProperty", element, link[1])
                    if type(target) == "string" then target = getElementByID(target) end
                    if isElement(target) then
                        local dx, dy, dz = positionOf(target)
                        if link[3] then arrow(sx, sy, sz, dx, dy, dz, link[2]) else dxDrawLine3D(sx, sy, sz + 1, dx, dy, dz + 1, link[2], 2) end
                    end
                end
            end
        end
    end
    for elementType, colour in pairs(EXITS) do
        for _, element in ipairs(getElementsByType(elementType)) do
            local sx, sy, sz = positionOf(element)
            local ex = tonumber(edf("edfGetElementProperty", element, "ex"))
            local ey = tonumber(edf("edfGetElementProperty", element, "ey"))
            local ez = tonumber(edf("edfGetElementProperty", element, "ez"))
            if ex and ey and ez and near(sx, sy, sz) and getDistanceBetweenPoints3D(sx, sy, sz, ex, ey, ez) < RANGE then
                dxDrawLine3D(sx, sy, sz + 0.5, ex, ey, ez + 0.5, colour, 1.5)
                dxDrawLine3D(ex - 0.4, ey, ez + 0.5, ex + 0.4, ey, ez + 0.5, colour, 3)
                dxDrawLine3D(ex, ey - 0.4, ez + 0.5, ex, ey + 0.4, ez + 0.5, colour, 3)
            end
        end
    end
end)
