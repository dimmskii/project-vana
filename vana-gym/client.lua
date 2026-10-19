-- The workout minigame: tap the sprint key to fill the bar; a full bar is one rep (the server
-- decides what it's worth). /use (F) or Backspace gets off: while on a machine, getting off is a
-- silent offer to vana-controls' /use (the bar says it).
local session -- { name, statName, taps, tapsPerRep, stat, fat, reps, capped, lastTap }
local ID = "vana-gym:off"

local function leave()
    if session then triggerServerEvent("vana-gym:stop", resourceRoot) end
end

local function offer(on)
    local res = getResourceFromName("vana-controls")
    if not res or getResourceState(res) ~= "running" then return end
    if on then exports["vana-controls"]:offer(ID, "get off", true) else exports["vana-controls"]:withdraw(ID) end
end

addEvent("onClientVanaUse", false)
addEventHandler("onClientVanaUse", root, function(id) if id == ID then leave() end end)
addEvent("onClientVanaUseReset", false)
addEventHandler("onClientVanaUseReset", root, function() offer(session ~= nil) end)

addEvent("vana-gym:start", true)
addEventHandler("vana-gym:start", resourceRoot, function(name, statName, tapsPerRep, stat, fat)
    session = { name = name, statName = statName, taps = 0, tapsPerRep = tapsPerRep, stat = stat, fat = fat, reps = 0, lastTap = getTickCount() }
    offer(true)
end)

addEvent("vana-gym:progress", true)
addEventHandler("vana-gym:progress", resourceRoot, function(stat, fat, capped)
    if session then session.stat, session.fat, session.capped, session.reps = stat, fat, capped, session.reps + 1 end
end)

addEvent("vana-gym:stop", true)
addEventHandler("vana-gym:stop", resourceRoot, function()
    session = nil
    offer(false)
end)

addEventHandler("onClientKey", root, function(key, pressed)
    if not session or not pressed then return end
    if key == "backspace" then leave() cancelEvent() return end
    for bound in pairs(getBoundKeys("sprint") or {}) do
        if bound == key then
            session.taps, session.lastTap = session.taps + 1, getTickCount()
            if session.taps >= session.tapsPerRep then
                session.taps = 0
                triggerServerEvent("vana-gym:rep", resourceRoot)
            end
            cancelEvent()
            return
        end
    end
end)

addEventHandler("onClientRender", root, function()
    if not session then return end
    -- The bar drains when you stop tapping.
    if getTickCount() - session.lastTap > 400 and session.taps > 0 then
        session.taps, session.lastTap = session.taps - 1, getTickCount()
    end
    local sw, sh = guiGetScreenSize()
    local s = sh / 720
    local x, y, w, h = sw / 2 - 160 * s, sh - 140 * s, 320 * s, 16 * s
    dxDrawText(session.name, x, y - 52 * s, x + w, y - 26 * s, tocolor(172, 203, 241), 1.2 * s, "bankgothic", "center", "center")
    dxDrawText("power", x - 80 * s, y, x - 8 * s, y + h, tocolor(220, 220, 220), 1 * s, "default-bold", "right", "center")
    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 180))
    dxDrawRectangle(x + 2, y + 2, (w - 4) * session.taps / session.tapsPerRep, h - 4, tocolor(110, 190, 110))
    local info = session.capped and "You have reached your limit for now, come back later!"
        or ("reps %d   |   %s %.0f%%   Fat %.0f%%   |   Tap sprint to train, %s to get off"):format(session.reps, session.statName, session.stat / 10, session.fat / 10, (getKeyBoundToCommand("use") or "F"):upper())
    dxDrawText(info, x - 100 * s, y + h + 4 * s, x + w + 100 * s, y + h + 28 * s, tocolor(220, 220, 220), 1 * s, "default-bold", "center", "center")
end)
