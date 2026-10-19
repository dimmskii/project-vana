-- The shop menu, in the vanilla style: a box top-left, arrow keys (or the pad, or the mouse) to
-- choose, Enter (or a click) to buy, Backspace (or a right click) to go back or leave. Clothes are grouped by apparel category; owned clothes say OWNED.
-- Purchases are only requests; the server decides. The highlighted item is reported as you move through
-- the menu: wearables are tried on, and staff show it (vana-shops/keepers.lua).
local TITLES = { weapons = "Ammu-Nation", food = "Order", clothes = "Clothes", misc = "24/7", closet = "Closet", fighting = "Fighting style", hair = "Barber", tattoo = "Tattoos" }
local menu       -- { title, items, list, selected, category, categories, message, messageAt, previewed, rows }

-- Tells the server what's highlighted (nil: nothing, e.g. back at the categories).
local function preview()
    if not menu then return end
    local entry = menu.list[menu.selected]
    local key = entry and entry.key
    if key ~= menu.previewed then
        menu.previewed = key
        triggerServerEvent("vana-shops:preview", resourceRoot, key)
    end
end

local function close()
    if not menu then return end
    menu = nil
    toggleAllControls(true, true, false)
    MenuInput.cursor(false)
    triggerServerEvent("vana-shops:close", resourceRoot)
end

-- What the menu shows right now: categories, or the items (of the chosen category).
local function rebuild()
    menu.list = {}
    if menu.categories and not menu.category then
        for _, c in ipairs(menu.categories) do
            for _, item in ipairs(menu.items) do
                if item.category == c.type then
                    menu.list[#menu.list + 1] = { label = c.name, category = c.type }
                    break
                end
            end
        end
    else
        for _, item in ipairs(menu.items) do
            if not menu.category or item.category == menu.category then menu.list[#menu.list + 1] = item end
        end
    end
    menu.selected = math.max(1, math.min(menu.selected or 1, #menu.list))
    menu.first = nil
end

addEvent("vana-shops:open", true)
addEventHandler("vana-shops:open", resourceRoot, function(shopName, kind, items, categories)
    local wasOpen = menu ~= nil
    local grouped = kind == "clothes" or kind == "closet" or kind == "tattoo"
    menu = { title = TITLES[kind] or shopName, items = items, selected = 1, categories = grouped and categories or nil }
    rebuild()
    preview()
    if not wasOpen then MenuInput.cursor(true) end
    toggleAllControls(false, true, false)
end)

addEvent("vana-shops:result", true)
addEventHandler("vana-shops:result", resourceRoot, function(ok, text, key, owns)
    if not menu then return end
    menu.message, menu.messageOk, menu.messageAt = text, ok, getTickCount()
    if ok and owns then
        for _, item in ipairs(menu.items) do
            if item.key == key then item.owned = true end
        end
    end
end)

local function accept()
    local entry = menu.list[menu.selected]
    if entry and entry.key then
        triggerServerEvent("vana-shops:buy", resourceRoot, entry.key)
    elseif entry then
        menu.category, menu.selected, menu.message = entry.category, 1, nil
        rebuild()
    end
end

local function back()
    if menu.category then
        menu.category, menu.selected = nil, 1
        rebuild()
    else
        close()
    end
end

addEventHandler("onClientKey", root, function(key, pressed)
    if not menu or not pressed then return end
    local count = #menu.list
    if MenuInput.wheel(menu, key, count) then
        preview()
        return cancelEvent()
    end
    local action = MenuInput.action(key)
    if action == "up" and count > 0 then
        menu.selected = (menu.selected - 2) % count + 1
    elseif action == "down" and count > 0 then
        menu.selected = menu.selected % count + 1
    elseif action == "accept" then
        accept()
    elseif action == "back" then
        back()
    else
        return
    end
    if menu then menu.first = nil end
    preview()
    cancelEvent()
end)

addEventHandler("onClientCursorMove", root, function(_, _, x, y)
    local i = menu and MenuInput.rowAt(menu.rows, x, y)
    if i and i ~= menu.selected then
        menu.selected = i
        preview()
    end
end)

addEventHandler("onClientClick", root, function(button, state, x, y)
    if not menu or state ~= "up" then return end
    if button == "left" then
        local i = MenuInput.rowAt(menu.rows, x, y)
        if not i then return end
        menu.selected = i
        accept()
    elseif button == "right" then
        back()
    end
    preview()
end)

local function categoryName(type)
    for _, c in ipairs(menu.categories or {}) do
        if c.type == type then return c.name end
    end
end

addEventHandler("onClientRender", root, function()
    if not menu then return end
    local sw, sh = guiGetScreenSize()
    local s = sh / 720
    local x, y, w = 40 * s, 120 * s, 360 * s
    local row = 26 * s
    local visible = math.min(#menu.list, 12)
    -- Where the keys left it (following the selection), or where the mouse wheel put it.
    local first = math.max(1, math.min(menu.first or (menu.selected - 6), #menu.list - visible + 1))
    menu.first, menu.visible = first, visible
    local title = menu.category and (menu.title .. ": " .. (categoryName(menu.category) or "")) or menu.title
    menu.rows = {}
    menu.box = { x, y, x + w, y + row * (visible + 2.6) }
    dxDrawRectangle(x, y, w, row * (visible + 2.6), tocolor(0, 0, 0, 190))
    dxDrawText(title, x + 12 * s, y + 6 * s, x + w, y + row, tocolor(172, 203, 241), 1.4 * s, "bankgothic")
    for i = first, first + visible - 1 do
        local entry = menu.list[i]
        local ry = y + row * (i - first + 1.4)
        local selected = i == menu.selected
        menu.rows[i] = { x, ry, x + w, ry + row }
        if selected then dxDrawRectangle(x + 4 * s, ry, w - 8 * s, row, tocolor(172, 203, 241, 60)) end
        local colour = selected and tocolor(255, 255, 255) or tocolor(180, 180, 180)
        dxDrawText(entry.label, x + 12 * s, ry, x + w, ry + row, colour, 1.15 * s, "default-bold", "left", "center")
        local right, rightColour
        if not entry.key then
            right, rightColour = ">", tocolor(172, 203, 241)
        elseif entry.takeOff then
            right = nil
        elseif entry.owned then
            right, rightColour = "OWNED", tocolor(172, 203, 241)
        else
            right, rightColour = "$" .. entry.price, tocolor(110, 190, 110)
        end
        if right then dxDrawText(right, x, ry, x + w - 12 * s, ry + row, rightColour, 1.15 * s, "default-bold", "right", "center") end
    end
    local by = y + row * (visible + 1.5)
    if menu.message and getTickCount() - menu.messageAt < 2500 then
        dxDrawText(menu.message, x + 12 * s, by, x + w, by + row, menu.messageOk and tocolor(120, 255, 120) or tocolor(255, 120, 120), 1 * s, "default-bold", "left", "center")
    else
        local hint = menu.category and "Enter: choose   Backspace: back" or (menu.categories and "Enter: open   Backspace: leave" or "Enter: buy   Backspace: leave")
        dxDrawText(("$%d   |   %s"):format(getPlayerMoney(), hint), x + 12 * s, by, x + w, by + row, tocolor(200, 200, 200), 1 * s, "default", "left", "center")
    end
end)

addEventHandler("onClientPlayerWasted", localPlayer, close)

-- The shop is being robbed: the server already let us go.
addEvent("vana-shops:closeMenu", true)
addEventHandler("vana-shops:closeMenu", resourceRoot, close)

-- Shops with staff frame the service with vanilla's camera; nil hands it back.
addEvent("vana-shops:camera", true)
addEventHandler("vana-shops:camera", resourceRoot, function(cam)
    if cam then setCameraMatrix(unpack(cam)) else setCameraTarget(localPlayer) end
end)
