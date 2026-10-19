function getNode(area, id) return Paths.getNode(area, id) end
function getNodeLinks(area, id) return Paths.getNodeLinks(area, id) end
function getNaviNode(area, index) return Paths.getNaviNode(area, index) end
function getAreaAt(x, y) return Paths.getAreaAt(x, y) end
function getNodePosition(area, id) return Paths.getNodePosition(area, id) end
function findNearestNode(x, y, z, kind, radius) return Paths.findNearestNode(x, y, z, kind, radius) end
function findRoute(fromX, fromY, fromZ, toX, toY, toZ) return Route.find(fromX, fromY, fromZ, toX, toY, toZ) end
function getCarLight(lightType, state) return Lights.getCarLight(lightType, state) end
function getPedSignal(state) return Lights.getPedSignal(state) end
function getGoverningLight(naviArea, naviIndex, toArea, toId)
    return Lights.getGoverningLight(naviArea, naviIndex, toArea, toId)
end
function shouldCarStop(naviArea, naviIndex, toArea, toId, x, y, state)
    return Lights.shouldCarStop(naviArea, naviIndex, toArea, toId, x, y, state)
end

-- Console-only integrity check against counts taken from the retail files with tools/scratch/verify_nodes.py.
local EXPECTED = { vehicle = 30587, ped = 37650, navi = 31466, links = 143622, roadCross = 1697, pedLight = 1294 }

addCommandHandler("pathstest", function(source)
    if getElementType(source) ~= "console" then return end
    local t0 = getTickCount()
    Paths.loadAll()
    local loadMs = getTickCount() - t0

    local got = { vehicle = 0, ped = 0, navi = 0, links = 0, roadCross = 0, pedLight = 0 }
    local dangling, misplaced, lights = 0, 0, { [0] = 0, 0, 0, 0 }
    for id = 0, 63 do
        local a = Paths.getLoadedArea(id)
        got.vehicle, got.ped = got.vehicle + a.vehCount, got.ped + a.pedCount
        got.navi, got.links = got.navi + a.naviCount, got.links + a.linkCount
        for i = 0, a.linkCount - 1 do
            local target = Paths.getLoadedArea(a.linkArea[i])
            if not target or a.linkNode[i] >= target.nodeCount then dangling = dangling + 1 end
            if bitExtract(a.linkFlags[i], 0, 1) == 1 then got.roadCross = got.roadCross + 1 end
            if bitExtract(a.linkFlags[i], 1, 1) == 1 then got.pedLight = got.pedLight + 1 end
        end
        for i = 0, a.nodeCount - 1 do
            if Paths.getAreaAt(a.x[i], a.y[i]) ~= id then misplaced = misplaced + 1 end
        end
        for i = 0, a.naviCount - 1 do
            local l = bitExtract(a.naviFlags[i], 16, 2)
            lights[l] = lights[l] + 1
        end
    end

    local ok = dangling == 0
    for k, v in pairs(EXPECTED) do
        local match = got[k] == v
        ok = ok and match
        outputServerLog(("[pathstest] %-9s %6d (expected %6d) %s"):format(k, got[k], v, match and "ok" or "MISMATCH"))
    end
    outputServerLog(("[pathstest] loaded 64 areas in %d ms; dangling links %d; nodes outside own area %d"):format(loadMs, dangling, misplaced))
    outputServerLog(("[pathstest] navi traffic lights: none %d, north-south %d, west-east %d"):format(lights[0], lights[1], lights[2]))

    -- Grove Street cul-de-sac
    for _, kind in ipairs({ "vehicle", "ped" }) do
        local area, id, dist = Paths.findNearestNode(2495, -1687, 13.5, kind, 100)
        if area then
            local n = Paths.getNode(area, id)
            outputServerLog(("[pathstest] nearest %s node to Grove St: %d:%d at %.2f, %.2f, %.2f (%.1fm, %d links)")
                :format(kind, area, id, n.x, n.y, n.z, dist, #Paths.getNodeLinks(area, id)))
        else
            ok = false
            outputServerLog("[pathstest] no " .. kind .. " node near Grove St")
        end
    end
    outputServerLog("[pathstest] " .. (ok and "PASS" or "FAIL"))
end)

-- Console-only check of the light colour table and the stop rule over every lit navi node in the retail data.
addCommandHandler("lightstest", function(source)
    if getElementType(source) ~= "console" then return end
    local ok = true
    local function check(cond, msg)
        if not cond then ok = false; outputServerLog("[lightstest] FAIL " .. msg) end
    end

    check(Lights.getCarLight(1, 0) == "green" and Lights.getCarLight(2, 0) == "red", "state 0")
    check(Lights.getCarLight(1, 1) == "amber" and Lights.getCarLight(2, 1) == "red", "state 1")
    check(Lights.getCarLight(1, 3) == "red" and Lights.getCarLight(2, 3) == "green", "state 3")
    check(Lights.getCarLight(1, 9) == "off" and Lights.getPedSignal(9) == "off", "state 9")
    check(Lights.getPedSignal(2) == "walk" and Lights.getPedSignal(0) == "dont_walk", "ped signal")

    -- Each lit segment appears as two links (one per direction); exactly one direction is governed.
    Paths.loadAll()
    local governed, ungoverned = 0, 0
    for areaId = 0, 63 do
        local a = Paths.getLoadedArea(areaId)
        for id = 0, a.vehCount - 1 do
            for _, link in ipairs(Paths.getNodeLinks(areaId, id)) do
                local navi = Paths.getNaviNode(link.naviArea, link.naviIndex)
                if navi and navi.trafficLight ~= 0 then
                    local fx, fy = Paths.getNodePosition(areaId, id)
                    local tx, ty = Paths.getNodePosition(link.area, link.id)
                    local len = math.sqrt((tx - fx) ^ 2 + (ty - fy) ^ 2)
                    local ux, uy = (tx - fx) / len, (ty - fy) / len
                    local red = navi.trafficLight == Lights.NORTH_SOUTH and 3 or 0
                    local green = navi.trafficLight == Lights.NORTH_SOUTH and 0 or 3
                    local where = ("navi %d:%d via %d:%d->%d:%d"):format(link.naviArea, link.naviIndex, areaId, id, link.area, link.id)
                    local function stops(dist, state)
                        return (Lights.shouldCarStop(link.naviArea, link.naviIndex, link.area, link.id, navi.x - ux * dist, navi.y - uy * dist, state))
                    end
                    if stops(6, red) then
                        governed = governed + 1
                        check(not stops(-6, red), where .. ": stops after the line")
                        check(not stops(20, red), where .. ": stops 20m early")
                        check(not stops(6, green), where .. ": stops on green")
                        check(stops(6, red == 3 and 4 or 1), where .. ": runs amber")
                    else
                        ungoverned = ungoverned + 1
                        check(not stops(6, green), where .. ": ungoverned direction stops")
                    end
                end
            end
        end
    end
    check(governed == 1689 and ungoverned == 1689, ("governed %d / ungoverned %d, expected 1689 each"):format(governed, ungoverned))
    outputServerLog(("[lightstest] lit links: %d governed, %d ungoverned"):format(governed, ungoverned))
    outputServerLog("[lightstest] " .. (ok and "PASS" or "FAIL"))
end)

-- Console-only: GPS routes across the map (route.lua): Grove Street to Doherty, to Las Venturas, and
-- one from the sea.
addCommandHandler("routetest", function(source)
    if getElementType(source) ~= "console" then return end
    local ok = true
    for _, t in ipairs({
        { "Grove Street -> Doherty", 2495, -1687, 13, -2026, 156, 28 },
        { "Grove Street -> Las Venturas strip", 2495, -1687, 13, 2027, 1343, 10 },
        { "Santa Maria Beach -> Angel Pine", 380, -1880, 2, -2150, -2400, 30 },
    }) do
        local t0 = getTickCount()
        local route, length, expanded = Route.find(t[2], t[3], t[4], t[5], t[6], t[7])
        local ms = getTickCount() - t0
        if not route then ok = false end
        outputServerLog(("[routetest] %s: %s"):format(t[1], route and ("%d points, %.0f m, %d nodes expanded, %d ms"):format(#route / 2, length, expanded, ms)
            or ("FAIL " .. tostring(length))))
    end
    outputServerLog("[routetest] " .. (ok and "PASS" or "FAIL"))
end)
