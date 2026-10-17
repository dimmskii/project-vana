-- The shop menu, in the vanilla style: a box top-left, arrow keys to choose, Enter to buy,
-- Backspace to go back or leave. Clothes are grouped by apparel category; owned clothes say OWNED.
-- Purchases are only requests; the server decides.
local TITLES = { weapons = "Ammu-Nation", food = "Order", clothes = "Clothes", misc = "24/7", closet = "Closet", fighting = "Fighting style" }
local menu       -- { title, items, list, selected, category, categories, message, messageAt }

local function close()
    if not menu then return end
    menu = nil
    toggleAllControls(true, true, false)
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
end

addEvent("vana-shops:open", true)
addEventHandler("vana-shops:open", resourceRoot, function(shopName, kind, items, categories)
    local grouped = kind == "clothes" or kind == "closet"
    menu = { title = TITLES[kind] or shopName, items = items, selected = 1, categories = grouped and categories or nil }
    rebuild()
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

addEventHandler("onClientKey", root, function(key, pressed)
    if not menu or not pressed then return end
    local count = #menu.list
    if key == "arrow_u" and count > 0 then
        menu.selected = (menu.selected - 2) % count + 1
    elseif key == "arrow_d" and count > 0 then
        menu.selected = menu.selected % count + 1
    elseif key == "enter" or key == "num_enter" then
        local entry = menu.list[menu.selected]
        if entry and entry.key then
            triggerServerEvent("vana-shops:buy", resourceRoot, entry.key)
        elseif entry then
            menu.category, menu.selected, menu.message = entry.category, 1, nil
            rebuild()
        end
    elseif key == "backspace" or key == "escape" then
        if menu.category then
            menu.category, menu.selected = nil, 1
            rebuild()
        else
            close()
        end
    else
        return
    end
    cancelEvent()
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
    local first = math.max(1, math.min(menu.selected - 6, #menu.list - visible + 1))
    local title = menu.category and (menu.title .. ": " .. (categoryName(menu.category) or "")) or menu.title
    dxDrawRectangle(x, y, w, row * (visible + 2.6), tocolor(0, 0, 0, 190))
    dxDrawText(title, x + 12 * s, y + 6 * s, x + w, y + row, tocolor(172, 203, 241), 1.4 * s, "bankgothic")
    for i = first, first + visible - 1 do
        local entry = menu.list[i]
        local ry = y + row * (i - first + 1.4)
        local selected = i == menu.selected
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
