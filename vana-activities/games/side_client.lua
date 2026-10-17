-- Inside Track Betting, the arcade games and basketball, drawn here. Betting outcomes come from the
-- server; the arcade games and the basketball meter are played here and report a score.
local ui -- { kind, p, ... }

local function sx(v) return v * (select(2, guiGetScreenSize()) / 720) end

local function done(score)
    triggerServerEvent("vana-side:done", resourceRoot, score or 0)
end

addEvent("vana-side:open", true)
addEventHandler("vana-side:open", resourceRoot, function(kind, p)
    if not kind then
        ui = nil
        toggleAllControls(true, true, false)
        return
    end
    ui = { kind = kind, p = p or {} }
    toggleAllControls(false, true, false)
    if kind == "betting" then
        ui.horse, ui.stake = 1, p.stakes[1]
    elseif kind == "arcade" then
        ui.score, ui.lives, ui.x, ui.y, ui.vy, ui.things, ui.shots, ui.last = 0, 3, 0.5, 0.5, 0, {}, {}, getTickCount()
    elseif kind == "basketball" then
        ui.score, ui.ends, ui.meter, ui.dir = 0, getTickCount() + p.timeMs, 0, 1
    end
end)

addEvent("vana-side:race", true)
addEventHandler("vana-side:race", resourceRoot, function(winner, win)
    if ui and ui.kind == "betting" then ui.winner, ui.win, ui.raceStart = winner, win, getTickCount() end
end)

addEvent("vana-side:newrace", true)
addEventHandler("vana-side:newrace", resourceRoot, function(race)
    if ui and ui.kind == "betting" then ui.p.race, ui.winner, ui.win, ui.raceStart = race, nil, nil, nil end
end)

addEventHandler("onClientKey", root, function(key, pressed)
    if not ui then return end
    ui.keys = ui.keys or {}
    ui.keys[key] = pressed
    if not pressed then return end
    if key == "backspace" or key == "escape" then
        done(ui.score)
    elseif ui.kind == "betting" and not ui.raceStart then
        local p = ui.p
        if key == "arrow_u" then ui.horse = (ui.horse - 2) % #p.race + 1
        elseif key == "arrow_d" then ui.horse = ui.horse % #p.race + 1
        elseif key == "arrow_r" or key == "arrow_l" then
            local stepSize = p.stakes[math.min(#p.stakes, 1 + math.floor(math.log10(math.max(1, ui.stake))))]
            ui.stake = math.max(p.stakes[1], math.min(p.max, ui.stake + (key == "arrow_r" and stepSize or -stepSize)))
        elseif key == "enter" then triggerServerEvent("vana-side:bet", resourceRoot, ui.horse, ui.stake) end
    elseif ui.kind == "arcade" and key == "space" then
        if ui.p.game == "uranus" or ui.p.game == "monkey" then
            table.insert(ui.shots, { x = ui.x, y = 0.9 })
        elseif ui.p.game == "bumble" then
            ui.vy = -0.9
        end
    elseif ui.kind == "basketball" and key == "space" then
        -- The meter's sweet spot sits at its top.
        local made = ui.meter >= 1 - ui.p.sweet
        if made then ui.score = ui.score + 2 end
        ui.flash, ui.made = getTickCount(), made
        triggerServerEvent("vana-side:shot", resourceRoot, made)
    else
        return
    end
    cancelEvent()
end)

local function box(x, y, w, h) dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 210)) end

-- The arcade games, in a box in the middle of the screen (coordinates 0..1 inside it).
local function arcade(dt)
    local W, H = guiGetScreenSize()
    local s = sx(1)
    local bw, bh = sx(420), sx(420)
    local bx, by = (W - bw) / 2, (H - bh) / 2
    box(bx, by, bw, bh)
    local g = ui.p.game
    local k = ui.keys or {}
    local now = getTickCount()
    local function px(x) return bx + x * bw end
    local function py(y) return by + y * bh end
    if g == "uranus" or g == "monkey" or g == "duality" then
        local speed = dt / 1000 * 0.6
        if k.arrow_l then ui.x = math.max(0.05, ui.x - speed) end
        if k.arrow_r then ui.x = math.min(0.95, ui.x + speed) end
        if g == "duality" then
            if k.arrow_u then ui.y = math.max(0.05, ui.y - speed) end
            if k.arrow_d then ui.y = math.min(0.95, ui.y + speed) end
        else
            ui.y = 0.9
        end
        -- Enemies (and, in Duality, things to collect) come down the screen.
        if now - ui.last > math.max(250, 900 - ui.score * 4) then
            ui.last = now
            table.insert(ui.things, { x = math.random() * 0.9 + 0.05, y = 0, good = g == "duality" and math.random() < 0.5 })
        end
        for i = #ui.things, 1, -1 do
            local t = ui.things[i]
            t.y = t.y + dt / 1000 * (0.25 + ui.score / 600)
            local hitMe = math.abs(t.x - ui.x) < 0.05 and math.abs(t.y - ui.y) < 0.05
            if hitMe then
                if t.good then ui.score = ui.score + 10 else ui.lives = ui.lives - 1 end
                table.remove(ui.things, i)
            elseif t.y > 1 then
                table.remove(ui.things, i)
            else
                dxDrawRectangle(px(t.x) - 6 * s, py(t.y) - 6 * s, 12 * s, 12 * s, t.good and tocolor(80, 220, 80) or tocolor(220, 60, 60))
            end
        end
        for i = #ui.shots, 1, -1 do
            local shot = ui.shots[i]
            shot.y = shot.y - dt / 1000 * 1.2
            local gone = shot.y < 0
            for j = #ui.things, 1, -1 do
                local t = ui.things[j]
                if math.abs(t.x - shot.x) < 0.04 and math.abs(t.y - shot.y) < 0.04 then
                    table.remove(ui.things, j)
                    ui.score = ui.score + 10
                    gone = true
                    break
                end
            end
            if gone then table.remove(ui.shots, i) else dxDrawRectangle(px(shot.x) - 2 * s, py(shot.y) - 6 * s, 4 * s, 12 * s, tocolor(255, 255, 120)) end
        end
        dxDrawRectangle(px(ui.x) - 10 * s, py(ui.y) - 6 * s, 20 * s, 12 * s, tocolor(120, 180, 255))
    elseif g == "bumble" then
        -- Flap (space) through the gaps.
        ui.vy = ui.vy + dt / 1000 * 2.2
        ui.y = ui.y + ui.vy * dt / 1000
        if now - ui.last > 1600 then
            ui.last = now
            table.insert(ui.things, { x = 1, gap = math.random() * 0.5 + 0.2 })
        end
        for i = #ui.things, 1, -1 do
            local t = ui.things[i]
            t.x = t.x - dt / 1000 * 0.35
            if t.x < -0.1 then
                table.remove(ui.things, i)
                ui.score = ui.score + 10
            else
                dxDrawRectangle(px(t.x), py(0), 30 * s, py(t.gap - 0.12) - py(0), tocolor(60, 160, 60))
                dxDrawRectangle(px(t.x), py(t.gap + 0.12), 30 * s, py(1) - py(t.gap + 0.12), tocolor(60, 160, 60))
                if math.abs(t.x - 0.25) < 0.04 and math.abs(ui.y - t.gap) > 0.12 then
                    ui.lives, ui.y, ui.vy = ui.lives - 1, t.gap, 0
                    table.remove(ui.things, i)
                end
            end
        end
        if ui.y > 1 or ui.y < 0 then ui.lives, ui.y, ui.vy = ui.lives - 1, 0.5, 0 end
        dxDrawRectangle(px(0.25) - 8 * s, py(ui.y) - 8 * s, 16 * s, 16 * s, tocolor(250, 210, 40))
    end
    dxDrawText(ui.p.title, bx, by - sx(30), bx + bw, by, tocolor(172, 203, 241), sx(1.2), "bankgothic", "center", "bottom")
    dxDrawText(("SCORE %d   LIVES %d   BEST %d"):format(ui.score, math.max(0, ui.lives), ui.p.best), bx, by + bh, bx + bw, by + bh + sx(26),
        tocolor(255, 255, 255), sx(1.1), "default-bold", "center", "center")
    if ui.lives <= 0 and not ui.over then
        ui.over = true
        setTimer(function() done(ui and ui.score) end, 1500, 1)
    end
end

addEventHandler("onClientPreRender", root, function(dt)
    if not ui then return end
    if ui.kind == "arcade" and not ui.over then arcade(dt) return end
    if ui.kind == "basketball" then
        local now = getTickCount()
        ui.meter = ui.meter + ui.dir * dt / 700
        if ui.meter > 1 then ui.meter, ui.dir = 1, -1 elseif ui.meter < 0 then ui.meter, ui.dir = 0, 1 end
        local W, H = guiGetScreenSize()
        local x, y, w, h = W / 2 + sx(160), H / 2 - sx(120), sx(24), sx(240)
        box(x - sx(4), y - sx(4), w + sx(8), h + sx(8))
        dxDrawRectangle(x, y, w, h * ui.p.sweet, tocolor(80, 200, 80, 160))
        dxDrawRectangle(x, y + h * (1 - ui.meter) - sx(3), w, sx(6), tocolor(255, 255, 255))
        local left = math.max(0, ui.ends - now)
        dxDrawText(("POINTS %d   TIME %d   BEST %d"):format(ui.score, math.ceil(left / 1000), ui.p.best), 0, H * 0.82, W, H * 0.88,
            tocolor(255, 255, 255), sx(1.3), "default-bold", "center", "center")
        if ui.flash and now - ui.flash < 1000 then
            dxDrawText(ui.made and "SCORE!" or "MISS", 0, H * 0.3, W, H * 0.4, ui.made and tocolor(120, 255, 120) or tocolor(255, 120, 120), sx(2), "pricedown", "center", "center")
        end
        dxDrawText("Space: shoot (at the top of the meter)   Backspace: stop", 0, H * 0.88, W, H * 0.92, tocolor(200, 200, 200), sx(1), "default", "center", "center")
        if left <= 0 and not ui.over then
            ui.over = true
            done(ui.score)
        end
    elseif ui.kind == "betting" then
        local p = ui.p
        local x, y, w, row = sx(40), sx(110), sx(480), sx(24)
        box(x, y, w, row * (#p.race + 4))
        dxDrawText("Inside Track Betting", x + sx(12), y + sx(4), x + w, y + row, tocolor(172, 203, 241), sx(1.3), "bankgothic")
        local now = getTickCount()
        for i, h in ipairs(p.race) do
            local ry = y + row * (i + 0.4)
            local colour = i == ui.horse and tocolor(255, 255, 255) or tocolor(180, 180, 180)
            dxDrawText((i == ui.horse and "> " or "  ") .. h.name .. "  " .. h.odds .. "/1", x + sx(12), ry, x + w, ry + row, colour, sx(1.05), "default-bold", "left", "center")
            if ui.raceStart then
                -- The race: everyone runs, the winner gets there first.
                local t = math.min(1, (now - ui.raceStart) / 6000)
                local frac = i == ui.winner and t or t * (0.75 + ((i * 37) % 20) / 100)
                dxDrawRectangle(x + sx(260), ry + row * 0.3, sx(200) * frac, row * 0.4, i == ui.winner and tocolor(240, 200, 60) or tocolor(120, 120, 160))
            end
        end
        local by = y + row * (#p.race + 1.6)
        local status = ("Stake $%d   |   You $%d"):format(ui.stake, getPlayerMoney())
        if ui.raceStart and now - ui.raceStart > 6000 then
            status = ui.win > 0 and ("WINNER! $" .. ui.win) or ("NO WIN! " .. p.race[ui.winner].name .. " won.")
        end
        dxDrawText(status, x + sx(12), by, x + w, by + row, tocolor(230, 230, 230), sx(1.1), "default-bold", "left", "center")
        dxDrawText("Up/Down: horse   Left/Right: stake   Enter: bet   Backspace: leave", x + sx(12), by + row, x + w, by + row * 2, tocolor(180, 180, 180), sx(1), "default", "left", "center")
    end
end)
