-- Pool, the game: 8-ball against the CPU on a top-down table. 2D physics (rolling friction, cushions,
-- ball-on-ball collisions), vanilla's rules as its texts name them: an open table until a group is
-- potted, solids or stripes, scratches give ball in hand, the black last. Left/Right aim (Shift for fine),
-- Up/Down power, Space shoot, Backspace leave (forfeits the wager).
local W, H = 2.24, 1.12        -- table (metres)
local R = 0.028                -- ball radius
local POCKET = 0.065
local FRICTION = 0.9           -- speed lost per second, as a fraction of 1 m/s per second
local game                      -- see open()

local POCKETS = { { 0, 0 }, { W / 2, -0.01 }, { W, 0 }, { 0, H }, { W / 2, H + 0.01 }, { W, H } }

local function sx(v) return v * (select(2, guiGetScreenSize()) / 720) end

local function groupOf(n)
    if n == 0 then return "cue" end
    if n == 8 then return "black" end
    return n < 8 and "solids" or "stripes"
end

local function rack()
    local balls = { { n = 0, x = W * 0.25, y = H / 2, vx = 0, vy = 0 } }
    local order = { 1, 9, 2, 10, 8, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15 }
    local k = 1
    for row = 0, 4 do
        for i = 0, row do
            balls[#balls + 1] = { n = order[k], x = W * 0.72 + row * R * 1.75, y = H / 2 + (i - row / 2) * R * 2.02, vx = 0, vy = 0 }
            k = k + 1
        end
    end
    return balls
end

local function open(min, max)
    game = { min = min, max = max, wager = min, state = "wager", aim = 0, power = 0.5 }
    toggleAllControls(false, true, false)
end

addEvent("vana-pool:open", true)
addEventHandler("vana-pool:open", resourceRoot, function(min, max)
    if not min then
        game = nil
        toggleAllControls(true, true, false)
        return
    end
    open(min, max)
end)

addEvent("vana-pool:rack", true)
addEventHandler("vana-pool:rack", resourceRoot, function()
    if not game then return end
    game.balls, game.state, game.turn, game.groups = rack(), "aim", "player", {}
    game.message = "Open Table"
end)

local function ball(n)
    for _, b in ipairs(game.balls) do if b.n == n then return b end end
end

local function moving()
    for _, b in ipairs(game.balls) do
        if b.vx * b.vx + b.vy * b.vy > 1e-6 then return true end
    end
    return false
end

local function step(dt)
    local balls = game.balls
    for _, b in ipairs(balls) do
        b.x, b.y = b.x + b.vx * dt, b.y + b.vy * dt
        local speed = math.sqrt(b.vx * b.vx + b.vy * b.vy)
        if speed > 0 then
            local slow = math.max(0, speed - FRICTION * dt) / speed
            b.vx, b.vy = b.vx * slow, b.vy * slow
            if speed < 0.01 then b.vx, b.vy = 0, 0 end
        end
        -- Pockets first, then cushions.
        for _, p in ipairs(POCKETS) do
            if (b.x - p[1]) ^ 2 + (b.y - p[2]) ^ 2 < POCKET * POCKET then b.potted = true end
        end
        if not b.potted then
            if b.x < R then b.x, b.vx = R, -b.vx * 0.8 elseif b.x > W - R then b.x, b.vx = W - R, -b.vx * 0.8 end
            if b.y < R then b.y, b.vy = R, -b.vy * 0.8 elseif b.y > H - R then b.y, b.vy = H - R, -b.vy * 0.8 end
        end
    end
    for i = #balls, 1, -1 do
        if balls[i].potted then
            table.insert(game.potted, balls[i].n)
            table.remove(balls, i)
        end
    end
    for i = 1, #balls do
        for j = i + 1, #balls do
            local a, b = balls[i], balls[j]
            local dx, dy = b.x - a.x, b.y - a.y
            local d2 = dx * dx + dy * dy
            if d2 < 4 * R * R and d2 > 0 then
                local d = math.sqrt(d2)
                local nx, ny = dx / d, dy / d
                local rel = (a.vx - b.vx) * nx + (a.vy - b.vy) * ny
                if rel > 0 then
                    a.vx, a.vy = a.vx - rel * nx, a.vy - rel * ny
                    b.vx, b.vy = b.vx + rel * nx, b.vy + rel * ny
                    if not game.firstHit and (a.n == 0 or b.n == 0) then game.firstHit = a.n == 0 and b.n or a.n end
                end
                local push = (2 * R - d) / 2
                a.x, a.y, b.x, b.y = a.x - nx * push, a.y - ny * push, b.x + nx * push, b.y + ny * push
            end
        end
    end
end

local function shoot(angle, power)
    local cue = ball(0)
    if not cue then return end
    cue.vx, cue.vy = math.cos(angle) * power * 6, math.sin(angle) * power * 6
    game.state, game.potted, game.firstHit = "rolling", {}, nil
end

local function finish(won)
    game.state = "over"
    game.message = won and "You Win!" or "You Lost!"
    triggerServerEvent("vana-pool:result", resourceRoot, won)
end

local function left(group)
    local n = 0
    for _, b in ipairs(game.balls) do if groupOf(b.n) == group then n = n + 1 end end
    return n
end

-- After a shot settles: vanilla's 8-ball rules.
local function settle()
    local who, other = game.turn, game.turn == "player" and "cpu" or "player"
    local mine = game.groups[who]
    local scratch, black, own = false, false, 0
    for _, n in ipairs(game.potted) do
        local g = groupOf(n)
        if g == "cue" then scratch = true
        elseif g == "black" then black = true
        elseif not mine then
            mine = g
            game.groups[who], game.groups[other] = g, g == "solids" and "stripes" or "solids"
            own = own + 1
        elseif g == mine then own = own + 1 end
    end
    if black then
        local cleared = mine and left(mine) == 0
        return finish((who == "player") == (cleared and not scratch))
    end
    local foul = scratch or not game.firstHit
    if scratch then
        table.insert(game.balls, 1, { n = 0, x = W * 0.25, y = H / 2, vx = 0, vy = 0 })
        game.message = "Scratch - Ball in hand"
    elseif foul then
        game.message = "Foul!"
    elseif own > 0 then
        game.message = own > 1 and "Pocketed Balls!" or "Pocketed Ball!"
    else
        game.message = nil
    end
    if foul or own == 0 then game.turn = other end
    game.state = game.turn == "player" and "aim" or "cpu"
    game.cpuAt = getTickCount() + 1200
end

-- The CPU: the straightest pot it can find (ghost-ball aim), with a little error.
local function cpuShot()
    local cue = ball(0)
    local mine = game.groups.cpu
    local best, bestScore
    for _, b in ipairs(game.balls) do
        local g = groupOf(b.n)
        local legal = (mine == nil and g ~= "cue" and g ~= "black") or g == mine or (mine and left(mine) == 0 and g == "black")
        if legal then
            for _, p in ipairs(POCKETS) do
                local px, py = p[1] - b.x, p[2] - b.y
                local pd = math.sqrt(px * px + py * py)
                local gx, gy = b.x - px / pd * 2 * R, b.y - py / pd * 2 * R
                local ax, ay = gx - cue.x, gy - cue.y
                local ad = math.sqrt(ax * ax + ay * ay)
                local cut = (ax * px + ay * py) / (ad * pd)
                local score = cut - pd * 0.1 - ad * 0.05
                if not bestScore or score > bestScore then best, bestScore = { math.atan2(ay, ax), ad + pd }, score end
            end
        end
    end
    if not best then best = { math.random() * math.pi * 2, 1 } end
    shoot(best[1] + (math.random() - 0.5) * 0.06, math.min(1, 0.35 + best[2] * 0.35))
end

addEventHandler("onClientKey", root, function(key, pressed)
    if not game or not pressed then return end
    if key == "backspace" or key == "escape" then
        triggerServerEvent("vana-pool:leave", resourceRoot)
    elseif game.state == "wager" then
        if key == "arrow_r" then game.wager = math.min(game.max, game.wager + 50)
        elseif key == "arrow_l" then game.wager = math.max(game.min, game.wager - 50)
        elseif key == "enter" then triggerServerEvent("vana-pool:wager", resourceRoot, game.wager) end
    elseif game.state == "aim" then
        if key == "space" then shoot(game.aim, game.power) else return end
    else
        return
    end
    cancelEvent()
end)

addEventHandler("onClientPreRender", root, function(dt)
    if not game then return end
    local Ws, Hs = guiGetScreenSize()
    local scale = math.min(Ws * 0.7 / W, Hs * 0.6 / H)
    local ox, oy = (Ws - W * scale) / 2, (Hs - H * scale) / 2
    dxDrawRectangle(ox - sx(18), oy - sx(18), W * scale + sx(36), H * scale + sx(36), tocolor(90, 50, 20))
    dxDrawRectangle(ox, oy, W * scale, H * scale, tocolor(20, 110, 50))
    for _, p in ipairs(POCKETS) do dxDrawCircle(ox + p[1] * scale, oy + p[2] * scale, POCKET * scale, 0, 360, tocolor(10, 10, 10)) end
    if game.state == "wager" then
        dxDrawText(("Wager $%d   (Left/Right, Enter to play, Backspace to leave)"):format(game.wager), 0, oy + H * scale / 2 - sx(20), Ws, oy + H * scale / 2 + sx(20),
            tocolor(255, 255, 255), sx(1.3), "default-bold", "center", "center")
        return
    end
    if game.state == "rolling" then
        local steps = math.ceil(dt / 4)
        for _ = 1, steps do step(dt / 1000 / steps) end
        if not moving() then settle() end
    elseif game.state == "cpu" and getTickCount() > (game.cpuAt or 0) then
        cpuShot()
    elseif game.state == "aim" then
        local fine = getKeyState("lshift") and 0.25 or 1
        if getKeyState("arrow_l") then game.aim = game.aim - dt / 1000 * 1.2 * fine end
        if getKeyState("arrow_r") then game.aim = game.aim + dt / 1000 * 1.2 * fine end
        if getKeyState("arrow_u") then game.power = math.min(1, game.power + dt / 1000 * 0.6) end
        if getKeyState("arrow_d") then game.power = math.max(0.05, game.power - dt / 1000 * 0.6) end
        local cue = ball(0)
        if cue then
            local cx, cy = ox + cue.x * scale, oy + cue.y * scale
            dxDrawLine(cx, cy, cx + math.cos(game.aim) * sx(250), cy + math.sin(game.aim) * sx(250), tocolor(255, 255, 255, 120), 1)
            dxDrawLine(cx - math.cos(game.aim) * sx(20), cy - math.sin(game.aim) * sx(20), cx - math.cos(game.aim) * sx(20 + 120 * game.power),
                cy - math.sin(game.aim) * sx(20 + 120 * game.power), tocolor(200, 160, 90), 4)
        end
    end
    for _, b in ipairs(game.balls) do
        local g = groupOf(b.n)
        local colour = g == "cue" and tocolor(245, 245, 245) or g == "black" and tocolor(15, 15, 15) or g == "solids" and tocolor(220, 180, 30) or tocolor(200, 60, 60)
        dxDrawCircle(ox + b.x * scale, oy + b.y * scale, R * scale, 0, 360, colour)
        if g == "stripes" then dxDrawCircle(ox + b.x * scale, oy + b.y * scale, R * scale * 0.45, 0, 360, tocolor(245, 245, 245)) end
    end
    local mine = game.groups.player
    local status = (game.turn == "player" and "Your shot" or "CPU's shot") .. "   |   You: " .. (mine and (mine == "solids" and "Solids (yellow)" or "Stripes (red)") or "Open Table")
    dxDrawText(status, 0, oy + H * scale + sx(24), Ws, oy + H * scale + sx(50), tocolor(255, 255, 255), sx(1.2), "default-bold", "center", "center")
    if game.message then dxDrawText(game.message, 0, oy - sx(60), Ws, oy - sx(24), tocolor(225, 196, 130), sx(1.4), "default-bold", "center", "center") end
    if game.state == "aim" then
        dxDrawText("Left/Right: aim (Shift: fine)   Up/Down: power   Space: shoot", 0, oy + H * scale + sx(52), Ws, oy + H * scale + sx(76),
            tocolor(190, 190, 190), sx(1), "default", "center", "center")
    end
end)
