-- The shop menu, in the vanilla style (vana-lib's menu_list): a box top-left, arrow keys (or the pad,
-- or the mouse) to choose, Enter (or a click) to buy, Backspace (or a right click) to go back or leave.
-- Clothes are grouped by apparel category; owned clothes say OWNED. Purchases are only requests; the
-- server decides. The highlighted item is reported as you move through the menu: wearables are tried
-- on, and staff show it (vana-shops/keepers.lua).
local TITLES = { weapons = "Ammu-Nation", food = "Order", clothes = "Clothes", misc = "24/7", closet = "Closet", fighting = "Fighting style", hair = "Barber", tattoo = "Tattoos" }
local ARROW, OWNED, PRICE = tocolor(172, 203, 241), tocolor(172, 203, 241), tocolor(110, 190, 110)
local menu -- { title, items, categories, category, previewed }
local list

-- Tells the server what's highlighted (nil: nothing, e.g. back at the categories).
local function preview(row)
    if not menu then return end
    local key = row and row.entry and row.entry.key
    if key ~= menu.previewed then
        menu.previewed = key
        triggerServerEvent("vana-shops:preview", resourceRoot, key)
    end
end

local function categoryName(type)
    for _, c in ipairs(menu.categories or {}) do
        if c.type == type then return c.name end
    end
end

-- What the menu shows right now: categories, or the items (of the chosen category).
local rebuild
local function rows()
    local out = {}
    if menu.categories and not menu.category then
        for _, c in ipairs(menu.categories) do
            for _, item in ipairs(menu.items) do
                if item.category == c.type then
                    out[#out + 1] = { label = c.name, right = ">", rightColour = ARROW, category = c.type,
                        run = function() menu.category = c.type rebuild(1) end }
                    break
                end
            end
        end
    else
        for _, item in ipairs(menu.items) do
            if not menu.category or item.category == menu.category then
                local right, colour
                if item.takeOff then right = nil
                elseif item.owned then right, colour = "OWNED", OWNED
                else right, colour = "$" .. item.price, PRICE end
                out[#out + 1] = { label = item.label, entry = item, right = right, rightColour = colour,
                    run = function() triggerServerEvent("vana-shops:buy", resourceRoot, item.key) end }
            end
        end
    end
    return out
end

function rebuild(index)
    list:setTitle(menu.category and (menu.title .. ": " .. (categoryName(menu.category) or "")) or menu.title)
    list:setItems(rows(), index)
end

list = MenuList.new{ x = 40, y = 120, width = 360, rows = 12,
    onSelect = function(row) preview(row) end,
    -- Back from a category goes up to the categories, on the one you were in.
    onBack = function()
        if not menu or not menu.category then return false end
        local was = menu.category
        menu.category = nil
        local index = 1
        for i, row in ipairs(rows()) do if row.category == was then index = i end end
        rebuild(index)
        return true
    end,
    onClose = function()
        if not menu then return end
        menu = nil
        triggerServerEvent("vana-shops:close", resourceRoot)
    end,
    footer = function() return ("$%d"):format(getPlayerMoney()) end,
    hint = function()
        if not menu then return "" end
        return menu.category and "Enter: choose   Backspace: back" or (menu.categories and "Enter: open   Backspace: leave" or "Enter: buy   Backspace: leave")
    end,
}

addEvent("vana-shops:open", true)
addEventHandler("vana-shops:open", resourceRoot, function(shopName, kind, items, categories, title)
    local grouped = kind == "clothes" or kind == "closet" or kind == "tattoo"
    menu = { title = title or TITLES[kind] or shopName, items = items, categories = grouped and categories or nil }
    rebuild(1)
    list:open()
end)

addEvent("vana-shops:result", true)
addEventHandler("vana-shops:result", resourceRoot, function(ok, text, key, owns)
    if not menu then return end
    list:message(text, ok)
    if ok and owns then
        for _, item in ipairs(menu.items) do
            if item.key == key then item.owned = true end
        end
        local _, index = list:current()
        menu.previewed = key -- the same entry, now owned: no new preview
        rebuild(index)
    end
end)

local function close() list:close() end

addEventHandler("onClientPlayerWasted", localPlayer, close)

-- The shop is being robbed: the server already let us go.
addEvent("vana-shops:closeMenu", true)
addEventHandler("vana-shops:closeMenu", resourceRoot, close)

-- Shops with staff frame the service with vanilla's camera; nil hands it back.
addEvent("vana-shops:camera", true)
addEventHandler("vana-shops:camera", resourceRoot, function(cam)
    if cam then setCameraMatrix(unpack(cam)) else setCameraTarget(localPlayer) end
end)
