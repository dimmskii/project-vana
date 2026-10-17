-- The workout minigame: tap the sprint key to fill the bar; a full bar is one rep (the server
-- decides what it's worth). Enter/exit (F) or Backspace gets off.
local session -- { name, taps, tapsPerRep, stat, fat, capped, lastTap }

local function leave()
    if session then triggerServerEvent("vana-gym:stop", resourceRoot) end
end

addEvent("vana-gym:start", true)
addEventHandler("vana-gym:start", resourceRoot, function(name, tapsPerRep, stat, fat)
    session = { name = name, taps = 0, tapsPerRep = tapsPerRep, stat = stat, fat = fat, lastTap = getTickCount() }
end)

addEvent("vana-gym:progress", true)
addEventHandler("vana-gym:progress", resourceRoot, function(stat, fat, capped)
    if session then session.stat, session.fat, session.capped = stat, fat, capped end
end)

addEvent("vana-gym:stop", true)
addEventHandler("vana-gym:stop", resourceRoot, function() session = nil end)

addEventHandler("onClientKey", root, function(key, pressed)
    if not session or not pressed then return end
    if key == "backspace" then leave() cancelEvent() return end
    for _, control in ipairs({ "sprint", "enter_exit" }) do
        for bound in pairs(getBoundKeys(control) or {}) do
            if bound == key then
                if control == "enter_exit" then
                    leave()
                else
                    session.taps, session.lastTap = session.taps + 1, getTickCount()
                    if session.taps >= session.tapsPerRep then
                        session.taps = 0
                        triggerServerEvent("vana-gym:rep", resourceRoot)
                    end
                end
                cancelEvent()
                return
            end
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
    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 180))
    dxDrawRectangle(x + 2, y + 2, (w - 4) * session.taps / session.tapsPerRep, h - 4, tocolor(110, 190, 110))
    local info = session.capped and "You've done enough for now." or ("Stat %.0f%%   Fat %.0f%%   |   Tap sprint to train, F to get off"):format(session.stat / 10, session.fat / 10)
    dxDrawText(info, x - 100 * s, y + h + 4 * s, x + w + 100 * s, y + h + 28 * s, tocolor(220, 220, 220), 1 * s, "default-bold", "center", "center")
end)
