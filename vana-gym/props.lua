-- Gym props, placed and moved as the vanilla gym scripts do: the barbell rests on the bench and the
-- dumbbells by the mat until the user's hands pick them up partway through the get-on animation (and put
-- them back partway through the get-off); the bike's pedals turn while someone rides. Local objects only.
local props = {}  -- machine index -> { { object, def } }
local users = {}  -- machine index -> { player, phase = "on"/"off", since }

-- SA's CMatrix::SetRotate (attach rotations): the child's right, forward and up axes in the parent's frame.
local function rotationAxes(rx, ry, rz)
    rx, ry, rz = math.rad(rx), math.rad(ry), math.rad(rz)
    local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    return { cz * cy - sz * sx * sy, cz * sx * sy + sz * cy, -cx * sy },
           { -sz * cx, cz * cx, sx },
           { sz * sx * cy + cz * sy, sz * sy - cz * sx * cy, cx * cy }
end

local function inFrame(axes, v) -- v (right, forward, up) in a frame given by its three axes
    return {
        v[1] * axes[1][1] + v[2] * axes[2][1] + v[3] * axes[3][1],
        v[1] * axes[1][2] + v[2] * axes[2][2] + v[3] * axes[3][2],
        v[1] * axes[1][3] + v[2] * axes[2][3] + v[3] * axes[3][3],
    }
end

-- The machine's own frame: its heading turns right and forward about the vertical.
local function machineAxes(machine)
    local h = math.rad(machine.heading)
    return { { math.cos(h), math.sin(h), 0 }, { -math.sin(h), math.cos(h), 0 }, { 0, 0, 1 } }
end

local function restMatrix(machine, def, spin)
    local frame = machineAxes(machine)
    local r = def.rest
    local local1, local2, local3 = rotationAxes(r[4] + (spin or 0), r[5], r[6])
    local p = inFrame(frame, r)
    return {
        inFrame(frame, local1), inFrame(frame, local2), inFrame(frame, local3),
        { machine.x + p[1], machine.y + p[2], machine.z + p[3] },
    }
end

local function setMatrix(object, m)
    setElementMatrix(object, {
        { m[1][1], m[1][2], m[1][3], 0 }, { m[2][1], m[2][2], m[2][3], 0 },
        { m[3][1], m[3][2], m[3][3], 0 }, { m[4][1], m[4][2], m[4][3], 1 },
    })
end

-- Is this prop in the user's hand right now?
local function held(index, def)
    local u = users[index]
    if not def.bone or not u or not isElement(u.player) or not isElementStreamedIn(u.player) or isPedDead(u.player) then return false end
    local m = Gym.machines[GymEquipment[index].kind]
    local t = getTickCount() - u.since
    if u.phase == "on" then return t >= def.pickup * m.getonMs end
    return t < def.putdown * m.getoffMs
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    for index, machine in ipairs(GymEquipment) do
        for _, def in ipairs(Gym.props[machine.kind] or {}) do
            local object = createObject(def.model, machine.x, machine.y, machine.z)
            if object then
                setElementInterior(object, machine.interior)
                setElementCollisionsEnabled(object, false)
                setMatrix(object, restMatrix(machine, def))
                props[index] = props[index] or {}
                table.insert(props[index], { object = object, def = def, angle = 0, wasHeld = false })
            end
        end
    end
    triggerServerEvent("vana-gym:hello", resourceRoot)
end)

addEvent("vana-gym:use", true)
addEventHandler("vana-gym:use", resourceRoot, function(index, player, phase, elapsed)
    users[index] = phase ~= "free" and { player = player, phase = phase, since = getTickCount() - (elapsed or 0) } or nil
end)

-- After the peds' bones are posed for this frame, so held props sit exactly in the hands.
addEventHandler("onClientPedsProcessed", root, function()
    local now = getTickCount()
    for index, list in pairs(props) do
        local machine = GymEquipment[index]
        local u = users[index]
        for _, prop in ipairs(list) do
            local def = prop.def
            if held(index, def) then
                local b = getElementBoneMatrix(u.player, def.bone)
                if b then
                    local axes = { b[1], b[2], b[3] }
                    local o = inFrame(axes, def.hold)
                    setMatrix(prop.object, { b[1], b[2], b[3], { b[4][1] + o[1], b[4][2] + o[2], b[4][3] + o[3] } })
                    prop.wasHeld = true
                end
            elseif prop.wasHeld then
                setMatrix(prop.object, restMatrix(machine, def))
                prop.wasHeld = false
            end
            if def.spin and u and u.phase == "on" and now - u.since >= Gym.machines[machine.kind].getonMs then
                prop.lastSpin = prop.lastSpin or now
                prop.angle = (prop.angle + (now - prop.lastSpin) / 1000 / def.spin * 360) % 360
                prop.lastSpin = now
                setMatrix(prop.object, restMatrix(machine, def, prop.angle))
            else
                prop.lastSpin = nil
            end
        end
    end
end)
