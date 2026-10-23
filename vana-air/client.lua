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
-- other model at those heights sits too low or too high. Near the ground (wheels down) a plane is
-- put on the ground by its own model's bottom instead, blending back to the leg's height over the
-- first BLEND m above it.
local BLEND = 10
local bottoms = {} -- model -> its bounding box's lowest point, below the vehicle's position
local function onGround(vehicle, x, y, z)
    local model = getElementModel(vehicle)
    if not bottoms[model] then
        local _, _, minZ = getElementBoundingBox(vehicle)
        bottoms[model] = minZ or false
    end
    local minZ = bottoms[model]
    if not minZ then return z end
    local gz = getGroundPosition(x, y, z + 3)
    if not gz or gz == 0 then return z end
    local rest = gz - minZ
    local above = z - rest
    if above >= BLEND then return z end
    local w = above <= 0 and 1 or 1 - above / BLEND
    return z + (rest - z) * w
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

addEventHandler("onClientElementDestroy", root, function() flying[source] = nil end)

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
            if x and gear and not f.heli then z = onGround(vehicle, x, y, z) end
            if x then
                -- up = right x forward
                local ux, uy, uz = ry * fz - rz * fy, rz * fx - rx * fz, rx * fy - ry * fx
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
