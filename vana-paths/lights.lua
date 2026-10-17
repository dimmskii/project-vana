-- Traffic light colours and the vanilla stop rule (CTrafficLights::ShouldCarStopForLight).
-- See docs/paths-and-lights.md for how this was derived.
Lights = {}

Lights.NORTH_SOUTH, Lights.WEST_EAST = 1, 2
Lights.STOP_DISTANCE = 12

-- MTA light state -> { north-south colour, west-east colour }
local CAR_COLOURS = {
    [0] = { "green", "red" },
    [1] = { "amber", "red" },
    [2] = { "red", "red" },
    [3] = { "red", "green" },
    [4] = { "red", "amber" },
    [5] = { "green", "green" },
    [6] = { "amber", "amber" },
    [7] = { "amber", "green" },
    [8] = { "green", "amber" },
    [9] = { "off", "off" },
}

-- lightType: a navi node's trafficLight value (1 north-south, 2 west-east).
function Lights.getCarLight(lightType, state)
    local colours = CAR_COLOURS[state or getTrafficLightState()]
    if not colours or not colours[lightType] then return false end
    return colours[lightType]
end

function Lights.getPedSignal(state)
    state = state or getTrafficLightState()
    if state == 9 then return "off" end
    return state == 2 and "walk" or "dont_walk"
end

-- The light governing a car on the link through this navi node heading to node (toArea, toId),
-- as the navi node with dirX/dirY turned to point along the direction of travel; false if none.
function Lights.getGoverningLight(naviArea, naviIndex, toArea, toId)
    local navi = Paths.getNaviNode(naviArea, naviIndex)
    if not navi or navi.trafficLight == 0 then return false end

    local towardTarget = toArea == navi.targetArea and toId == navi.targetId
    if towardTarget ~= navi.trafficLightDirection then return false end

    -- The navi direction points at the target node; flip it for traffic heading the other way.
    if not towardTarget then navi.dirX, navi.dirY = -navi.dirX, -navi.dirY end
    return navi
end

-- Whether a car at (x, y) on that link must stop. Also returns how far ahead of the car the stop point is.
function Lights.shouldCarStop(naviArea, naviIndex, toArea, toId, x, y, state)
    local light = Lights.getGoverningLight(naviArea, naviIndex, toArea, toId)
    if not light then return false end

    local colour = Lights.getCarLight(light.trafficLight, state)
    if colour ~= "amber" and colour ~= "red" then return false end

    local ahead = (light.x - x) * light.dirX + (light.y - y) * light.dirY
    return ahead > 0 and ahead < Lights.STOP_DISTANCE, ahead
end
