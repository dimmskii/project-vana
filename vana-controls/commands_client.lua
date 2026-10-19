-- Every action is a command here (sent by the server: server.lua), so it can be typed, bound to a key
-- or picked in /interact. Running one tells the server what the player can see: nearby vehicles,
-- peds, players and markers with nothing solid in between, nearest the middle of the view first.
Commands = {}
local actions = {}  -- name -> def
local ordered = {}  -- defs as the server listed them
local handlers = {} -- command name -> handler we added

local SEEN_RANGE, SEEN_MAX = 12, 24
local KINDS = { "vehicle", "player", "ped", "marker" }

local function centre(e)
    local x, y, z = getElementPosition(e)
    local kind = getElementType(e)
    if kind == "marker" then return x, y, z + 0.8 end
    if kind == "vehicle" then return x, y, z + 0.3 end
    return x, y, z + 0.5
end

-- What the player can see, best first: within the 60 degrees round the middle of the view by angle,
-- then the rest by distance.
function Commands.seen()
    local cx, cy, cz, lx, ly, lz = getCameraMatrix()
    local fx, fy, fz = lx - cx, ly - cy, lz - cz
    local fl = math.sqrt(fx * fx + fy * fy + fz * fz)
    if fl == 0 then fl = 1 end
    fx, fy, fz = fx / fl, fy / fl, fz / fl
    local px, py, pz = getElementPosition(localPlayer)
    local dim, int = getElementDimension(localPlayer), getElementInterior(localPlayer)
    local own = getPedOccupiedVehicle(localPlayer)
    local list = {}
    for _, kind in ipairs(KINDS) do
        for _, e in ipairs(getElementsWithinRange(px, py, pz, SEEN_RANGE, kind)) do
            if e ~= localPlayer and e ~= own and getElementDimension(e) == dim and getElementInterior(e) == int then
                local ex, ey, ez = centre(e)
                if isLineOfSightClear(px, py, pz + 0.6, ex, ey, ez, true, false, false, true, false, true, false, localPlayer) then
                    local dx, dy, dz = ex - cx, ey - cy, ez - cz
                    local d = math.sqrt(dx * dx + dy * dy + dz * dz)
                    local cos = d > 0 and (dx * fx + dy * fy + dz * fz) / d or 1
                    list[#list + 1] = { e = e, inView = cos > 0.866, cos = cos, d = getDistanceBetweenPoints3D(px, py, pz, ex, ey, ez) }
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.inView ~= b.inView then return a.inView end
        if a.inView then return a.cos > b.cos end
        return a.d < b.d
    end)
    local out = {}
    for i = 1, math.min(#list, SEEN_MAX) do out[i] = list[i].e end
    return out
end

-- Runs an action: `words` are what was typed after it, `picked` what was clicked (or nil).
function Commands.run(name, words, picked)
    triggerServerEvent("vana-controls:run", resourceRoot, name, words or {}, picked, Commands.seen())
end

function Commands.get(name) return actions[name] end
function Commands.list() return ordered end

local function register(list)
    for name, fn in pairs(handlers) do removeCommandHandler(name, fn) end
    handlers, actions, ordered = {}, {}, list
    for _, def in ipairs(list) do
        local names = { def.name }
        for _, a in ipairs(def.aliases or {}) do names[#names + 1] = a end
        for _, n in ipairs(names) do
            if not actions[n] then
                actions[n] = def
                local fn = function(_, ...) Commands.run(def.name, { ... }) end
                handlers[n] = fn
                addCommandHandler(n, fn)
            end
        end
    end
end

addEvent("vana-controls:actions", true)
addEventHandler("vana-controls:actions", resourceRoot, register)
addEventHandler("onClientResourceStart", resourceRoot, function() triggerServerEvent("vana-controls:hello", resourceRoot) end)
