-- Races, this client's side: the checkpoints (ground markers, or rings for air races) and the opponents'
-- driving (native "racing" drive-to, checkpoint after checkpoint).
local race -- { course, racers, radius, speed, air, dim, next, marker, blip, nextMarker }

local function clear()
    if not race then return end
    for _, e in ipairs({ race.marker, race.blip, race.ahead }) do if isElement(e) then destroyElement(e) end end
end

local function showCheckpoint(n)
    clear()
    local cp, after = race.course[n], race.course[n + 1]
    if not cp then return end
    local kind = race.air and "ring" or "checkpoint"
    race.marker = createMarker(cp[1], cp[2], cp[3] + (race.air and 0 or 0.5), kind, race.air and race.radius or 6, 255, 210, 0, 160)
    setElementDimension(race.marker, race.dim)
    setElementInterior(race.marker, getElementInterior(localPlayer))
    if after then setMarkerTarget(race.marker, after[1], after[2], after[3]) end
    if not after then setMarkerIcon(race.marker, "finish") end
    race.blip = createBlip(cp[1], cp[2], cp[3], 0, 2, 255, 210, 0)
    setElementDimension(race.blip, race.dim)
    if after then
        race.ahead = createBlip(after[1], after[2], after[3], 0, 1, 255, 210, 0, 160)
        setElementDimension(race.ahead, race.dim)
    end
end

addEvent("vana-race:go", true)
addEventHandler("vana-race:go", resourceRoot, function(course, racers, radius, speed, air, dim)
    clear()
    race = nil
    if not course then return end
    race = { course = course, racers = racers, radius = radius, speed = speed, air = air, dim = dim }
    for _, r in ipairs(racers) do r.next = 1 end
    showCheckpoint(1)
end)

addEvent("vana-race:checkpoint", true)
addEventHandler("vana-race:checkpoint", resourceRoot, function(n) if race then showCheckpoint(n) end end)

-- Opponents: drive to their next checkpoint; move on when close.
setTimer(function()
    if not race then return end
    for _, r in ipairs(race.racers) do
        if r.ped and isElement(r.ped) and isElement(r.vehicle) and isElementStreamedIn(r.vehicle) then
            local cp = race.course[r.next]
            if cp then
                local x, y, z = getElementPosition(r.vehicle)
                if getDistanceBetweenPoints3D(x, y, z, cp[1], cp[2], cp[3]) < race.radius then
                    r.next = r.next + 1
                    r.ordered = nil
                    cp = race.course[r.next]
                end
                if cp and r.ordered ~= r.next then
                    if setPedDriveTo(r.ped, r.vehicle, Vector3(cp[1], cp[2], cp[3]), race.speed, "racing", "plough_through") then
                        r.ordered = r.next
                    end
                end
            end
        end
    end
end, 300, 0)
