-- The shooting range, this client's side: three rounds in your lane against two rivals in theirs.
-- Round 1: first to destroy three targets. Round 2: the same, with targets advancing. Round 3: one target
-- at a time, each part shot off is a point, first to 20. A target counts as destroyed when enough of its
-- parts are shot off. Rivals score at a set pace per weapon (ours).
local G = Games.range
local run -- { range, weapon, dim, round, mine, rivals, target, parts, ... }

local function clearTarget()
    for _, p in ipairs(run and run.parts or {}) do if isElement(p) then destroyElement(p) end end
    if run then run.parts, run.hits = {}, 0 end
end

local function laneOrigin(offset, distance)
    local r = G.ranges[run.range]
    local h = math.rad(r.heading)
    local fx, fy, rx, ry = -math.sin(h), math.cos(h), math.cos(h), math.sin(h)
    return r.booth[1] + fx * distance + rx * offset, r.booth[2] + fy * distance + ry * offset, r.booth[3] + 1
end

local function spawnTarget(distance)
    clearTarget()
    local r = G.ranges[run.range]
    local x, y, z = laneOrigin(0, distance)
    for i, model in ipairs(G.parts) do
        local o = createObject(model, x, y, z, 0, 0, r.heading)
        setElementInterior(o, r.interior)
        setElementDimension(o, run.dim)
        setElementCollisionsEnabled(o, true)
        run.parts[i] = o
    end
    if run.round == 2 then
        local nx, ny = laneOrigin(0, 5)
        for _, o in ipairs(run.parts) do moveObject(o, 9000, nx, ny, z) end
    end
end

local function startRound(round)
    run.round, run.mine, run.rivals, run.started = round, 0, { 0, 0 }, getTickCount()
    Hud.counter("round", "ROUND", round, "number")
    spawnTarget(round == 2 and G.distance + 10 or G.distance)
end

local function finishRound(won)
    clearTarget()
    triggerServerEvent("vana-range:round", resourceRoot, run.round, won)
    if won and run.round < 3 then
        setTimer(function() if run then startRound(run.round + 1) end end, 3500, 1)
    else
        run.over = true
    end
end

addEvent("vana-range:run", true)
addEventHandler("vana-range:run", resourceRoot, function(range, weapon, dim)
    if run then clearTarget() Hud.counter("round", nil) Hud.counter("you", nil) Hud.counter("rival1", nil) Hud.counter("rival2", nil) end
    run = nil
    if not range then return end
    run = { range = range, weapon = weapon, dim = dim, parts = {}, hits = 0 }
    setTimer(function() if run then startRound(1) end end, 2500, 1)
end)

addEventHandler("onClientPlayerWeaponFire", localPlayer, function(_, _, _, _, _, _, hit)
    if not run or run.over or not hit then return end
    for i, p in ipairs(run.parts) do
        if p == hit and isElement(p) and i > 1 then -- the frame doesn't count
            destroyElement(p)
            run.hits = run.hits + 1
            if run.round == 3 then
                run.mine = run.mine + 1
                if run.hits >= #G.parts - 1 then spawnTarget(G.distance) end
            elseif run.hits >= G.destroyedAt then
                run.mine = run.mine + 1
                spawnTarget(run.round == 2 and G.distance + 10 or G.distance)
            end
            return
        end
    end
end)

-- Rivals' pace, the scoreboard, and the round's end.
setTimer(function()
    if not run or run.over or not run.round then return end
    local per = G.rivalSeconds[run.weapon] * (run.round == 2 and 0.9 or 1)
    for i = 1, 2 do
        if math.random() < 0.5 / per * (i == 1 and 1 or 0.85) then
            run.rivals[i] = run.rivals[i] + (run.round == 3 and 4 or 1)
        end
    end
    local goal = run.round == 3 and G.pointsToWin or G.targetsToWin
    Hud.counter("you", "CARL", run.mine, "number")
    Hud.counter("rival1", "BOOTH 1", run.rivals[1], "number")
    Hud.counter("rival2", "BOOTH 2", run.rivals[2], "number")
    if run.mine >= goal then finishRound(true)
    elseif run.rivals[1] >= goal or run.rivals[2] >= goal then finishRound(false) end
end, 500, 0)
