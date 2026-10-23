-- Flies the aircraft this client simulates along the legs the server sends (legs.lua): every frame
-- the aircraft is put where its leg has it at that moment, with its velocity (so everyone else's
-- game sees it move), landing gear and rotors. The same legs and clock as the server's, so another
-- client taking over carries on from where this one was.
local flights = {}  -- flight recording id -> frames (from the server, once each)
local wanted = {}   -- flight id -> true while asked for
local flying = {}   -- vehicle -> { pilot, desc, frames, started, loop, heli }
local gearStats = {} -- vehicle -> { frames, foundUp, stillUp } while vana-air:sync is on

local function framesFor(desc)
    if desc.kind ~= "flight" then return Legs.build(desc) end
    if not flights[desc.id] then
        if not wanted[desc.id] then
            wanted[desc.id] = true
            triggerServerEvent("vana-air:needFlight", resourceRoot, desc.id)
        end
        return nil
    end
    return Legs.build(desc, flights)
end

-- The recordings were made with an AT-400, and taxi and parking heights come from the ATP mod: any
-- other model at those heights sits too low or too high. Near the ground (wheels down) a plane is put
-- at its model's resting height over the ground instead, blending back to the leg's height over the
-- first BLEND m above it. The resting height is what the game's own suspension gives it (GTA rests a
-- vehicle by its height above road, CAutomobile::PlaceOnRoadProperly, which Lua can't read): the
-- first time a model stands parked here, it's dropped onto its wheels and left to settle, and the
-- height it comes to rest at is kept. Until then, an estimate from the model's wheels (their
-- positions less their radius), or its bounding box's bottom (the fuselage: a little low).
local BLEND = 10
local rests = {}    -- model -> resting height of its position over the ground (settled)
local guesses = {}  -- model -> the bounding box's estimate
local settling = {} -- vehicle -> { since, model }

-- Heights measured by any client (or kept in the config), from the server.
local function loadRests()
    for model, h in pairs(getElementData(resourceRoot, "vana:rests") or {}) do rests[tonumber(model)] = h end
end
loadRests()
addEventHandler("onClientElementDataChange", resourceRoot, function(key) if key == "vana:rests" then loadRests() end end)

local function ground(x, y, z)
    local gz = getGroundPosition(x, y, z + 3)
    if not gz or gz == 0 then return nil end
    return gz
end

local function restOf(vehicle)
    local model = getElementModel(vehicle)
    if rests[model] then return rests[model] end
    if guesses[model] == nil then
        local lowest
        for name in pairs(getVehicleComponents(vehicle) or {}) do
            if name:find("^wheel_") then
                local _, _, wz = getVehicleComponentPosition(vehicle, name, "root")
                if wz and (not lowest or wz < lowest) then lowest = wz end
            end
        end
        if lowest then
            local size = getVehicleModelWheelSize(model, "rear_axle")
            guesses[model] = -(lowest - (tonumber(size) or 1) / 2)
        else
            local _, _, minZ = getElementBoundingBox(vehicle)
            guesses[model] = minZ and -minZ or false
        end
    end
    return guesses[model] or nil
end

local function onGround(vehicle, x, y, z)
    local gz = ground(x, y, z)
    local rest = restOf(vehicle)
    if not gz or not rest then return z end
    rest = gz + rest
    local above = z - rest
    if above >= BLEND then return z end
    local w = above <= 0 and 1 or 1 - above / BLEND
    return z + (rest - z) * w
end

-- A parked plane of a model with no resting height yet: dropped from just above, then left alone
-- (the caller skips it) until it stops; true while settling.
local function settle(vehicle, x, y, z, matrix, now)
    local model = getElementModel(vehicle)
    if rests[model] or getVehicleType(vehicle) ~= "Plane" then return false end
    local s = settling[vehicle]
    if not s then
        local gz = ground(x, y, z)
        if not gz then return false end
        local guess = restOf(vehicle) or 2
        matrix[4] = { x, y, gz + guess + 3, 1 }
        setElementMatrix(vehicle, matrix)
        setElementVelocity(vehicle, 0, 0, 0)
        setVehicleLandingGearDown(vehicle, true)
        settling[vehicle] = { since = now, model = model }
        return true
    end
    local vx, vy, vz = getElementVelocity(vehicle)
    local still = (vx * vx + vy * vy + vz * vz) * 2500 < 0.01
    if now - s.since > 2500 and still and isVehicleOnGround(vehicle) then
        local px, py, pz = getElementPosition(vehicle)
        local gz = ground(px, py, pz + 20)
        -- Fallen through the ground (or onto something): no measurement, the estimate stays.
        if gz and pz - gz > 0.2 and pz - gz < 10 then
            rests[model] = pz - gz
            triggerServerEvent("vana-air:rest", resourceRoot, model, pz - gz) -- shared with everyone
            if Debug.on("sync") then Debug.log("sync", ("%s rests %.2f m over the ground (estimated %.2f)"):format(getVehicleName(vehicle), pz - gz, guesses[model] or -1)) end
        else
            rests[model] = restOf(vehicle) or 2
            if Debug.on("sync") then Debug.log("sync", ("%s didn't settle on the ground (at %.1f, ground %s): keeping the estimate %.2f m"):format(getVehicleName(vehicle), pz, tostring(gz), rests[model])) end
        end
        settling[vehicle] = nil
        return false
    end
    if now - s.since > 10000 then
        -- Never settled (or fell through): keep the estimate, and don't try this model again here.
        settling[vehicle] = nil
        rests[model] = restOf(vehicle) or 2
        if Debug.on("sync") then Debug.log("sync", ("%s never settled: keeping the estimate %.2f m"):format(getVehicleName(vehicle), rests[model])) end
        return false
    end
    return true
end

addEvent("vana-air:flight", true)
addEventHandler("vana-air:flight", resourceRoot, function(id, packed)
    local frames = {}
    for i, p in ipairs(packed) do
        frames[i] = { t = p[1], x = p[2], y = p[3], z = p[4], fx = p[5], fy = p[6], fz = p[7], rx = p[8], ry = p[9], rz = p[10],
                      vx = p[11], vy = p[12], vz = p[13], gear = p[14] == 1 }
    end
    flights[id] = { frames = frames }
    wanted[id] = nil
    -- Legs that waited for it.
    for _, f in pairs(flying) do
        if not f.frames and f.desc.kind == "flight" and f.desc.id == id then f.frames = framesFor(f.desc) end
    end
end)

addEvent("vana-air:fly", true)
addEventHandler("vana-air:fly", resourceRoot, function(vehicle, pilot, desc, elapsed, loop, heli)
    if not isElement(vehicle) then return end
    flying[vehicle] = { pilot = pilot, desc = desc, frames = framesFor(desc), started = getTickCount() - elapsed, loop = loop, heli = heli }
    -- Flown aircraft pass through each other (they're on separate timings; a clip shouldn't wreck them).
    for other in pairs(flying) do
        if other ~= vehicle and isElement(other) then
            setElementCollidableWith(vehicle, other, false)
            setElementCollidableWith(other, vehicle, false)
        end
    end
end)

addEvent("vana-air:stop", true)
addEventHandler("vana-air:stop", resourceRoot, function(vehicle) flying[vehicle] = nil end)

addEventHandler("onClientElementDestroy", root, function() flying[source], settling[source] = nil, nil end)

addEventHandler("onClientPreRender", root, function()
    local now = getTickCount()
    for vehicle, f in pairs(flying) do
        if not isElement(vehicle) then
            flying[vehicle] = nil
        elseif not isElement(f.pilot) or isPedDead(f.pilot) or getPedOccupiedVehicle(f.pilot) ~= vehicle then
            -- No pilot, no flying: physics has it now.
            flying[vehicle] = nil
        elseif f.frames and isElementStreamedIn(vehicle) and isElementSyncer(vehicle) then
            local t = now - f.started
            if f.loop then t = t % f.loop end
            local x, y, z, fx, fy, fz, rx, ry, rz, vx, vy, vz, gear = Legs.sample(f.frames, t)
            -- up = right x forward
            local ux, uy, uz
            if x then ux, uy, uz = ry * fz - rz * fy, rz * fx - rx * fz, rx * fy - ry * fx end
            if x and f.desc.kind == "park" and settle(vehicle, x, y, z, { { rx, ry, rz, 0 }, { fx, fy, fz, 0 }, { ux, uy, uz, 0 }, { x, y, z, 1 } }, now) then
                x = nil -- left to settle on its wheels
            elseif x and gear and not f.heli then
                z = onGround(vehicle, x, y, z)
            end
            if x then
                setElementMatrix(vehicle, { { rx, ry, rz, 0 }, { fx, fy, fz, 0 }, { ux, uy, uz, 0 }, { x, y, z, 1 } })
                setElementVelocity(vehicle, vx / 50, vy / 50, vz / 50)
                setElementAngularVelocity(vehicle, 0, 0, 0)
                if f.heli then
                    setVehicleRotorSpeed(vehicle, 0.2)
                elseif getVehicleType(vehicle) == "Plane" then
                    local before = getVehicleLandingGearDown(vehicle)
                    setVehicleLandingGearDown(vehicle, gear)
                    if Debug.on("sync") and gear then
                        -- Wheels wanted down: found up (raised since the last frame), still up after asking.
                        local st = gearStats[vehicle] or { frames = 0, foundUp = 0, stillUp = 0 }
                        gearStats[vehicle] = st
                        st.frames = st.frames + 1
                        if not before then st.foundUp = st.foundUp + 1 end
                        if not getVehicleLandingGearDown(vehicle) then st.stillUp = st.stillUp + 1 end
                    end
                end
            end
        end
    end
end)

-- vana-air:sync: how the landing gear fares while it should be down (docs/debug.md).
setTimer(function()
    for vehicle, st in pairs(gearStats) do
        if isElement(vehicle) and st.frames > 0 then
            Debug.log("sync", ("gear of %s (%s): wanted down %d frames, found up %d, still up after asking %d; driver %s, on ground %s")
                :format(getVehicleName(vehicle), tostring(getElementData(vehicle, "vana:air")), st.frames, st.foundUp, st.stillUp,
                    tostring(getVehicleController(vehicle) and getElementType(getVehicleController(vehicle))), tostring(isVehicleOnGround(vehicle))))
        end
        gearStats[vehicle] = nil
    end
end, 3000, 0)
