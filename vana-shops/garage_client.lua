-- The mod garage menu, in the shop menu's style (vana-lib's menu_list): categories (upgrade slots, then
-- colours and paintjobs), their items (greyed out where this vehicle can't take them), and a colour grid
-- of its own. Arrow keys (or the pad, or the mouse) choose, Enter (or a click) buys, Backspace (or a
-- right click) goes back or drives out. What's highlighted is tried on the car (the server does it);
-- the camera frames the part of the car the category is about.
local menu -- { data, level ("top", "items", "colours", "paintjobs", "grid"), category, slot, cell, previewed, rects, leaving }
local list

-- Camera per category: an offset from the car (its own axes: right, forward, up) to look from.
local VIEWS = {
    front = { 0, 6.2, 1.6 }, rear = { 0, -6.8, 1.7 }, side = { 5.6, 0.4, 1.1 }, top = { 3.2, -3.2, 4.2 }, default = { 4.6, 4.8, 1.9 },
}
local VIEW_OF = {
    Hood = "front", Vent = "front", ["Front Bullbars"] = "front", Headlights = "front", ["Front Bumper"] = "front",
    Spoiler = "rear", ["Rear Bullbars"] = "rear", Exhaust = "rear", ["Rear Bumper"] = "rear", Nitro = "rear",
    Sideskirt = "side", Wheels = "side", Hydraulics = "side", Roof = "top",
    Repair = "default", Engine = "front", Turbo = "front", Brakes = "side", Suspension = "side", Tyres = "side", Drivetrain = "side",
}
local GRID_COLUMNS = 16
local ARROW, OWNED, PRICE, GREY = tocolor(172, 203, 241), tocolor(172, 203, 241), tocolor(110, 190, 110), tocolor(110, 110, 110)

-- The rows the menu shows at its current level (the garage's own fields; entries() makes menu items).
local function rows()
    local d = menu.data
    if menu.level == "top" then
        local out = {}
        for i, c in ipairs(d.categories) do out[#out + 1] = { label = c.name, open = "items", category = i } end
        out[#out + 1] = { label = "Colors", open = "colours" }
        if d.paintjobs > 0 then out[#out + 1] = { label = "Paintjobs", open = "paintjobs" } end
        return out
    elseif menu.level == "items" then
        return d.categories[menu.category].items
    elseif menu.level == "colours" then
        return { { label = "Color 1", slot = 1 }, { label = "Color 2", slot = 2 } }
    elseif menu.level == "paintjobs" then
        local out = {}
        for n = 0, d.paintjobs - 1 do
            out[#out + 1] = { label = "Paintjob " .. (n + 1), paintjob = n, price = d.paintPrice, fits = true, owned = d.paintjob == n }
        end
        return out
    end
    return {}
end

-- The highlighted item, tried on the car (or nothing tried on).
local function preview()
    if not menu then return end
    local kind, value
    if menu.level == "grid" then
        kind, value = "colour", { menu.slot, menu.cell - 1 }
    elseif menu.level == "items" or menu.level == "paintjobs" then
        local item = list:current()
        local r = item and item.row
        if r and r.kind and r.fits and r.kind ~= "repair" then kind, value = r.kind, r.value
        elseif r and r.paintjob then kind, value = "paintjob", r.paintjob end
    end
    local id = kind and (kind .. ":" .. (type(value) == "table" and table.concat(value, ",") or value)) or "none"
    if id ~= menu.previewed then
        menu.previewed = id
        triggerServerEvent("vana-garage:preview", resourceRoot, kind, value)
    end
end

local function view()
    if menu.level == "items" then return VIEW_OF[menu.data.categories[menu.category].name] or "default" end
    if menu.level == "top" then
        local item = list:current()
        local r = item and item.row
        return r and r.category and VIEW_OF[menu.data.categories[r.category].name] or "default"
    end
    return "default"
end

local function titleOf()
    local title = menu.data.title
    if menu.level == "items" then title = title .. ": " .. menu.data.categories[menu.category].name
    elseif menu.level == "colours" or menu.level == "grid" then title = title .. ": Colors"
    elseif menu.level == "paintjobs" then title = title .. ": Paintjobs" end
    return title
end

local refresh
local function choose(r)
    if r.open then
        menu.level, menu.category = r.open, r.category
        refresh(1)
    elseif r.slot then
        -- The grid starts on the car's current colour if it's a palette one.
        menu.level, menu.slot, menu.cell = "grid", r.slot, 1
        local c = menu.data.colours
        for i, p in ipairs(menu.data.palette) do
            if p[1] == c[r.slot * 3 - 2] and p[2] == c[r.slot * 3 - 1] and p[3] == c[r.slot * 3] then menu.cell = i break end
        end
        list:suspend(true)
        preview()
    elseif r.paintjob then
        triggerServerEvent("vana-garage:buy", resourceRoot, "paintjob", r.paintjob)
    elseif r.kind then
        if not r.fits then
            list:message(r.reason or "This part doesn't fit this vehicle.", false)
        else
            triggerServerEvent("vana-garage:buy", resourceRoot, r.kind, r.value)
        end
    end
end

local function entries()
    local out = {}
    for _, r in ipairs(rows()) do
        local right, colour
        if r.open or r.slot then right, colour = ">", ARROW
        elseif r.owned then right, colour = "OWNED", OWNED
        elseif r.fits == false then right, colour = "N/A", GREY
        elseif r.price then right, colour = "$" .. r.price, PRICE end
        out[#out + 1] = { label = r.label, row = r, right = right, rightColour = colour, greyed = r.fits == false, run = function() choose(r) end }
    end
    return out
end

function refresh(index)
    list:setTitle(titleOf())
    list:setItems(entries(), index)
end

-- Back: up a level, on the row you came from; at the top, drive out.
local function back()
    if menu.level == "items" then
        local was = menu.category -- its row at the top: the categories come first, in order
        menu.level, menu.category = "top", nil
        refresh(was)
    elseif menu.level == "colours" or menu.level == "paintjobs" then
        -- Back on its row: after the categories, Colors then Paintjobs.
        local index = #menu.data.categories + (menu.level == "colours" and 1 or 2)
        menu.level = "top"
        refresh(index)
    else
        menu.leaving = true
        list.locked = true
        triggerServerEvent("vana-garage:leave", resourceRoot)
    end
    return true
end

list = MenuList.new{ x = 40, y = 120, width = 380, rows = 12,
    onSelect = function() preview() end,
    onBack = function() return menu and back() end,
    footer = function() return ("$%d"):format(getPlayerMoney()) end,
    hint = function()
        if not menu or menu.leaving then return "Driving out..." end
        return menu.level == "top" and "Enter: open   Backspace: drive out" or "Enter: buy   Backspace: back"
    end,
}

addEvent("vana-garage:open", true)
addEventHandler("vana-garage:open", resourceRoot, function(data, refreshOnly)
    if refreshOnly and menu then
        menu.data = data
        if menu.level ~= "grid" then
            local _, index = list:current()
            refresh(index)
        end
        return
    end
    menu = { data = data, level = "top" }
    refresh(1)
    list:open()
end)

addEvent("vana-garage:close", true)
addEventHandler("vana-garage:close", resourceRoot, function()
    if not menu then return end
    menu = nil
    list:close()
    setCameraTarget(localPlayer)
end)

addEvent("vana-garage:result", true)
addEventHandler("vana-garage:result", resourceRoot, function(ok, text)
    if menu then
        menu.message, menu.messageOk, menu.messageAt = text, ok, getTickCount()
        list:message(text, ok)
    else
        -- Outside the menu (driving in with a bike, a boat...): the game's subtitle, as vanilla says it.
        local res = getResourceFromName("vana-controls")
        if res and getResourceState(res) == "running" then exports["vana-controls"]:subtitle(text, 4000) else outputChatBox(text, 255, 200, 120) end
    end
end)

-- The colour grid: its own keys and clicks while the list is suspended.
local function leaveGrid()
    menu.level = "colours"
    list:suspend(false)
    refresh(menu.slot)
end

addEventHandler("onClientKey", root, function(key, pressed)
    if not menu or menu.level ~= "grid" or not pressed or menu.leaving then return end
    local n = #menu.data.palette
    local action = MenuInput.action(key)
    if action == "left" then menu.cell = (menu.cell - 2) % n + 1
    elseif action == "right" then menu.cell = menu.cell % n + 1
    elseif action == "up" then menu.cell = (menu.cell - 1 - GRID_COLUMNS) % n + 1
    elseif action == "down" then menu.cell = (menu.cell - 1 + GRID_COLUMNS) % n + 1
    elseif action == "accept" then triggerServerEvent("vana-garage:buy", resourceRoot, "colour", { menu.slot, menu.cell - 1 })
    elseif action == "back" then
        leaveGrid()
        return cancelEvent()
    else return end
    preview()
    cancelEvent()
end)

addEventHandler("onClientCursorMove", root, function(_, _, x, y)
    if not menu or menu.level ~= "grid" then return end
    local i = MenuInput.rowAt(menu.rects, x, y)
    if i and i ~= menu.cell then
        menu.cell = i
        preview()
    end
end)

addEventHandler("onClientClick", root, function(button, state, x, y)
    if not menu or menu.level ~= "grid" or state ~= "up" then return end
    if button == "right" then return leaveGrid() end
    local i = button == "left" and MenuInput.rowAt(menu.rects, x, y)
    if i then
        menu.cell = i
        preview()
        triggerServerEvent("vana-garage:buy", resourceRoot, "colour", { menu.slot, menu.cell - 1 })
    end
end)

addEventHandler("onClientRender", root, function()
    if not menu then return end
    -- The camera on the part of the car this is about.
    local v = getPedOccupiedVehicle(localPlayer)
    if v then
        local o = VIEWS[view()]
        local m = getElementMatrix(v)
        local cx = m[4][1] + m[1][1] * o[1] + m[2][1] * o[2] + m[3][1] * o[3]
        local cy = m[4][2] + m[1][2] * o[1] + m[2][2] * o[2] + m[3][2] * o[3]
        local cz = m[4][3] + m[1][3] * o[1] + m[2][3] * o[2] + m[3][3] * o[3]
        setCameraMatrix(cx, cy, cz, m[4][1], m[4][2], m[4][3] + 0.3)
    end
    if menu.level ~= "grid" then return end
    local _, sh = guiGetScreenSize()
    local s = sh / 720
    local x, y = 40 * s, 120 * s
    local row = 26 * s
    local pal = menu.data.palette
    local cell = 20 * s
    local rowsN = math.ceil(#pal / GRID_COLUMNS)
    local gw = cell * GRID_COLUMNS + 24 * s
    menu.rects = {}
    dxDrawRectangle(x, y, gw, row * 1.4 + cell * rowsN + row * 1.4, tocolor(0, 0, 0, 190))
    dxDrawText(titleOf() .. " " .. menu.slot, x + 12 * s, y + 6 * s, x + gw, y + row, tocolor(172, 203, 241), 1.4 * s, "bankgothic")
    for i, c in ipairs(pal) do
        local cx = x + 12 * s + ((i - 1) % GRID_COLUMNS) * cell
        local cy = y + row * 1.4 + math.floor((i - 1) / GRID_COLUMNS) * cell
        menu.rects[i] = { cx - 2 * s, cy - 2 * s, cx - 2 * s + cell, cy - 2 * s + cell }
        if i == menu.cell then dxDrawRectangle(cx - 2 * s, cy - 2 * s, cell, cell, tocolor(255, 255, 255)) end
        dxDrawRectangle(cx, cy, cell - 4 * s, cell - 4 * s, tocolor(c[1], c[2], c[3]))
    end
    local by = y + row * 1.4 + cell * rowsN + row * 0.1
    if menu.message and getTickCount() - menu.messageAt < 2500 then
        dxDrawText(menu.message, x + 12 * s, by, x + gw, by + row, menu.messageOk and tocolor(120, 255, 120) or tocolor(255, 120, 120), 1 * s, "default-bold", "left", "center")
    else
        dxDrawText(("$%d   |   Arrows: choose   Enter: $%d   Backspace: back"):format(getPlayerMoney(), menu.data.paintPrice),
            x + 12 * s, by, x + gw, by + row, tocolor(200, 200, 200), 1 * s, "default", "left", "center")
    end
end)
