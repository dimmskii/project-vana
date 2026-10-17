-- The shop menu, in the vanilla style: a box top-left, arrow keys to choose, Enter to buy,
-- Backspace to leave. Purchases are only requests; the server decides.
local TITLES = { weapons = "Ammu-Nation", food = "Order", clothes = "Clothes", misc = "24/7" }
local menu       -- { title, items, selected, message, messageAt }

local function close()
    if not menu then return end
    menu = nil
    toggleAllControls(true, true, false)
    triggerServerEvent("vana-shops:close", resourceRoot)
end

addEvent("vana-shops:open", true)
addEventHandler("vana-shops:open", resourceRoot, function(shopName, kind, items)
    menu = { title = TITLES[kind] or shopName, items = items, selected = 1 }
    toggleAllControls(false, true, false)
end)

addEvent("vana-shops:result", true)
addEventHandler("vana-shops:result", resourceRoot, function(ok, text)
    if not menu then return end
    menu.message = ok and ("Bought: " .. text) or text
    menu.messageOk, menu.messageAt = ok, getTickCount()
end)

addEventHandler("onClientKey", root, function(key, pressed)
    if not menu or not pressed then return end
    if key == "arrow_u" then
        menu.selected = (menu.selected - 2) % #menu.items + 1
    elseif key == "arrow_d" then
        menu.selected = menu.selected % #menu.items + 1
    elseif key == "enter" or key == "num_enter" then
        local item = menu.items[menu.selected]
        if item then triggerServerEvent("vana-shops:buy", resourceRoot, item.key) end
    elseif key == "backspace" or key == "escape" then
        close()
    else
        return
    end
    cancelEvent()
end)

addEventHandler("onClientRender", root, function()
    if not menu then return end
    local sw, sh = guiGetScreenSize()
    local s = sh / 720
    local x, y, w = 40 * s, 120 * s, 360 * s
    local row = 26 * s
    local visible = math.min(#menu.items, 12)
    local first = math.max(1, math.min(menu.selected - 6, #menu.items - visible + 1))
    dxDrawRectangle(x, y, w, row * (visible + 2.6), tocolor(0, 0, 0, 190))
    dxDrawText(menu.title, x + 12 * s, y + 6 * s, x + w, y + row, tocolor(172, 203, 241), 1.4 * s, "bankgothic")
    for i = first, first + visible - 1 do
        local item = menu.items[i]
        local ry = y + row * (i - first + 1.4)
        local selected = i == menu.selected
        if selected then dxDrawRectangle(x + 4 * s, ry, w - 8 * s, row, tocolor(172, 203, 241, 60)) end
        local colour = selected and tocolor(255, 255, 255) or tocolor(180, 180, 180)
        dxDrawText(item.label, x + 12 * s, ry, x + w, ry + row, colour, 1.15 * s, "default-bold", "left", "center")
        dxDrawText("$" .. item.price, x, ry, x + w - 12 * s, ry + row, tocolor(110, 190, 110), 1.15 * s, "default-bold", "right", "center")
    end
    local by = y + row * (visible + 1.5)
    if menu.message and getTickCount() - menu.messageAt < 2500 then
        dxDrawText(menu.message, x + 12 * s, by, x + w, by + row, menu.messageOk and tocolor(120, 255, 120) or tocolor(255, 120, 120), 1 * s, "default-bold", "left", "center")
    else
        dxDrawText(("$%d   |   Enter: buy   Backspace: leave"):format(getPlayerMoney()), x + 12 * s, by, x + w, by + row, tocolor(200, 200, 200), 1 * s, "default", "left", "center")
    end
end)

addEventHandler("onClientPlayerWasted", localPlayer, close)
