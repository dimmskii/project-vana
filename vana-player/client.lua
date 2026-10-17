-- "WASTED" / "BUSTED", in the vanilla style.
local text, shownAt

addEvent("vana-player:restartText", true)
addEventHandler("vana-player:restartText", resourceRoot, function(kind)
    text, shownAt = kind == "busted" and "busted" or "wasted", getTickCount()
end)

addEventHandler("onClientRender", root, function()
    if not text then return end
    local age = getTickCount() - shownAt
    if age > 5500 then text = nil return end
    local alpha = math.min(255, age / 4)
    local sw, sh = guiGetScreenSize()
    local scale = sh / 360
    dxDrawText(text, 3, 3, sw + 3, sh + 3, tocolor(0, 0, 0, alpha), scale, "pricedown", "center", "center")
    dxDrawText(text, 0, 0, sw, sh, tocolor(text == "wasted" and 180 or 200, text == "wasted" and 25 or 200, 29, alpha), scale, "pricedown", "center", "center")
end)
