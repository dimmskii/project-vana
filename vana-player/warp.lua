-- Admin warps. Restricted: command.warp / warphere / warps in the ACL (granted to Admin on start).
--   /warp <where> [player]   you (or the player) to a place, a player, or x y z [interior]
--   /warphere <player>       the player to you
--   /warps [filter]          the place names
-- Places (names are case-insensitive; a unique start or part of a name is enough):
--   spots by id (playerconfig.start.spawn, games.dance.floors.1, jobs.trucking.start ...)
--   hospital.1-8 / police.1-7, also by zone (hospital.jefferson); hospital or police alone: the nearest
--   ls / sf / lv: that city's police station
--   interior entrances by vanilla's name (carls, ammun1 ...): outside; name.in: inside; more of one
--   name: name.2, name.3 ...
--   the extra names in config/player.lua (warps)
local W = PlayerConfig.warps
local places, builtAt -- name -> { x, y, z, interior, label }; rebuilt when older than 30 s

local function add(list, name, place)
    name = name:lower():gsub("%s+", "")
    if not list[name] then list[name] = place end
end

local function zoneName(x, y, z, city)
    return (getZoneName(x, y, z, city) or ""):lower():gsub("[^%w]", "")
end

local function elementsOf(resourceName, kind)
    local res = getResourceFromName(resourceName)
    local root = res and getResourceState(res) == "running" and getResourceRootElement(res)
    return root and getElementsByType(kind, root) or {}
end

local function num(element, key) return tonumber(getElementData(element, key)) end

local function build()
    local list = {}
    -- Spots, in every data resource.
    for _, res in ipairs(getResources()) do
        local name = getResourceName(res)
        if name:find("^vana%-data%-") then
            for _, e in ipairs(elementsOf(name, "spot")) do
                local id = getElementID(e) ~= "" and getElementID(e) or getElementData(e, "id")
                local x, y, z = num(e, "posX"), num(e, "posY"), num(e, "posZ")
                if id and x then add(list, id, { x = x, y = y, z = z, interior = num(e, "interior") or 0, label = "spot" }) end
            end
        end
    end
    -- Hospitals and police stations (restart points), numbered and by zone; each city's police station.
    local count = { hospital = 0, police = 0 }
    for _, e in ipairs(elementsOf("vana-data-player", "restart")) do
        local kind = getElementData(e, "kind") or "hospital"
        local x, y, z = num(e, "posX"), num(e, "posY"), num(e, "posZ")
        if x and count[kind] then
            count[kind] = count[kind] + 1
            local zone = getZoneName(x, y, z)
            local place = { x = x, y = y, z = z, interior = 0, label = kind .. " (" .. zone .. ")", kind = kind, rot = num(e, "rotZ") }
            add(list, kind .. "." .. count[kind], place)
            add(list, kind .. "." .. zoneName(x, y, z), place)
            if kind == "police" then
                local city = ({ lossantos = "ls", sanfierro = "sf", lasventuras = "lv" })[zoneName(x, y, z, true)]
                if city then add(list, city, place) end
            end
        end
    end
    -- Interior entrances: where each side puts you (its exit point), outside by name, inside as name.in.
    local seen = {}
    for _, e in ipairs(elementsOf("vana-data-interiors", "entrance")) do
        local name = getElementData(e, "name")
        local ex, ey, ez = num(e, "ex"), num(e, "ey"), num(e, "ez")
        local interior = num(e, "interior") or 0
        if name and ex and getElementData(e, "enabled") ~= "false" then
            local key = name:lower() .. (interior ~= 0 and ".in" or "")
            seen[key] = (seen[key] or 0) + 1
            add(list, key .. (seen[key] > 1 and ("." .. seen[key]) or ""),
                { x = ex, y = ey, z = ez + 1, interior = interior, label = "entrance " .. name .. (interior ~= 0 and " (inside)" or "") })
        end
    end
    -- The config's names, last (they may point at the ones above).
    for name, to in pairs(W) do
        if type(to) == "table" then
            add(list, name, { x = to[1], y = to[2], z = to[3], interior = to[4] or 0, label = "config" })
        elseif list[to:lower()] then
            add(list, name, list[to:lower()])
        end
    end
    places, builtAt = list, getTickCount()
end

local function allPlaces()
    if not places or getTickCount() - builtAt > 30000 then build() end
    return places
end

-- A name -> its entries: an exact name, else every name it starts, else every name containing it.
local function lookup(list, wanted)
    wanted = wanted:lower()
    if list[wanted] then return { wanted } end
    local starts, contains = {}, {}
    for name in pairs(list) do
        if name:sub(1, #wanted) == wanted then starts[#starts + 1] = name
        elseif name:find(wanted, 1, true) then contains[#contains + 1] = name end
    end
    local found = #starts > 0 and starts or contains
    table.sort(found)
    return found
end

-- A player by name (exact, else a unique start or part, case-insensitive; "me" is the source).
local function findPlayer(name, source)
    if name:lower() == "me" and getElementType(source) == "player" then return source end
    local exact = getPlayerFromName(name)
    if exact then return exact end
    local list = {}
    for _, p in ipairs(getElementsByType("player")) do list[getPlayerName(p):lower()] = p end
    local found = lookup(list, name)
    if #found == 1 then return list[found[1]] end
    return nil, #found > 1 and found or nil
end

-- Moves a player there; a driver takes the car (and its passengers) along.
local function warp(player, x, y, z, interior, dimension, rot)
    local vehicle = getPedOccupiedVehicle(player)
    if vehicle and getVehicleOccupant(vehicle, 0) ~= player then
        removePedFromVehicle(player)
        vehicle = nil
    end
    if vehicle then
        setElementVelocity(vehicle, 0, 0, 0)
        setElementInterior(vehicle, interior)
        setElementDimension(vehicle, dimension)
        for _, occupant in pairs(getVehicleOccupants(vehicle)) do
            setElementInterior(occupant, interior)
            setElementDimension(occupant, dimension)
        end
        setElementPosition(vehicle, x, y, z + 0.5)
        if rot then setElementRotation(vehicle, 0, 0, rot) end
    else
        setElementInterior(player, interior)
        setElementDimension(player, dimension)
        setElementPosition(player, x, y, z)
        setElementVelocity(player, 0, 0, 0)
        if rot then setElementRotation(player, 0, 0, rot, "default", true) end
    end
end

-- Where `args` points (a player, coordinates or a place) for `subject`: x, y, z, interior, dimension,
-- rot and a description; or nil and why.
local function resolve(args, source, subject)
    local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
    if x and y and z then
        local interior = tonumber(args[4])
        return x, y, z, interior or 0, 0, nil, ("%.1f, %.1f, %.1f"):format(x, y, z)
    end
    local what = args[1]
    if not what then return end
    -- Players first: a player's exact name, then places, then a player's partial name.
    local player = getPlayerFromName(what) or (what:lower() == "me" and getElementType(source) == "player" and source)
    local list = allPlaces()
    local found = not player and lookup(list, what) or {}
    if not player and #found == 0 then
        local p, many = findPlayer(what, source)
        if not p then
            return nil, many and ("Several players match: " .. table.concat(many, ", ", 1, math.min(#many, 8)))
                or ("No player or place called " .. what .. " (see /warps).")
        end
        player = p
    end
    if player then
        if player == subject then return nil, "That's who's being warped." end
        local px, py, pz = getElementPosition(player)
        local _, _, rz = getElementRotation(player)
        -- Beside them (a car's width to the side if they're in one).
        local side = getPedOccupiedVehicle(player) and 3 or 1.2
        local a = math.rad(rz)
        return px + math.cos(a) * side, py + math.sin(a) * side, pz, getElementInterior(player), getElementDimension(player),
            rz, getPlayerName(player)
    end
    -- hospital / police alone: the nearest to whoever is being warped.
    if (what:lower() == "hospital" or what:lower() == "police") then
        local sx, sy, sz = getElementPosition(subject)
        local best, bestD
        for _, p in pairs(list) do
            if p.kind == what:lower() then
                local d = getDistanceBetweenPoints3D(sx, sy, sz, p.x, p.y, p.z)
                if not bestD or d < bestD then best, bestD = p, d end
            end
        end
        if best then return best.x, best.y, best.z, best.interior, 0, best.rot, best.label end
    end
    if #found > 1 then
        -- Names sharing a place (hospital.1 and hospital.market) are one answer.
        local first = list[found[1]]
        local same = true
        for _, name in ipairs(found) do same = same and list[name] == first end
        if not same then
            return nil, ("%d places match %s: %s%s"):format(#found, what, table.concat(found, ", ", 1, math.min(#found, 10)),
                #found > 10 and " ..." or "")
        end
    end
    local p = list[found[1]]
    return p.x, p.y, p.z, p.interior, 0, p.rot, found[1] .. " (" .. p.label .. ")"
end

local function reply(source, msg)
    if getElementType(source) == "console" then outputServerLog("[warp] " .. msg) else outputChatBox(msg, source, 200, 200, 255) end
end

addCommandHandler("warp", function(source, _, ...)
    local args = { ... }
    if #args == 0 then return reply(source, "Usage: /warp <place|player|x y z [interior]> [player]   (/warps lists places)") end
    -- Whoever is warped: the argument after the destination, else you.
    local subject = getElementType(source) == "player" and source or nil
    local function subjectAfter(taken)
        local name = args[taken + 1]
        if not name then return subject end
        local p, many = findPlayer(name, source)
        if not p then reply(source, many and ("Several players match: " .. table.concat(many, ", ")) or ("No player called " .. name .. ".")) end
        return p
    end
    -- The destination is x y z [interior] or one name; the player's name follows it.
    local taken = 1
    if tonumber(args[1]) and tonumber(args[2]) and tonumber(args[3]) then
        taken = tonumber(args[4]) and 4 or 3
    elseif tonumber(args[1]) then
        return reply(source, "Coordinates are x y z [interior].")
    end
    subject = subjectAfter(taken)
    if not subject then
        if getElementType(source) == "console" and not args[taken + 1] then reply(source, "From the console, name who to warp.") end
        return
    end
    local x, y, z, interior, dimension, rot, what = resolve(args, source, subject)
    if not x then return reply(source, y or "Usage: /warp <place|player|x y z [interior]> [player]") end
    warp(subject, x, y, z, interior, dimension, rot)
    reply(source, ("Warped %s to %s."):format(subject == source and "you" or getPlayerName(subject), what))
    if subject ~= source then outputChatBox("An admin warped you to " .. what .. ".", subject, 200, 200, 255) end
end, true)

addCommandHandler("warphere", function(source, _, name)
    if getElementType(source) ~= "player" then return reply(source, "Only a player can bring someone to them.") end
    if not name then return reply(source, "Usage: /warphere <player>") end
    local target, many = findPlayer(name, source)
    if not target then return reply(source, many and ("Several players match: " .. table.concat(many, ", ")) or ("No player called " .. name .. ".")) end
    if target == source then return reply(source, "You're already here.") end
    local x, y, z, interior, dimension, rot = resolve({ getPlayerName(source) }, source, target)
    warp(target, x, y, z, interior, dimension, rot)
    reply(source, ("Brought %s to you."):format(getPlayerName(target)))
    outputChatBox("An admin brought you to them.", target, 200, 200, 255)
end, true)

addCommandHandler("warps", function(source, _, filter)
    local list = allPlaces()
    local names = {}
    for name in pairs(list) do
        if not filter or name:find(filter:lower(), 1, true) then names[#names + 1] = name end
    end
    table.sort(names)
    if #names == 0 then return reply(source, "No places match " .. tostring(filter) .. ".") end
    -- Chat shows the first 30; the console gets them all.
    local console = getElementType(source) == "console"
    local shown = console and #names or math.min(#names, 30)
    for i = 1, shown, 6 do
        local line = {}
        for j = i, math.min(i + 5, shown) do line[#line + 1] = names[j] end
        reply(source, table.concat(line, ", "))
    end
    reply(source, ("%d places%s. Try /warps <part of a name>: hospital, police, carls, games., jobs. ..."):format(#names,
        shown < #names and (", " .. shown .. " shown") or ""))
end, true)

-- Console-only: the place list builds and every config name resolves.
addCommandHandler("warptest", function(source)
    if getElementType(source) ~= "console" then return end
    build()
    local n, broken = 0, {}
    for _ in pairs(places) do n = n + 1 end
    for name, to in pairs(W) do
        if type(to) == "string" and not places[to:lower()] then broken[#broken + 1] = name .. " -> " .. to end
    end
    local function show(name) local p = places[name] return p and ("%s %.0f,%.0f,%.0f int %d"):format(name, p.x, p.y, p.z, p.interior) or (name .. " missing") end
    outputServerLog(("[warptest] %d places; %s; %s; %s; %s; %s"):format(n, show("cj"), show("carls.in"), show("start"), show("hospital.1"), show("ls")))
    outputServerLog("[warptest] " .. (#broken == 0 and "PASS" or ("FAIL: config names with no place: " .. table.concat(broken, ", "))))
end)
