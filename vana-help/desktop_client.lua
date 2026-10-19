-- The help window, kept for the desktop to come (a "?" icon at the screen's side): the list of pages
-- by area (Up/Down, Enter opens), a page (Up/Down scroll, Enter follows its first "see" link,
-- Backspace back to the list), Escape closes. Nothing opens it yet: /help prints to chat (server.lua).
-- To open it, the server sends vana-help:window with the list, the page and the query.
local view -- { list, selected, page, scroll, query, history }

local function close()
    if not view then return end
    view = nil
    toggleAllControls(true, true, false)
end

addEvent("vana-help:window", true)
addEventHandler("vana-help:window", resourceRoot, function(list, page, query)
    view = { list = list, selected = 1, page = page, scroll = 0, query = query, history = {} }
    toggleAllControls(false, true, false)
end)

addEvent("vana-help:show", true)
addEventHandler("vana-help:show", resourceRoot, function(page)
    if not view then return end
    if view.page then table.insert(view.history, view.page) end
    view.page, view.scroll = page, 0
end)

-- A page as lines: the usage, its aliases, the text, see also.
local function pageLines(p)
    local lines = {}
    local function add(s, colour) lines[#lines + 1] = { s, colour } end
    if p.usage then add(p.usage, "usage") end
    if p.aliases and #p.aliases > 0 then add("Also: " .. table.concat(p.aliases, ", "), "dim") end
    if p.admin or p.console then add(p.console and "Server console only." or "Admin.", "dim") end
    add("")
    for line in ((p.text or p.summary or "") .. "\n"):gmatch("(.-)\n") do add(line) end
    if p.see and #p.see > 0 then
        add("")
        add("See also: " .. table.concat(p.see, ", ") .. "   (Enter: " .. p.see[1] .. ")", "dim")
    end
    return lines
end

addEventHandler("onClientKey", root, function(key, pressed)
    if not view or not pressed then return end
    if key == "escape" then
        close()
    elseif view.page then
        if key == "arrow_u" then view.scroll = math.max(0, view.scroll - 1)
        elseif key == "arrow_d" then view.scroll = view.scroll + 1
        elseif key == "enter" or key == "num_enter" then
            if view.page.see and view.page.see[1] then triggerServerEvent("vana-help:page", resourceRoot, view.page.see[1]) end
        elseif key == "backspace" then
            view.page, view.scroll = table.remove(view.history), 0
            if not view.page and #view.list == 0 then close() end
        else return end
    else
        local n = #view.list
        if key == "arrow_u" and n > 0 then view.selected = (view.selected - 2) % n + 1
        elseif key == "arrow_d" and n > 0 then view.selected = view.selected % n + 1
        elseif (key == "enter" or key == "num_enter") and view.list[view.selected] then view.page, view.scroll = view.list[view.selected], 0
        elseif key == "backspace" then close()
        else return end
    end
    cancelEvent()
end)

addEventHandler("onClientRender", root, function()
    if not view then return end
    local sw, sh = guiGetScreenSize()
    local s = sh / 720
    local x, y, w = 40 * s, 110 * s, math.min(sw - 80 * s, 760 * s)
    local row = 24 * s
    local rows = 18
    dxDrawRectangle(x, y, w, row * (rows + 2.6), tocolor(0, 0, 0, 200))
    local title = view.page and (view.page.topic and view.page.name or ("/" .. view.page.name)) or
        ("Manual" .. (view.query and (": " .. view.query) or ""))
    dxDrawText(title, x + 12 * s, y + 6 * s, x + w, y + row, tocolor(172, 203, 241), 1.3 * s, "bankgothic")
    local hint
    if view.page then
        local lines = pageLines(view.page)
        view.scroll = math.min(view.scroll, math.max(0, #lines - rows))
        for i = 1, rows do
            local l = lines[i + view.scroll]
            if not l then break end
            local ry = y + row * (i + 0.4)
            local colour = l[2] == "usage" and tocolor(240, 210, 90) or l[2] == "dim" and tocolor(160, 160, 160) or tocolor(230, 230, 230)
            dxDrawText(l[1], x + 12 * s, ry, x + w - 12 * s, ry + row, colour, 1.05 * s, "default-bold", "left", "center", true)
        end
        hint = "Up/Down: scroll   Enter: see also   Backspace: back   Esc: close"
    else
        local list = view.list
        local first = math.max(1, math.min(view.selected - math.floor(rows / 2), #list - rows + 1))
        local area
        for i = first, math.min(#list, first + rows - 1) do
            local p = list[i]
            local ry = y + row * (i - first + 1.4)
            if i == view.selected then dxDrawRectangle(x + 4 * s, ry, w - 8 * s, row, tocolor(172, 203, 241, 60)) end
            if p.area ~= area then
                area = p.area
                dxDrawText(area, x + w - 190 * s, ry, x + w - 12 * s, ry + row, tocolor(110, 140, 180), 0.95 * s, "default", "right", "center")
            end
            local name = p.topic and p.name or ("/" .. p.name)
            dxDrawText(name, x + 12 * s, ry, x + 180 * s, ry + row, i == view.selected and tocolor(255, 255, 255) or tocolor(200, 200, 200), 1.05 * s, "default-bold", "left", "center", true)
            dxDrawText(p.summary or "", x + 190 * s, ry, x + w - 200 * s, ry + row, tocolor(170, 170, 170), 1 * s, "default", "left", "center", true)
        end
        hint = ("%d pages   Up/Down: choose   Enter: open   Esc: close"):format(#list)
    end
    local by = y + row * (rows + 1.5)
    dxDrawText(hint, x + 12 * s, by, x + w, by + row, tocolor(200, 200, 200), 1 * s, "default", "left", "center")
end)

addEventHandler("onClientPlayerWasted", localPlayer, close)
