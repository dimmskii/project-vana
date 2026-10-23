-- Legs: what an aircraft does over time, as timed frames (position, forward and right vectors,
-- velocity, landing gear), built the same on the server and on the client from a short description,
-- so any client can fly any part of one, from any moment, after a handover. Plain Lua.
--   { kind = "flight", id = "46" [, from = ms, to = ms] }
--                                                      a vanilla flight recording (flights.map), or
--                                                      a stretch of it
--   { kind = "hold", x, y, z, heading, speed, radius, fromRise, toRise }
--                                                      a lap of a holding circle through (x, y) at
--                                                      that heading, from z + fromRise to z + toRise
--   { kind = "taxi", points = { {x,y,z}, ... }, from = heading, to = heading }
--                                                      turn on the spot, roll, turn (taxiing)
--   { kind = "park", x, y, z, heading }                standing still
--   { kind = "spline", points = { {x,y,z,speed,ground}, ... }, closed, laps, heli }
--                                                      flown through the points (circuits, helis)
-- A frame: { t, x, y, z, fx, fy, fz, rx, ry, rz, vx, vy, vz, gear } (t in ms from the leg's start).
Legs = {}

local sqrt, sin, cos, atan2, abs, max, min, floor, pi = math.sqrt, math.sin, math.cos, math.atan2 or math.atan, math.abs, math.max, math.min, math.floor, math.pi

Legs.TAXI_SPEED, Legs.TAXI_ACCEL, Legs.TURN_RATE = 8, 1, 30 -- m/s, m/s², degrees/s on the spot
Legs.STEP = 250                                               -- ms between built frames

-- MTA headings (rotZ, degrees: 0 north, anticlockwise) and their forward vector.
local function forwardOf(heading)
    local h = math.rad(heading)
    return -sin(h), cos(h)
end
local function headingOf(fx, fy) return (math.deg(atan2(-fx, fy))) % 360 end
local function wrap180(a) return (a + 180) % 360 - 180 end

local function flatFrame(t, x, y, z, heading, speed, gear)
    local fx, fy = forwardOf(heading)
    return { t = t, x = x, y = y, z = z, fx = fx, fy = fy, fz = 0, rx = fy, ry = -fx, rz = 0,
             vx = fx * speed, vy = fy * speed, vz = 0, gear = gear ~= false }
end

local function park(desc)
    return { flatFrame(0, desc.x, desc.y, desc.z, desc.heading or 0, 0, true) }
end

-- Taxiing: turn on the spot to each segment's heading, roll it (speeding up and slowing to a stop
-- before a turn of more than 30 degrees, or the end), then turn to the final heading.
local function taxi(desc)
    local pts, frames = desc.points, {}
    local t, heading = 0, desc.from or 0
    local step = Legs.STEP / 1000
    local function turnTo(x, y, z, target)
        local delta = wrap180(target - heading)
        local duration = abs(delta) / Legs.TURN_RATE
        local n = max(1, floor(duration / step))
        for k = 1, n do
            frames[#frames + 1] = flatFrame(t + k * duration / n * 1000, x, y, z, heading + delta * k / n, 0, true)
        end
        t, heading = t + duration * 1000, target
    end
    frames[1] = flatFrame(0, pts[1][1], pts[1][2], pts[1][3], heading, 0, true)
    for i = 1, #pts - 1 do
        local a, b = pts[i], pts[i + 1]
        local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
        local len = sqrt(dx * dx + dy * dy)
        if len > 0.5 then
            turnTo(a[1], a[2], a[3], headingOf(dx, dy))
            -- Rolling: trapezoid speed profile, from and to a stop.
            local v, a1 = Legs.TAXI_SPEED, Legs.TAXI_ACCEL
            local accelDist = min(len / 2, v * v / (2 * a1))
            local top = sqrt(2 * a1 * accelDist)
            local cruise = len - 2 * accelDist
            local tAccel = top / a1
            local total = 2 * tAccel + cruise / max(top, 0.1)
            local n = max(1, floor(total / step))
            for k = 1, n do
                local tt = total * k / n
                local d, speed
                if tt < tAccel then d, speed = 0.5 * a1 * tt * tt, a1 * tt
                elseif tt < tAccel + cruise / top then d, speed = accelDist + (tt - tAccel) * top, top
                else
                    local r = total - tt
                    d, speed = len - 0.5 * a1 * r * r, a1 * r
                end
                local f = d / len
                frames[#frames + 1] = flatFrame(t + tt * 1000, a[1] + dx * f, a[2] + dy * f, a[3] + dz * f, heading, speed, true)
            end
            t = t + total * 1000
        end
    end
    local last = pts[#pts]
    if desc.to then turnTo(last[1], last[2], last[3], desc.to) end
    return frames
end

-- Through the points on a Catmull-Rom curve, at the points' speeds; banked into turns (planes up to
-- 35 degrees, helicopters 20, nose down a little with speed); points marked ground are on the
-- runway, wheels down. closed: back to the first point, laps times.
local function spline(desc)
    local P = desc.points
    local n = #P
    local closed = desc.closed
    -- Open curves: lead and tail (if given) shape the ends' tangents only.
    local function at(i)
        if closed then return P[(i - 1) % n + 1] end
        if i < 1 and desc.lead then return desc.lead end
        if i > n and desc.tail then return desc.tail end
        return P[max(1, min(n, i))]
    end
    -- A dense polyline: (x, y, z, speed, ground) every few metres.
    local poly = {}
    local laps = closed and (desc.laps or 1) or 1
    local segments = closed and n * laps or n - 1
    local SUB = 16
    for s = 1, segments do
        local p0, p1, p2, p3 = at(s - 1), at(s), at(s + 1), at(s + 2)
        for k = 0, SUB - 1 do
            local u = k / SUB
            local u2, u3 = u * u, u * u * u
            local function cr(i) return 0.5 * (2 * p1[i] + (p2[i] - p0[i]) * u + (2 * p0[i] - 5 * p1[i] + 4 * p2[i] - p3[i]) * u2 + (3 * p1[i] - p0[i] - 3 * p2[i] + p3[i]) * u3) end
            local ground = p1[5] and p2[5]
            local z = ground and (p1[3] + (p2[3] - p1[3]) * u) or cr(3)
            poly[#poly + 1] = { cr(1), cr(2), z, p1[4] + (p2[4] - p1[4]) * u, ground }
        end
    end
    local endP = closed and at(segments + 1) or P[n]
    poly[#poly + 1] = { endP[1], endP[2], endP[3], endP[4], endP[5] }
    -- Time along it, then frames every STEP.
    local times = { 0 }
    for i = 2, #poly do
        local a, b = poly[i - 1], poly[i]
        local d = sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
        times[i] = times[i - 1] + d / max(1, (a[4] + b[4]) / 2) * 1000
    end
    local frames = {}
    local j = 1
    local bankMax = math.rad(desc.heli and 20 or 35)
    local prevYaw, prevT
    local total = times[#times]
    local t = 0
    while true do
        while j < #poly - 1 and times[j + 1] < t do j = j + 1 end
        local a, b = poly[j], poly[j + 1]
        local span = times[j + 1] - times[j]
        local f = span > 0 and min(1, (t - times[j]) / span) or 0
        local x, y, z = a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
        local speed = a[4] + (b[4] - a[4]) * f
        local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
        local len = sqrt(dx * dx + dy * dy + dz * dz)
        if len < 0.001 then dx, dy, dz, len = 0, 1, 0, 1 end
        dx, dy, dz = dx / len, dy / len, dz / len
        local yaw = atan2(dy, dx)
        local yawRate = 0
        if prevYaw then yawRate = wrap180(math.deg(yaw - prevYaw)) * pi / 180 / max(0.001, (t - prevT) / 1000) end
        prevYaw, prevT = yaw, t
        local fx, fy, fz = dx, dy, dz
        local h = sqrt(fx * fx + fy * fy)
        if desc.heli then
            -- Level, nose a little down with speed.
            local pitch = -math.rad(min(10, speed * 0.3))
            local hx, hy = h > 0 and fx / h or 0, h > 0 and fy / h or 1
            fx, fy, fz = hx * cos(pitch), hy * cos(pitch), sin(pitch)
        end
        local bank = a[5] and 0 or max(-bankMax, min(bankMax, -math.atan(speed * yawRate / 9.81)))
        -- Right: level and square to forward, rolled by the bank.
        local r0x, r0y = fy, -fx
        local rl = sqrt(r0x * r0x + r0y * r0y)
        if rl < 0.001 then r0x, r0y, rl = 1, 0, 1 end
        r0x, r0y = r0x / rl, r0y / rl
        -- up0 = right0 x forward
        local ux, uy, uz = r0y * fz - 0 * fy, 0 * fx - r0x * fz, r0x * fy - r0y * fx
        local rx, ry, rz = r0x * cos(bank) - ux * sin(bank), r0y * cos(bank) - uy * sin(bank), -uz * sin(bank)
        frames[#frames + 1] = { t = t, x = x, y = y, z = z, fx = fx, fy = fy, fz = fz, rx = rx, ry = ry, rz = rz,
                                vx = dx * speed, vy = dy * speed, vz = dz * speed, gear = a[5] or false }
        if t >= total then break end
        t = min(total, t + Legs.STEP)
    end
    -- Wheels down a little before and after the runway (gearMs).
    local gearMs = desc.gearMs or 8000
    local groundAt = {}
    for i, fr in ipairs(frames) do if fr.gear then groundAt[#groundAt + 1] = i end end
    for _, i in ipairs(groundAt) do
        for k = max(1, i - gearMs / Legs.STEP), min(#frames, i + gearMs / Legs.STEP) do frames[k].gear = true end
    end
    return frames
end

-- A stretch of frames, from..to ms, starting at 0.
local function slice(frames, from, to)
    if not from and not to then return frames end
    from, to = from or 0, to or Legs.duration(frames)
    local out = {}
    local function frameAt(t)
        local x, y, z, fx, fy, fz, rx, ry, rz, vx, vy, vz, gear = Legs.sample(frames, t)
        return { t = t - from, x = x, y = y, z = z, fx = fx, fy = fy, fz = fz, rx = rx, ry = ry, rz = rz, vx = vx, vy = vy, vz = vz, gear = gear }
    end
    out[1] = frameAt(from)
    for _, fr in ipairs(frames) do
        if fr.t > from and fr.t < to then
            local c = {}
            for k, v in pairs(fr) do c[k] = v end
            c.t = fr.t - from
            out[#out + 1] = c
        end
    end
    out[#out + 1] = frameAt(to)
    return out
end

-- A lap of a holding circle: through (x, y) at `heading`, turning left round a circle of `radius`,
-- back to the start, climbing or descending from z + fromRise to z + toRise on the way (stacked
-- holds: a plane climbs to its level, circles there, comes back down to land).
local function hold(desc)
    local fx, fy = forwardOf(desc.heading)
    local lx, ly = -fy, fx -- to the left
    local cx, cy = desc.x + lx * desc.radius, desc.y + ly * desc.radius
    local points = {}
    local start = atan2(desc.y - cy, desc.x - cx)
    local r0, r1 = desc.fromRise or 0, desc.toRise or 0
    for k = 0, 8 do
        local a = start + k * pi / 4
        local up = r0 + (r1 - r0) * (1 - cos(k * pi / 8)) / 2
        points[#points + 1] = { cx + cos(a) * desc.radius, cy + sin(a) * desc.radius, desc.z + up, desc.speed, false }
    end
    -- The points either side of the start point shape the curve's tangent there, level, along `heading`.
    local lead = { cx + cos(start - pi / 4) * desc.radius, cy + sin(start - pi / 4) * desc.radius, desc.z + r0, desc.speed, false }
    local tail = { cx + cos(start + pi / 4) * desc.radius, cy + sin(start + pi / 4) * desc.radius, desc.z + r1, desc.speed, false }
    return spline({ points = points, lead = lead, tail = tail, gearMs = 0 })
end

-- The frames of a leg. flights: the flight recordings (AirData.buildFlights).
function Legs.build(desc, flights)
    if desc.kind == "flight" then
        local flight = flights and flights[desc.id]
        return flight and slice(flight.frames, desc.from, desc.to) or {}
    elseif desc.kind == "hold" then return hold(desc)
    elseif desc.kind == "taxi" then return taxi(desc)
    elseif desc.kind == "park" then return park(desc)
    elseif desc.kind == "spline" then return spline(desc)
    end
    return {}
end

function Legs.duration(frames) return frames[#frames] and frames[#frames].t or 0 end

-- The aircraft at t ms into the leg (clamped to its ends): x, y, z, fx, fy, fz, rx, ry, rz, vx, vy, vz, gear.
function Legs.sample(frames, t)
    local n = #frames
    if n == 0 then return nil end
    if t <= frames[1].t or n == 1 then
        local f = frames[1]
        return f.x, f.y, f.z, f.fx, f.fy, f.fz, f.rx, f.ry, f.rz, n == 1 and 0 or f.vx, n == 1 and 0 or f.vy, n == 1 and 0 or f.vz, f.gear
    end
    if t >= frames[n].t then
        local f = frames[n]
        return f.x, f.y, f.z, f.fx, f.fy, f.fz, f.rx, f.ry, f.rz, 0, 0, 0, f.gear
    end
    local lo, hi = 1, n
    while hi - lo > 1 do
        local mid = floor((lo + hi) / 2)
        if frames[mid].t <= t then lo = mid else hi = mid end
    end
    local a, b = frames[lo], frames[hi]
    local u = (t - a.t) / max(1, b.t - a.t)
    local function l(k) return a[k] + (b[k] - a[k]) * u end
    local fx, fy, fz = l("fx"), l("fy"), l("fz")
    local fl = sqrt(fx * fx + fy * fy + fz * fz)
    fx, fy, fz = fx / fl, fy / fl, fz / fl
    local rx, ry, rz = l("rx"), l("ry"), l("rz")
    -- Square to forward again, then unit length.
    local d = rx * fx + ry * fy + rz * fz
    rx, ry, rz = rx - d * fx, ry - d * fy, rz - d * fz
    local rl = sqrt(rx * rx + ry * ry + rz * rz)
    if rl > 0 then rx, ry, rz = rx / rl, ry / rl, rz / rl end
    return l("x"), l("y"), l("z"), fx, fy, fz, rx, ry, rz, l("vx"), l("vy"), l("vz"), u < 0.5 and a.gear or b.gear
end

-- The first and last moments a frame is on the ground (wheels on the runway: within `above` m of the
-- leg's first or last height), for scheduling runways: liftoff and touchdown ms.
function Legs.groundTimes(frames, above)
    above = above or 3
    local first, last = frames[1], frames[#frames]
    local liftoff, touchdown = 0, Legs.duration(frames)
    for _, fr in ipairs(frames) do
        if fr.z > first.z + above then liftoff = fr.t break end
    end
    for i = #frames, 1, -1 do
        if frames[i].z > last.z + above then touchdown = frames[i].t break end
    end
    return liftoff, touchdown
end
