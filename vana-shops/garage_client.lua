-- The mod garage menu, in the shop menu's style: categories (upgrade slots, then colours and
-- paintjobs), their items (greyed out where this vehicle can't take them), a colour grid. Arrow keys
-- (or the pad, or the mouse) choose, Enter (or a click) buys, Backspace (or a right click) goes back
-- or drives out. What's highlighted is tried on the car (the
-- server does it); the camera frames the part of the car the category is about.
local menu -- { data, level ("top", "items", "colours", "grid"), top, category, selected, slot, message, messageAt, previewed, rects }

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

-- The rows the menu shows at its current level.
local function rows()
    local d = menu.data
    if menu.level == "top" then
        local list = {}
        for i, c in ipairs(d.categories) do list[#list + 1] = { label = c.name, open = "items", category = i } end
        list[#list + 1] = { label = "Colors", open = "colours" }
        if d.paintjobs > 0 then list[#list + 1] = { label = "Paintjobs", open = "paintjobs" } end
        return list
    elseif menu.level == "items" then
        return d.categories[menu.category].items
    elseif menu.level == "colours" then
        return { { label = "Color 1", slot = 1 }, { label = "Color 2", slot = 2 } }
    elseif menu.level == "paintjobs" then
        local list = {}
        for n = 0, d.paintjobs - 1 do
            list[#list + 1] = { label = "Paintjob " .. (n + 1), paintjob = n, price = d.paintPrice, fits = true, owned = d.paintjob == n }
        end
        return list
    end
    return {}
end

-- The highlighted item, tried on the car (or nothing tried on).
local function preview()
    local kind, value
    if menu.level == "items" or menu.level == "paintjobs" then
        local r = rows()[menu.selected]
        if r and r.kind and r.fits and r.kind ~= "repair" then kind, value = r.kind, r.value
        elseif r and r.paintjob then kind, value = "paintjob", r.paintjob end
    elseif menu.level == "grid" then
        kind, value = "colour", { menu.slot, menu.selected - 1 }
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
        local r = rows()[menu.selected]
        return r and r.category and VIEW_OF[menu.data.categories[r.category].name] or "default"
    end
    return "default"
end

addEvent("vana-garage:open", true)
addEventHandler("vana-garage:open", resourceRoot, function(data, refresh)
    if refresh and menu then
        menu.data = data
        return
    end
    if not menu then MenuInput.cursor(true) end
    menu = { data = data, level = "top", selected = 1 }
    toggleAllControls(false, true, false)
end)

addEvent("vana-garage:close", true)
addEventHandler("vana-garage:close", resourceRoot, function()
    if not menu then return end
    menu = nil
    toggleAllControls(true, true, false)
    MenuInput.cursor(false)
    setCameraTarget(localPlayer)
end)

addEvent("vana-garage:result", true)
addEventHandler("vana-garage:result", resourceRoot, function(ok, text)
    if menu then
        menu.message, menu.messageOk, menu.messageAt = text, ok, getTickCount()
    else
        -- Outside the menu (driving in with a bike, a boat...): the game's subtitle, as vanilla says it.
        local res = getResourceFromName("vana-controls")
        if res and getResourceState(res) == "running" then exports["vana-controls"]:subtitle(text, 4000) else outputChatBox(text, 255, 200, 120) end
    end
end)

local function back()
    menu.first = nil
    if menu.level == "grid" then menu.level, menu.selected = "colours", menu.slot
    elseif menu.level == "items" then menu.level, menu.selected = "top", menu.category
    elseif menu.level == "colours" or menu.level == "paintjobs" then
        -- Back on its row: after the categories, Colors then Paintjobs.
        menu.selected = #menu.data.categories + (menu.level == "colours" and 1 or 2)
        menu.level = "top"
    else
        menu.leaving = true
        triggerServerEvent("vana-garage:leave", resourceRoot)
    end
end

local function accept()
    if menu.level == "grid" then
        return triggerServerEvent("vana-garage:buy", resourceRoot, "colour", { menu.slot, menu.selected - 1 })
    end
    local r = rows()[menu.selected]
    if not r then return end
    if r.open then
        menu.level, menu.category, menu.selected, menu.first = r.open, r.category, 1, nil
    elseif r.slot then
        -- The grid starts on the car's current colour if it's a palette one.
        menu.level, menu.slot, menu.selected = "grid", r.slot, 1
        local c = menu.data.colours
        for i, p in ipairs(menu.data.palette) do
            if p[1] == c[r.slot * 3 - 2] and p[2] == c[r.slot * 3 - 1] and p[3] == c[r.slot * 3] then menu.selected = i break end
        end
    elseif r.paintjob then
        triggerServerEvent("vana-garage:buy", resourceRoot, "paintjob", r.paintjob)
    elseif r.kind then
        if not r.fits then
            menu.message, menu.messageOk, menu.messageAt = r.reason or "This part doesn't fit this vehicle.", false, getTickCount()
        else
            triggerServerEvent("vana-garage:buy", resourceRoot, r.kind, r.value)
        end
    end
end

addEventHandler("onClientKey", root, function(key, pressed)
    if not menu or not pressed or menu.leaving then return end
    local action = MenuInput.action(key)
    if menu.level == "grid" then
        local n = #menu.data.palette
        if action == "left" then menu.selected = (menu.selected - 2) % n + 1
        elseif action == "right" then menu.selected = menu.selected % n + 1
        elseif action == "up" then menu.selected = (menu.selected - 1 - GRID_COLUMNS) % n + 1
        elseif action == "down" then menu.selected = (menu.selected - 1 + GRID_COLUMNS) % n + 1
        elseif action == "accept" then accept()
        elseif action == "back" then back()
        else return end
        preview()
        return cancelEvent()
    end
    local count = #rows()
    if MenuInput.wheel(menu, key, count) then
        preview()
        return cancelEvent()
    end
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
    menu.first = nil
    preview()
    cancelEvent()
end)

addEventHandler("onClientCursorMove", root, function(_, _, x, y)
    if not menu or menu.leaving then return end
    local i = MenuInput.rowAt(menu.rects, x, y)
    if i and i ~= menu.selected then
        menu.selected = i
        preview()
    end
end)

addEventHandler("onClientClick", root, function(button, state, x, y)
    if not menu or menu.leaving or state ~= "up" then return end
    if button == "left" then
        local i = MenuInput.rowAt(menu.rects, x, y)
        if not i then return end
        menu.selected = i
        accept()
    elseif button == "right" then
        back()
    end
    if menu then preview() end
end)

addEventHandler("onClientRender", root, function()
    if not menu then return end
    local _, sh = guiGetScreenSize()
    local s = sh / 720
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
    local x, y, w = 40 * s, 120 * s, 380 * s
    local row = 26 * s
    local title = menu.data.title
    if menu.level == "items" then title = title .. ": " .. menu.data.categories[menu.category].name
    elseif menu.level == "colours" or menu.level == "grid" then title = title .. ": Colors"
    elseif menu.level == "paintjobs" then title = title .. ": Paintjobs" end

    local hint
    menu.rects, menu.box = {}, nil
    if menu.level == "grid" then
        local pal = menu.data.palette
        local cell = 20 * s
        local rowsN = math.ceil(#pal / GRID_COLUMNS)
        local gw = cell * GRID_COLUMNS + 24 * s
        dxDrawRectangle(x, y, gw, row * 1.4 + cell * rowsN + row * 1.4, tocolor(0, 0, 0, 190))
        dxDrawText(title .. " " .. menu.slot, x + 12 * s, y + 6 * s, x + gw, y + row, tocolor(172, 203, 241), 1.4 * s, "bankgothic")
        for i, c in ipairs(pal) do
            local cx = x + 12 * s + ((i - 1) % GRID_COLUMNS) * cell
            local cy = y + row * 1.4 + math.floor((i - 1) / GRID_COLUMNS) * cell
            menu.rects[i] = { cx - 2 * s, cy - 2 * s, cx - 2 * s + cell, cy - 2 * s + cell }
            if i == menu.selected then dxDrawRectangle(cx - 2 * s, cy - 2 * s, cell, cell, tocolor(255, 255, 255)) end
            dxDrawRectangle(cx, cy, cell - 4 * s, cell - 4 * s, tocolor(c[1], c[2], c[3]))
        end
        y = y + row * 1.4 + cell * rowsN - row * 1.5
        w = gw
        hint = ("$%d   |   Arrows: choose   Enter: $%d   Backspace: back"):format(getPlayerMoney(), menu.data.paintPrice)
    else
        local list = rows()
        local visible = math.min(#list, 12)
        -- Where the keys left it (following the selection), or where the mouse wheel put it.
        local first = math.max(1, math.min(menu.first or (menu.selected - 6), #list - visible + 1))
        menu.first, menu.visible = first, visible
        menu.box = { x, y, x + w, y + row * (visible + 2.6) }
        dxDrawRectangle(x, y, w, row * (visible + 2.6), tocolor(0, 0, 0, 190))
        dxDrawText(title, x + 12 * s, y + 6 * s, x + w, y + row, tocolor(172, 203, 241), 1.4 * s, "bankgothic")
        for i = first, first + visible - 1 do
            local r = list[i]
            local ry = y + row * (i - first + 1.4)
            local selected = i == menu.selected
            menu.rects[i] = { x, ry, x + w, ry + row }
            if selected then dxDrawRectangle(x + 4 * s, ry, w - 8 * s, row, tocolor(172, 203, 241, 60)) end
            local greyed = r.fits == false
            local colour = greyed and tocolor(110, 110, 110) or selected and tocolor(255, 255, 255) or tocolor(180, 180, 180)
            dxDrawText(r.label, x + 12 * s, ry, x + w, ry + row, colour, 1.15 * s, "default-bold", "left", "center")
            local right, rightColour
            if r.open or r.slot then right, rightColour = ">", tocolor(172, 203, 241)
            elseif r.owned then right, rightColour = "OWNED", tocolor(172, 203, 241)
            elseif greyed then right, rightColour = "N/A", tocolor(110, 110, 110)
            elseif r.price then right, rightColour = "$" .. r.price, tocolor(110, 190, 110) end
            if right then dxDrawText(right, x, ry, x + w - 12 * s, ry + row, rightColour, 1.15 * s, "default-bold", "right", "center") end
        end
        y = y + row * (visible - 1)
        hint = ("$%d   |   %s"):format(getPlayerMoney(), menu.level == "top" and "Enter: open   Backspace: drive out" or "Enter: buy   Backspace: back")
    end
    local by = y + row * 2.5
    if menu.leaving then
        hint = "Driving out..."
    elseif menu.message and getTickCount() - menu.messageAt < 2500 then
        dxDrawText(menu.message, x + 12 * s, by, x + w, by + row, menu.messageOk and tocolor(120, 255, 120) or tocolor(255, 120, 120), 1 * s, "default-bold", "left", "center")
        return
    end
    dxDrawText(hint, x + 12 * s, by, x + w, by + row, tocolor(200, 200, 200), 1 * s, "default", "left", "center")
end)
