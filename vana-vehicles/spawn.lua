-- Admin spawning. Restricted: command.car / command.spawncar (granted to Admin by vana-player).
--   /car <vehicle> [player]       you (or the player) in the driver's seat of a new one, replacing the
--                                 last one /car gave them; it isn't kept by the registry ("vana:managed")
--   /spawncar <vehicle> [player]  a new one, empty, in front of you (or the player): an ordinary car
-- A vehicle is a model ID (400-611), GTA's name for it, or an alias (config: spawnAliases); a
-- unique start or part of a name is enough, as /warp's places.
local C = VehicleConfig
local names       -- normalised name -> model
local given = {}  -- player -> the vehicle /car gave them

local function normalise(s) return (s:lower():gsub("[^%w]", "")) end

local function allNames()
    if names then return names end
    names = {}
    for model = 400, 611 do
        local name = getVehicleNameFromModel(model)
        if name and name ~= "" then names[normalise(name)] = names[normalise(name)] or model end
    end
    for alias, model in pairs(C.spawnAliases) do names[normalise(alias)] = model end
    return names
end

-- A vehicle -> its model; or nil and why.
local function resolve(what)
    local id = tonumber(what)
    if id then
        if id >= 400 and id <= 611 and getVehicleNameFromModel(id) ~= "" then return id end
        return nil, ("No vehicle model %d (400-611)."):format(id)
    end
    local list, wanted = allNames(), normalise(what)
    if wanted == "" then return nil, "Name a vehicle." end
    if list[wanted] then return list[wanted] end
    local starts, contains = {}, {}
    for name, model in pairs(list) do
        if name:sub(1, #wanted) == wanted then starts[model] = name
        elseif name:find(wanted, 1, true) then contains[model] = name end
    end
    local found = next(starts) and starts or contains
    local models = {}
    for model in pairs(found) do models[#models + 1] = model end
    if #models == 1 then return models[1] end
    if #models == 0 then return nil, ("No vehicle called %s."):format(what) end
    table.sort(models)
    local shown = {}
    for i = 1, math.min(#models, 10) do shown[i] = ("%s (%d)"):format(getVehicleNameFromModel(models[i]), models[i]) end
    return nil, ("%d vehicles match %s: %s%s"):format(#models, what, table.concat(shown, ", "), #models > 10 and " ..." or "")
end

-- A player by name (exact, else a unique start or part, case-insensitive; "me" is the source).
local function findPlayer(name, source)
    if name:lower() == "me" and getElementType(source) == "player" then return source end
    local exact = getPlayerFromName(name)
    if exact then return exact end
    local found
    for _, p in ipairs(getElementsByType("player")) do
        local n = getPlayerName(p):gsub("#%x%x%x%x%x%x", ""):lower()
        if n:find(name:lower(), 1, true) then
            if found then return nil, "Several players match " .. name .. "." end
            found = p
        end
    end
    return found, not found and ("No player called " .. name .. ".") or nil
end

-- "a Sultan", "an Infernus".
local function aName(model)
    local name = getVehicleNameFromModel(model)
    return (name:find("^[AEIOUaeiou]") and "an " or "a ") .. name
end

local function reply(source, msg)
    if getElementType(source) == "console" then outputServerLog("[spawn] " .. msg) else outputChatBox(msg, source, 200, 200, 255) end
end

local function create(model, x, y, z, rz, interior, dimension)
    local vehicle = createVehicle(model, x, y, z, 0, 0, rz)
    if not vehicle then return end
    setElementInterior(vehicle, interior)
    setElementDimension(vehicle, dimension)
    setVehicleFuel(vehicle, C.fuel.tank) -- a full tank (nothing for those that don't use fuel)
    return vehicle
end

-- Everyone out, then gone.
local function removeVehicle(vehicle)
    if not isElement(vehicle) then return end
    for _, occupant in pairs(getVehicleOccupants(vehicle)) do removePedFromVehicle(occupant) end
    destroyElement(vehicle)
end

-- The command's target: the named player, else whoever typed it.
local function targetOf(source, name, usage)
    if name then
        local p, why = findPlayer(name, source)
        if not p then reply(source, why) end
        return p
    end
    if getElementType(source) ~= "player" then reply(source, "From the console, name a player: " .. usage) return end
    return source
end

addCommandHandler("car", function(source, _, what, name)
    local usage = "/car <vehicle: name or ID> [player]"
    if not what then return reply(source, "Usage: " .. usage) end
    local model, why = resolve(what)
    if not model then return reply(source, why) end
    local player = targetOf(source, name, usage)
    if not player then return end
    if isPedDead(player) then return reply(source, getPlayerName(player) .. " is dead.") end
    local x, y, z = getElementPosition(player)
    local _, _, rz = getElementRotation(player)
    local current = getPedOccupiedVehicle(player)
    if current then
        local _, _, vrz = getElementRotation(current)
        rz = vrz
        x, y, z = getElementPosition(current)
        if current == given[player] then
            removeVehicle(current) -- replaced where it stands
        else
            -- Out of someone else's car: the new one alongside it.
            removePedFromVehicle(player)
            local h = math.rad(rz)
            x, y = x + math.cos(h) * 4, y + math.sin(h) * 4
        end
    end
    if isElement(given[player]) and given[player] ~= current then removeVehicle(given[player]) end
    local vehicle = create(model, x, y, z + 1, rz, getElementInterior(player), getElementDimension(player))
    if not vehicle then return reply(source, "Couldn't create " .. aName(model) .. " there.") end
    setElementData(vehicle, "vana:managed", true, false) -- ours to replace: not kept by the registry
    given[player] = vehicle
    warpPedIntoVehicle(player, vehicle, 0)
    setVehicleEngineState(vehicle, true)
    reply(source, ("%s in %s (%d)."):format(player == source and "You're" or (getPlayerName(player) .. " is"), aName(model), model))
    if player ~= source then outputChatBox(("An admin put you in %s."):format(aName(model)), player, 200, 200, 255) end
end, true)

addCommandHandler("spawncar", function(source, _, what, name)
    local usage = "/spawncar <vehicle: name or ID> [player]"
    if not what then return reply(source, "Usage: " .. usage) end
    local model, why = resolve(what)
    if not model then return reply(source, why) end
    local player = targetOf(source, name, usage)
    if not player then return end
    local from = getPedOccupiedVehicle(player) or player
    local x, y, z = getElementPosition(from)
    local _, _, rz = getElementRotation(from)
    local ahead = C.spawnAhead[getVehicleType(model)] or 5
    if from ~= player then ahead = ahead + 3 end -- clear of the car they're in
    local h = math.rad(rz)
    local vehicle = create(model, x - math.sin(h) * ahead, y + math.cos(h) * ahead, z + 1, rz, getElementInterior(player), getElementDimension(player))
    if not vehicle then return reply(source, "Couldn't create " .. aName(model) .. " there.") end
    local text = ("%s (%d), %d m in front of %s."):format(aName(model), model, ahead, player == source and "you" or getPlayerName(player))
    reply(source, text:sub(1, 1):upper() .. text:sub(2))
end, true)

-- A /car car goes with its player once nobody's in it.
addEventHandler("onPlayerQuit", root, function()
    local vehicle = given[source]
    given[source] = nil
    if isElement(vehicle) and not next(getVehicleOccupants(vehicle) or {}) then destroyElement(vehicle) end
end)

-- For vehicletest: names resolve as typed.
function spawnResolve(what) return resolve(what) end
