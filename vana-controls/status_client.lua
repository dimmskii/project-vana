-- The status line and the subtitle, drawn by the game itself (Neon's native text: GTA's own font),
-- so every message looks like vanilla's.
-- The status box, top middle (clear of the chat, top left), has three layers; the first one present
-- shows:
--   status  a short message ("Engine turned off"), also printed to the console
--   help    an activity's help text (vana-activities' Hud.help), for 10 s or until cleared
--   prompt  what /use does here ("Press F to order food"), while it can
-- The subtitle, bottom middle: objectives and spoken lines (vana-activities' Hud say), messages like
-- "You must have hydraulics for this." or "You cannot mod this vehicle.".
-- The status box is the game's text drawn where we put it (Neon's drawText on a rectangle), not
-- GTA's help box: that one is pinned top left, under the chat, and its slot can stay busy. If the
-- game refuses a text (too long, another resource holds its messages), a box of our own stands in.
Status = {}
local STATUS_MS = 4000

-- GTA's messages take ASCII and its own tokens only (~r~ ~g~ ~b~ ~w~ ~y~ ~p~ ~s~ ~h~ ~n~ ~z~), 160
-- bytes at most. Key tokens become the key's name, everything else is dropped.
local TOKENS = { r = true, g = true, b = true, w = true, y = true, p = true, s = true, h = true, n = true, z = true }
local MAX = 160

-- A key as the player knows it: "F", "NUM+", "LSHIFT".
local NUM = { add = "+", sub = "-", mul = "*", div = "/", dec = ".", enter = "ENTER" }
function Status.keyLabel(key)
    local num = key:match("^num_(%w+)$")
    if num then return "NUM" .. (NUM[num] or num:upper()) end
    return key:upper()
end

function Status.keyName(command, control)
    local key = command and getKeyBoundToCommand(command)
    if not key and control then key = next(getBoundKeys(control) or {}) end
    return key and Status.keyLabel(key) or "?"
end

local function clean(text)
    text = text:gsub("#%x%x%x%x%x%x", "")
    text = text:gsub("~k~~([%w_]+)~", function(name)
        if name == "VEHICLE_ENTER_EXIT" then return Status.keyName("use", "enter_exit") end
        return Status.keyName(nil, name:lower())
    end)
    text = text:gsub("~(%a)~", function(c) return TOKENS[c:lower()] and "~" .. c:lower() .. "~" or "" end)
    text = text:gsub("\n", "~n~"):gsub("[%[%]%^]", ""):gsub("[\128-\255]", "")
    return text
end

local function plain(text)
    return (text:gsub("~n~", "\n"):gsub("~%a~", ""))
end

-- One native message line: a registered text shown on a channel ("help" or "objective").
-- The game busy with a message of its own there: ours waits for it up to BUSY_WAIT_MS, then draws in
-- our own box meanwhile, trying the game's again each second.
local BUSY_WAIT_MS, BUSY_RETRY_MS = 1500, 1000

local function line(channel, name)
    local l = { channel = channel, name = name, shownUntil = 0 }
    function l.show(entry)
        local now = getTickCount()
        if entry ~= l.entry then l.busySince, l.warned = nil, false end
        l.nativeOk, l.fallback, l.waiting = false, nil, false
        l.entry = entry
        if not entry then
            clearNativeText(channel)
            return
        end
        local ms = math.max(1, math.min(600000, entry.untilTick - now))
        l.shownUntil = now + ms
        if #entry.text <= MAX then
            local why
            if not l.handle then l.handle, why = createNativeUI("text", { name = name, content = entry.text }) end
            local ok
            if l.handle then ok, why = updateNativeUI(l.handle, { content = entry.text }) end
            if ok then ok, why = showNativeText(l.handle, channel, ms) end
            if ok then
                l.nativeOk, l.busySince = true, nil
                return
            end
            if why == "native-channel-busy" then
                l.busySince = l.busySince or now
                l.retryAt = now + BUSY_RETRY_MS
                if now - l.busySince < BUSY_WAIT_MS then
                    l.waiting = true
                    return
                end
            end
            if not l.warned then
                l.warned = true
                outputDebugString(("[vana-controls] the game refused the %s text (%s), drawing it ourselves: %s"):format(channel, tostring(why), entry.text), 2)
            end
        end
        l.fallback = plain(entry.text)
    end
    -- The entry to show now: shown again when the game's own time for it ran out (10 minutes at most),
    -- or, while it waits for the game or stands in for it, to try the game's again.
    function l.want(entry)
        local now = getTickCount()
        local retry = entry and (l.waiting or (l.fallback and l.busySince and now >= (l.retryAt or 0)) or (l.nativeOk and now >= l.shownUntil))
        if entry ~= l.entry or retry then l.show(entry) end
        if l.fallback and l.entry and now >= l.entry.untilTick then l.show(nil) end
    end
    return l
end

-- The status box: in GTA's 640 x 448 script space, centred at the top. Its height follows the text's
-- lines, estimated from the font's average width at this scale (GTA doesn't tell scripts).
local BOX = { centre = 320, y = 10, width = 300, pad = 6, scaleX = 0.48, scaleY = 1.6, lineHeight = 14, charsPerLine = 52,
              background = 0x000000BE, colour = 0xFFFFFFFF }

local function lineCount(text)
    local n = 0
    for part in (plain(text) .. "\n"):gmatch("(.-)\n") do n = n + math.max(1, math.ceil(#part / BOX.charsPerLine)) end
    return n
end

local helpBox = { shownUntil = 0 }
function helpBox.show(entry)
    helpBox.entry, helpBox.nativeOk, helpBox.fallback = entry, false, nil
    local h = helpBox
    if not entry then
        if h.rect then updateNativeUI(h.rect, { visible = false }) updateNativeUI(h.draw, { visible = false }) end
        return
    end
    if #entry.text <= MAX then
        local height = BOX.pad * 2 + lineCount(entry.text) * BOX.lineHeight
        local why
        local function make(kind, options)
            local id, reason = createNativeUI(kind, options)
            if not id then why = reason end
            return id or nil
        end
        if not h.text then
            h.text = make("text", { name = "vana-status", content = entry.text })
            if h.text then
                h.rect = make("rectangle", { x = BOX.centre - BOX.width / 2, y = BOX.y, width = BOX.width, height = height,
                    background = BOX.background, visible = false })
                h.draw = make("drawText", { text = h.text, x = BOX.centre, y = BOX.y + BOX.pad, width = BOX.width - BOX.pad * 2,
                    scaleX = BOX.scaleX, scaleY = BOX.scaleY, font = 1, alignment = 0, color = BOX.colour, visible = false })
            end
        end
        local ok = h.text and h.rect and h.draw and updateNativeUI(h.text, { content = entry.text })
        if ok then
            updateNativeUI(h.rect, { height = height, visible = true })
            ok, why = updateNativeUI(h.draw, { visible = true })
        end
        if ok then
            h.nativeOk = true
            return
        end
        if not h.warned then
            h.warned = true
            outputDebugString(("[vana-controls] the game refused the status text (%s), drawing it ourselves: %s"):format(tostring(why), entry.text), 2)
        end
    end
    if h.rect then updateNativeUI(h.rect, { visible = false }) end
    if h.draw then updateNativeUI(h.draw, { visible = false }) end
    h.fallback = plain(entry.text)
end
function helpBox.want(entry)
    if entry ~= helpBox.entry then helpBox.show(entry) end
end

local subtitleLine = line("objective", "vana-subtitle")

local layers = {} -- name -> { text, untilTick }
local ORDER = { "status", "help", "prompt" }
local said        -- the subtitle entry

local function refresh()
    local now, top = getTickCount(), nil
    for _, name in ipairs(ORDER) do
        local l = layers[name]
        if l and now < l.untilTick then top = l break end
        layers[name] = nil
    end
    helpBox.want(top)
    if said and now >= said.untilTick then said = nil end
    subtitleLine.want(said)
end
setTimer(refresh, 100, 0)

local function entry(text, ms)
    return text and text ~= "" and { text = clean(text), untilTick = getTickCount() + ms } or nil
end

local function set(layer, text, ms)
    layers[layer] = entry(text, ms)
    refresh()
end

function Status.say(text)
    if not text then return end
    outputConsole(plain(clean(text)))
    set("status", text, STATUS_MS)
end
function Status.help(text, forever) set("help", text, forever and 3600000 or 10000) end
function Status.prompt(text) set("prompt", text, 3600000) end
function Status.subtitle(text, ms)
    said = entry(text, ms or 5000)
    refresh()
end

-- Exports for the other resources' client scripts.
function status(text) Status.say(text) end
function help(text, forever) Status.help(text, forever) end
function subtitle(text, ms) Status.subtitle(text, ms) end

addEvent("vana-controls:status", true)
addEventHandler("vana-controls:status", resourceRoot, Status.say)
addEvent("vana-controls:subtitle", true)
addEventHandler("vana-controls:subtitle", resourceRoot, Status.subtitle)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if subtitleLine.nativeOk then clearNativeText("objective") end
end)

local function shadowText(text, x1, y1, x2, y2, scale)
    dxDrawText(text, x1 + 2, y1 + 2, x2 + 2, y2 + 2, tocolor(0, 0, 0, 220), scale, "default-bold", "center", "center", false, true)
    dxDrawText(text, x1, y1, x2, y2, tocolor(255, 255, 255), scale, "default-bold", "center", "center", false, true)
end

addEventHandler("onClientRender", root, function()
    local w, sh = guiGetScreenSize()
    local s = sh / 720
    local text = helpBox.fallback
    if text then
        -- Where the game's box would be: the same script-space rectangle, scaled to the screen.
        local fx, fy = w / 640, sh / 448
        local bw = BOX.width * fx
        local x, y = BOX.centre * fx - bw / 2, BOX.y * fy
        local h = (BOX.pad * 2 + lineCount(text) * BOX.lineHeight) * fy
        dxDrawRectangle(x, y, bw, h, tocolor(0, 0, 0, 190))
        dxDrawText(text, x + BOX.pad * fx, y + BOX.pad * fy, x + bw - BOX.pad * fx, y + h, tocolor(255, 255, 255), 1.05 * s, "default-bold", "center", "top", false, true)
    end
    if subtitleLine.fallback then shadowText(subtitleLine.fallback, w * 0.15, sh * 0.80, w * 0.85, sh * 0.92, 1.15 * s) end
end)
