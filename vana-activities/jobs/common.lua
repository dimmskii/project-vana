-- Shared bits for the vehicle side jobs.
Job = {}

-- The player's vehicle if they're driving one of `models` ({ [model] = true }).
function Job.vehicle(session, models)
    local v = getPedOccupiedVehicle(session.player)
    return v and models[getElementModel(v)] and getVehicleController(v) == session.player and v or nil
end

function Job.stopped(vehicle, limit)
    local vx, vy, vz = getElementVelocity(vehicle)
    return vx * vx + vy * vy + vz * vz < (limit or 0.0016)
end

function Job.set(list)
    local s = {}
    for _, v in ipairs(list) do s[v] = true end
    return s
end

-- The nearest of a list of { x, y, z } points.
function Job.nearest(points, x, y, z)
    local best, bestD
    for _, p in ipairs(points) do
        local d = getDistanceBetweenPoints3D(x, y, z, p[1], p[2], p[3])
        if not bestD or d < bestD then best, bestD = p, d end
    end
    return best, bestD
end

function Job.civilian()
    return Jobs.civilians[math.random(#Jobs.civilians)]
end

-- Fails the job if the player is out of the job vehicle too long or it's wrecked; returns the vehicle
-- while all is well.
function Job.watchVehicle(session, models, graceMs, failKey, wreckedKey)
    local d = session.data
    local v = Job.vehicle(session, models)
    if not v then
        local any = getPedOccupiedVehicle(session.player)
        if any and models[getElementModel(any)] and isVehicleBlown(any) then session:fail(wreckedKey or failKey) return nil end
        d.outSince = d.outSince or getTickCount()
        if getTickCount() - d.outSince > graceMs then session:fail(failKey) end
        return nil
    end
    d.outSince = nil
    if isVehicleBlown(v) then session:fail(wreckedKey or failKey) return nil end
    return v
end
