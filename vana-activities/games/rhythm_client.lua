-- The rhythm game shared by dancing (vanilla DANCE), the lowrider contest (vanilla LOWGAME) and dance
-- dates, drawn as vanilla's beat display (BDISPLY): LD_BEAT's arrows scroll along a track into the
-- target ring; press the matching direction as each reaches it. Judged and scored as those scripts do
-- (docs/activities.md): grades by how far off the press was, points by grade, doubled (dance) or x10
-- (lowrider) while the overall rating is PERFECT, the rating revised every 4 judged beats.
-- Rhythm.start(opts, onDone(share, points)); opts:
--   rules   "dance" (arrow keys) or "lowrider" (the hydraulics keys; two at once for diagonals)
--   beats   { { at, key }, ... } on `clock` (a vanilla routine's beats, keyed as LD_BEAT's sprites), or
--           count + beatMs to make up dance beats
--   clock   function -> now (ms); default getTickCount. endAt: when it's over (default 2 s after the last beat)
--   title, text (the game's text, from the server: score, player, opposition, ratings, feedback sets)
--   rival   lowrider: the opposition's points, one entry per beat, added as each beat goes by
--   onJudge function(grade, key, index): each beat judged ("perfect", "good", "ok", "late", "early",
--           "wrong", "timing")
Rhythm = {}
local run

local RULES = {
    -- DANCE: within 35 ms perfect, 60 good, 110 ok; a press further off "bad timing".
    dance = { windows = { 35, 60, 110 }, reach = 300, multiplier = 2 },
    -- LOWGAME: within 35 ms perfect, 50 good, 100 ok, 200 early / late.
    lowrider = { windows = { 35, 50, 100 }, reach = 200, early = true, multiplier = 10 },
}
local POINTS = { perfect = 50, good = 20, ok = 10 }
-- Each feedback set's lines in this order (DNC_005-011, DNC_012-018, DNC_019-025).
local FEEDBACK = { perfect = 1, good = 2, ok = 3, late = 4, early = 5, wrong = 6, timing = 7 }
local SPRITE = { [1] = "down", [2] = "left", [3] = "up", [4] = "right", [9] = "left", [10] = "right", [11] = "upr",
                 [12] = "downl", [13] = "up", [14] = "down", [15] = "upl", [16] = "downr" }
local DANCE_KEYS = { arrow_u = 3, arrow_d = 1, arrow_l = 2, arrow_r = 4 }
-- Lowrider: directions to keys, single and in pairs.
local LOW_KEYS = { up = 13, down = 14, left = 9, right = 10, ["up+right"] = 11, ["down+left"] = 12, ["up+left"] = 15, ["down+right"] = 16 }
local HYDRAULICS = { up = "special_control_up", down = "special_control_down", left = "special_control_left", right = "special_control_right" }
local ARROWS = { arrow_u = "up", arrow_d = "down", arrow_l = "left", arrow_r = "right" }
local PAIR_MS = 60 -- a second direction this soon after the first makes a diagonal

-- BDISPLY's layout, in vanilla's 640 x 448 HUD space: the track's left end and width, beats shown from
-- `future` ms ahead to `past` ms behind, the ring where they're hit at `past`'s share of the track.
local TRACK = { x = 265, y = 390, width = 355, arrow = 32, ring = 64, future = 4500, past = 800 }
-- The hit flash (CHIT) by grade: brightness and how long it holds before fading (vanilla BD_RenderHit 3, 2, 1).
local FLASH = { perfect = { 255, 25 }, good = { 190, 80 }, other = { 90, 100 } }
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
    local clock = opts.clock or getTickCount
    local beats = {}
    if opts.beats then
        for i, b in ipairs(opts.beats) do beats[i] = { at = b[1], key = b[2] } end
    else
        local start = clock() + 2000
        for i = 1, opts.count do beats[i] = { at = start + i * opts.beatMs, key = math.random(4) } end
    end
    local rules = RULES[opts.rules or "dance"]
    run = { beats = beats, opts = opts, onDone = onDone, clock = clock, rules = rules, next = 1, points = 0,
            rival = 0, rivalNext = 1, state = 0, counts = { perfect = 0, good = 0, bad = 0 }, set = 0, hits = 0,
            endAt = opts.endAt or ((beats[#beats] and beats[#beats].at or clock()) + 2000), pending = nil, text = opts.text or {} }
    toggleAllControls(false, true, false)
    if opts.rules == "lowrider" then
        -- The hydraulics keys stay live: the car bounces natively as you press them, seen by everyone.
        for _, control in pairs(HYDRAULICS) do toggleControl(control, true) end
        run.keys = {}
        for dir, control in pairs(HYDRAULICS) do
            for key in pairs(getBoundKeys(control) or {}) do run.keys[key] = dir end
        end
    end
end

function Rhythm.stop()
    if run then
        toggleAllControls(true, true, false)
        for _, control in pairs(HYDRAULICS) do setPedControlState(localPlayer, control, false) end
    end
    run = nil
end

function Rhythm.active() return run ~= nil end

-- Every 4 judged beats the overall rating is revised (DANCE_8952 / LOWGAME_9681): four perfects raise
-- it (to PERFECT from GOOD or PERFECT), more good than bad keeps or makes it GOOD, otherwise it drops a step.
local function rate()
    local c = run.counts
    if c.perfect + c.good + c.bad < 4 then return end
    if c.perfect == 4 then
        run.state = (run.state == 1 or run.state == 2) and 2 or 1
    elseif c.good > c.bad then
        run.state = 1
    else
        run.state = math.max(0, run.state - 1)
    end
    run.rated = true
    c.perfect, c.good, c.bad = 0, 0, 0
end

local function judge(grade, beat, index)
    rate()
    local points = POINTS[grade]
    if points then
        run.points = run.points + points * (run.state == 2 and run.rules.multiplier or 1)
        run.hits = run.hits + (grade == "perfect" and 1 or grade == "good" and 0.66 or 0.33)
    end
    local c = run.counts
    if grade == "perfect" then c.perfect = c.perfect + 1 elseif points then c.good = c.good + 1 else c.bad = c.bad + 1 end
    -- The feedback line, from the next of the three sets.
    run.set = run.set % 3 + 1
    local set = run.text.feedback and run.text.feedback[run.set]
    run.line, run.grade, run.lineAt = set and set[FEEDBACK[grade]] or grade:upper(), grade, getTickCount()
    if beat then run.flash = { beat = beat, grade = grade, at = run.clock() } end
    if run.opts.onJudge then run.opts.onJudge(grade, beat and beat.key, index) end
end

-- A press (a key, at a time): judged against the next unjudged beat, if it's within reach.
local function press(key, at)
    local b = run.beats[run.next]
    if not b then return end
    local off = at - b.at -- negative: early
    if math.abs(off) > run.rules.reach then return end
    local index = run.next
    run.next = run.next + 1
    if key ~= b.key then return judge("wrong", b, index) end
    local w = run.rules.windows
    local a = math.abs(off)
    if a <= w[1] then return judge("perfect", b, index) end
    if a <= w[2] then return judge("good", b, index) end
    if a <= w[3] then return judge("ok", b, index) end
    if run.rules.early then return judge(off < 0 and "early" or "late", b, index) end
    judge("timing", b, index)
end

addEventHandler("onClientKey", root, function(key, down)
    if not run or not down then return end
    if run.opts.rules ~= "lowrider" then
        local k = DANCE_KEYS[key]
        if not k then return end
        cancelEvent()
        return press(k, run.clock())
    end
    local dir = run.keys[key]
    if not dir and ARROWS[key] then
        -- Arrow keys work too, moving the hydraulics as their keys would.
        dir = ARROWS[key]
        cancelEvent()
        local control = HYDRAULICS[dir]
        setPedControlState(localPlayer, control, true)
        setTimer(function() if run then setPedControlState(localPlayer, control, false) end end, 250, 1)
    end
    if not dir then return end
    -- Wait a moment for a second direction (a diagonal), judged at the first press's time.
    local p = run.pending
    if p and not p[dir] and getTickCount() - p.started <= PAIR_MS then
        p[dir], p.count = true, p.count + 1
    else
        run.pending = { [dir] = true, count = 1, started = getTickCount(), at = run.clock() }
    end
end)

local function resolvePending()
    local p = run.pending
    if not p or (p.count < 2 and getTickCount() - p.started < PAIR_MS) then return end
    run.pending = nil
    local name = p.up and "up" or p.down and "down"
    local side = p.left and "left" or p.right and "right"
    local key = LOW_KEYS[name and side and (name .. "+" .. side) or name or side]
    if key then press(key, p.at) end
end

addEventHandler("onClientRender", root, function()
    if not run then return end
    local now = run.clock()
    if run.opts.rules == "lowrider" then resolvePending() end
    -- Beats that went by unanswered: too late.
    while run.beats[run.next] and now - run.beats[run.next].at > run.rules.reach do
        run.next = run.next + 1
        judge("late", nil, run.next - 1)
    end
    -- The opposition scores as each beat goes by.
    if run.opts.rival then
        while run.beats[run.rivalNext] and now >= run.beats[run.rivalNext].at do
            run.rival = run.rival + (run.opts.rival[run.rivalNext] or 0)
            run.rivalNext = run.rivalNext + 1
        end
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
    for i = math.max(1, run.next - 3), math.min(#run.beats, run.next + 24) do
        local b = run.beats[i]
        local ahead = b.at - now
        if ahead < TRACK.future and ahead > -TRACK.past and not (run.flash and run.flash.beat == b) then
            -- Fading in on the way to the ring, out after it (BDISPLY).
            local alpha = ahead >= 0 and 255 * (1 - ahead / TRACK.future) or 255 * (TRACK.past + ahead) / TRACK.past
            local x, y = at(ahead)
            sprite(SPRITE[b.key] or "up", x, y, TRACK.arrow, math.max(0, math.min(255, alpha)))
        end
    end
    -- The hit flash, at the beat that was hit, held then faded by grade.
    local f = run.flash
    if f then
        local fl = FLASH[f.grade] or FLASH.other
        local t = now - f.at
        local alpha = t <= fl[2] and fl[1] or fl[1] * (1 - (t - fl[2]) / FLASH_FADE_MS)
        if alpha <= 0 then
            run.flash = nil
        else
            local x, y = at(math.max(f.beat.at - now, -TRACK.past))
            sprite("chit", x, y, TRACK.ring, alpha)
        end
    end

    local text = run.text
    -- Before the first beat: how long until the routine starts.
    local first = run.beats[1]
    if first and now < first.at - TRACK.future then
        local secs = math.ceil((first.at - TRACK.future - now) / 1000)
        dxDrawText((text.wait or "Next song in %d s"):format(secs), 0, H * 0.4, W, H * 0.45, tocolor(255, 255, 255), sx(1.4), "default-bold", "center", "center")
    end
    -- The overall rating (top, light blue), the score, and the latest feedback line.
    if run.rated then
        local label = text.ratings and text.ratings[run.state + 1] or ({ "BAD", "GOOD", "PERFECT" })[run.state + 1]
        dxDrawText(label, 0, H * 0.06, W, H * 0.11, tocolor(140, 190, 255), sx(1.8), "pricedown", "center", "center")
    end
    local score
    if run.opts.rival then
        score = ("%s %d   %s %d"):format(text.player or "Player", run.points, text.opposition or "Opposition", run.rival)
    else
        score = ("%s %d"):format(text.score or "Score:", run.points)
    end
    dxDrawText((run.opts.title or "") .. "   " .. score, 0, H * 0.12, W, H * 0.17, tocolor(255, 255, 255), sx(1.4), "default-bold", "center", "center")
    if run.lineAt and getTickCount() - run.lineAt < 1000 then
        local g = run.grade
        local colour = g == "perfect" and tocolor(240, 210, 60) or (g == "good" or g == "ok") and tocolor(90, 140, 255) or tocolor(220, 60, 60)
        dxDrawText(run.line, 0, H * 0.72, W, H * 0.78, colour, sx(1.5), "default-bold", "center", "center")
    end
    if now >= run.endAt and run.next > #run.beats then
        local r = run
        Rhythm.stop()
        r.onDone(#r.beats > 0 and r.hits / #r.beats or 0, r.points)
    end
end)
