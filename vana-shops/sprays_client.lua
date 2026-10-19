-- Pay 'n' Spray on this client: vanilla's frontend sounds (16 the respray, 14 no cash) and the
-- garage's line, shown low in the middle for a few seconds.
local line, shownAt

addEvent("vana-spray:tell", true)
addEventHandler("vana-spray:tell", resourceRoot, function(text, sound)
    if sound then playSoundFrontEnd(sound) end
    if text then line, shownAt = text, getTickCount() end
end)

addEventHandler("onClientRender", root, function()
    if not line or getTickCount() - shownAt > 4000 then return end
    local sw, sh = guiGetScreenSize()
    local s = sh / 720
    dxDrawText(line, 2, sh * 0.78 + 2, sw + 2, sh * 0.84 + 2, tocolor(0, 0, 0, 220), 1.3 * s, "default-bold", "center", "center")
    dxDrawText(line, 0, sh * 0.78, sw, sh * 0.84, tocolor(255, 255, 255), 1.3 * s, "default-bold", "center", "center")
end)
