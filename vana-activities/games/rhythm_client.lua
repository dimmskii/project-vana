-- The rhythm game shared by dancing (vanilla DANCE), the lowrider contest (vanilla LOWR) and dance dates,
-- drawn as vanilla's beat display (BDISPLY): LD_BEAT's arrows scroll along a track into the target ring;
-- press the matching arrow as each reaches it. Judged as the DANCE script does: within 35 ms PERFECT,
-- 60 ms GOOD, 110 ms BAD (lines DNC_002..025), with BDISPLY's hit flash.
-- Rhythm.start(opts, onDone(share, points)); opts: beats, beatMs, title. The beats are still generated
-- here (vanilla's come from each track's beat data: not ported yet).
Rhythm = {}
local run
local DIRS = { { "arrow_u", "up" }, { "arrow_d", "down" }, { "arrow_l", "left" }, { "arrow_r", "right" } }
local WINDOW = { perfect = 35, good = 60, bad = 110 } -- ms either side of the beat (vanilla DANCE)
local LINES = { perfect = { "Great timing!", "The master!", "Synchronized!" }, good = { "Well done!", "Alright!", "Got it!" },
                bad = { "Bad timing!", "Too late!", "Too early!" }, miss = { "Missed it!", "Wrong!", "Try again!" } }

-- BDISPLY's layout, in vanilla's 640 x 448 HUD space: the track's left end and width, beats shown from
-- `future` ms ahead to `past` ms behind, the ring where they're hit at `past`'s share of the track.
local TRACK = { x = 265, y = 390, width = 355, arrow = 32, ring = 64, future = 4500, past = 800 }
-- The hit flash (CHIT) by grade: brightness and how long it holds before fading (vanilla BD_RenderHit 3, 2, 1).
local FLASH = { perfect = { 255, 25 }, good = { 190, 80 }, bad = { 90, 100 }, miss = { 90, 100 } }
local FLASH_FADE_MS = 270 -- vanilla fades per frame; this is its fade at the game's 30 fps

local sprites -- LD_BEAT's textures (data/LD_BEAT.txd, copied at setup), or false if they didn't load

local function textures()
    if sprites == nil then
        sprites = SATxd.load("data/LD_BEAT.txd") or false
        if not sprites or not sprites.cring then
            outputDebugString("[vana-activities] data/LD_BEAT.txd didn't load (see docs/setup.md): plain arrows", 2)
            sprites = false
        end
    end
    return sprites
end

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

local function judge(kind, beat)
    run.last, run.lastAt = kind, getTickCount()
    run.line = LINES[kind][math.random(#LINES[kind])]
    run.points = run.points + (kind == "perfect" and 3 or kind == "good" and 2 or kind == "bad" and 1 or 0)
    run.judged = run.judged + 1
    if beat then run.flash = { beat = beat, kind = kind, at = run.lastAt } end
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
    if dir ~= b.dir then return judge("miss", b) end
    judge(off <= WINDOW.perfect and "perfect" or off <= WINDOW.good and "good" or "bad", b)
end)

addEventHandler("onClientRender", root, function()
    if not run then return end
    local now = getTickCount()
    -- Beats that went by unanswered are misses.
    while run.beats[run.next] and now - run.beats[run.next].at > WINDOW.bad do
        run.next = run.next + 1
        judge("miss")
    end
    local W, H = guiGetScreenSize()
    local k = H / 448
    local span = TRACK.past + TRACK.future
    -- A point of the track at `ahead` ms from now (negative: gone by), centred on the screen.
    local function at(ahead)
        return W / 2 + (TRACK.x + TRACK.width * (ahead + TRACK.past) / span - 320) * k, TRACK.y * k
    end
    local tex = textures()
    local function sprite(name, x, y, size, alpha)
        local s = size * k
        if tex and tex[name] then
            dxDrawImage(x - s / 2, y - s / 2, s, s, tex[name], 0, 0, 0, tocolor(255, 255, 255, alpha))
        else
            dxDrawText(name:upper(), x - s, y - s / 2, x + s, y + s / 2, tocolor(250, 220, 90, alpha), k, "default-bold", "center", "center")
        end
    end

    local rx, ry = at(0)
    sprite("cring", rx, ry, TRACK.ring, 255)
    for i = math.max(1, run.next - 3), math.min(#run.beats, run.next + 16) do
        local b = run.beats[i]
        local ahead = b.at - now
        if ahead < TRACK.future and ahead > -TRACK.past and not (run.flash and run.flash.beat == b) then
            -- Fading in on the way to the ring, out after it (BDISPLY).
            local alpha = ahead >= 0 and 255 * (1 - ahead / TRACK.future) or 255 * (TRACK.past + ahead) / TRACK.past
            local x, y = at(ahead)
            sprite(DIRS[b.dir][2], x, y, TRACK.arrow, math.max(0, math.min(255, alpha)))
        end
    end
    -- The hit flash, at the beat that was hit, held then faded by grade.
    local f = run.flash
    if f then
        local bright, hold = FLASH[f.kind][1], FLASH[f.kind][2]
        local t = now - f.at
        local alpha = t <= hold and bright or bright * (1 - (t - hold) / FLASH_FADE_MS)
        if alpha <= 0 then
            run.flash = nil
        else
            local x, y = at(math.max(f.beat.at - now, -TRACK.past))
            sprite("chit", x, y, TRACK.ring, alpha)
        end
    end

    dxDrawText((run.opts.title or "") .. "   Score: " .. run.points, 0, H * 0.12, W, H * 0.17, tocolor(255, 255, 255), sx(1.4), "default-bold", "center", "center")
    if run.lastAt and now - run.lastAt < 700 then
        local colour = run.last == "perfect" and tocolor(240, 210, 60) or run.last == "good" and tocolor(90, 140, 255) or tocolor(220, 60, 60)
        dxDrawText(run.last:upper() .. "  " .. run.line, 0, H * 0.72, W, H * 0.78, colour, sx(1.5), "default-bold", "center", "center")
    end
    if run.next > #run.beats and now > run.beats[#run.beats].at + WINDOW.bad then
        local r = run
        Rhythm.stop()
        r.onDone(r.points / (3 * #r.beats), r.points)
    end
end)
