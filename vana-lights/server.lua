-- Vanilla SA cycle (CTrafficLights::LightForCars1/2, LightForPeds: CTimer ms / 2 & 16383), in game-time ms.
local PHASES = {
    { state = 0, ms = 10000, name = "north-south green" },
    { state = 1, ms = 2000, name = "north-south amber" },
    { state = 3, ms = 10000, name = "west-east green" },
    { state = 4, ms = 2000, name = "west-east amber" },
    { state = 2, ms = 8768, name = "all red, peds walk" },
}

local phase, phaseStarted, phaseLength, timer
local listeners = {}

local function advance()
    phase = phase % #PHASES + 1
    local p = PHASES[phase]
    setTrafficLightState(p.state)
    phaseStarted, phaseLength = getTickCount(), math.max(50, p.ms / getGameSpeed())
    timer = setTimer(advance, phaseLength, 1)
    for _, fn in ipairs(listeners) do fn(p.state) end
end

-- Returns the current MTA light state, the phase name and the real-time ms left in it.
function getPhase()
    local p = PHASES[phase]
    return p.state, p.name, math.max(0, phaseLength - (getTickCount() - phaseStarted))
end

addEventHandler("onResourceStart", resourceRoot, function()
    setTrafficLightsLocked(true)
    phase = 0
    advance()
end)

addEventHandler("onResourceStop", resourceRoot, function()
    setTrafficLightState("auto")
end)

-- Console-only: runs one cycle at 10x game speed and checks order and durations.
addCommandHandler("lightcycletest", function(source)
    if getElementType(source) ~= "console" then return end
    local speed = getGameSpeed()
    setGameSpeed(10)
    if isTimer(timer) then killTimer(timer) end
    phase = #PHASES

    local seen = {}
    listeners[1] = function(state) seen[#seen + 1] = { state = state, at = getTickCount() } end
    advance()

    setTimer(function()
        listeners[1] = nil
        setGameSpeed(speed)
        local ok = #seen >= #PHASES + 1
        for i = 1, #PHASES do
            local expected = PHASES[i]
            local got, nextAt = seen[i], seen[i + 1] and seen[i + 1].at
            local took = got and nextAt and nextAt - got.at or -1
            local want = expected.ms / 10
            local match = got and got.state == expected.state and math.abs(took - want) <= 100
            ok = ok and match
            outputServerLog(("[lightcycletest] state %d %-20s %4d ms (expected %4d) %s")
                :format(got and got.state or -1, expected.name, took, want, match and "ok" or "MISMATCH"))
        end
        outputServerLog("[lightcycletest] locked=" .. tostring(areTrafficLightsLocked()) .. " " .. (ok and "PASS" or "FAIL"))
    end, 3700, 1)
end)
