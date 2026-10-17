-- The rhythm game shared by dancing (vanilla DANCE), the lowrider contest (vanilla LOWR) and dance dates:
-- arrows scroll to a line; press the matching arrow as each crosses it. Judged PERFECT / GOOD / BAD with
-- vanilla's lines (DNC_002..025). Rhythm.start(opts, onDone(share, points)); opts: beats, beatMs, title.
Rhythm = {}
local run
local DIRS = { { "arrow_u", "UP" }, { "arrow_d", "DOWN" }, { "arrow_l", "LEFT" }, { "arrow_r", "RIGHT" } }
local WINDOW = { perfect = 90, good = 200, bad = 320 } -- ms either side of the beat
local LINES = { perfect = { "Great timing!", "The master!", "Synchronized!" }, good = { "Well done!", "Alright!", "Got it!" },
                bad = { "Bad timing!", "Too late!", "Too early!" }, miss = { "Missed it!", "Wrong!", "Try again!" } }

local function sx(v) return v * (select(2, guiGetScreenSize()) / 720) end

function Rhythm.start(opts, onDone)
    local beats = {}
    local start = getTickCount() + 2000
    for i = 1, opts.beats do beats[i] = { at = start + i * opts.beatMs, dir = math.random(4) } end
    run = { beats = beats, opts = opts, onDone = onDone, points = 0, judged = 0, next = 1 }
    toggleAllControls(false, true, false)
end

function Rhythm.stop()
    if run then toggleAllControls(true, true, false) end
    run = nil
end

function Rhythm.active() return run ~= nil end

local function judge(kind)
    run.last, run.lastAt = kind, getTickCount()
    run.line = LINES[kind][math.random(#LINES[kind])]
    run.points = run.points + (kind == "perfect" and 3 or kind == "good" and 2 or kind == "bad" and 1 or 0)
    run.judged = run.judged + 1
end

addEventHandler("onClientKey", root, function(key, pressed)
    if not run or not pressed then return end
    local dir
    for i, d in ipairs(DIRS) do if d[1] == key then dir = i end end
    if not dir then return end
    cancelEvent()
    local b = run.beats[run.next]
    if not b then return end
    local off = math.abs(getTickCount() - b.at)
    if off > WINDOW.bad then return end
    run.next = run.next + 1
    if dir ~= b.dir then return judge("miss") end
    judge(off <= WINDOW.perfect and "perfect" or off <= WINDOW.good and "good" or "bad")
end)

addEventHandler("onClientRender", root, function()
    if not run then return end
    local now = getTickCount()
    -- Beats that went by unanswered are misses.
    while run.beats[run.next] and now - run.beats[run.next].at > WINDOW.bad do
        run.next = run.next + 1
        judge("miss")
    end
    local W, Hs = guiGetScreenSize()
    local lineY = Hs * 0.75
    dxDrawRectangle(W / 2 - sx(160), lineY - sx(2), sx(320), sx(4), tocolor(255, 255, 255, 180))
    for i = run.next, math.min(#run.beats, run.next + 8) do
        local b = run.beats[i]
        local y = lineY - (b.at - now) / 4
        if y > Hs * 0.2 then
            local x = W / 2 + (b.dir - 2.5) * sx(70)
            dxDrawText(DIRS[b.dir][2], x - sx(40), y - sx(14), x + sx(40), y + sx(14), tocolor(250, 220, 90), sx(1.4), "default-bold", "center", "center")
        end
    end
    dxDrawText((run.opts.title or "") .. "   Score: " .. run.points, 0, Hs * 0.12, W, Hs * 0.17, tocolor(255, 255, 255), sx(1.4), "default-bold", "center", "center")
    if run.lastAt and now - run.lastAt < 700 then
        local colour = run.last == "perfect" and tocolor(240, 210, 60) or run.last == "good" and tocolor(90, 140, 255) or tocolor(220, 60, 60)
        dxDrawText(run.last:upper() .. "  " .. run.line, 0, Hs * 0.62, W, Hs * 0.68, colour, sx(1.5), "default-bold", "center", "center")
    end
    if run.next > #run.beats and now > run.beats[#run.beats].at + WINDOW.bad then
        local r = run
        Rhythm.stop()
        r.onDone(r.points / (3 * #r.beats), r.points)
    end
end)
