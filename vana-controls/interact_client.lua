-- /interact (F1 by default): the cursor comes up and a command box opens at the bottom, taking the
-- keyboard. Whatever is under the cursor (a vehicle, ped or player) glows; clicking it opens its menu:
-- the actions it takes now, from the server. An action that needs more (an amount) fills the box
-- with its command instead, so typing the rest and Enter runs it on that target. Typing anything
-- else offers matching commands (actions, and every documented command the player may use): Enter
-- takes the highlighted one, Tab completes it. Escape (or the key again) closes; so does running.
local open
local edit
local hover        -- element under the cursor
local menu         -- { target, x, y, items (nil while asked), selected, rows }
local suggest = { list = {}, selected = 1, rows = {} }
local documented = {} -- { name, usage, summary } from vana-help
local shader, arrow, shaded
local previousMode

local TARGETS = { vehicle = true, ped = true, player = true }
local GLOW = { 60, 255, 120 }

local function sx(v) return v * (select(2, guiGetScreenSize()) / 720) end

local function nameOf(e)
    local kind = getElementType(e)
    local n
    if kind == "vehicle" then
        n = getVehicleName(e) or "Vehicle"
        if getPedOccupiedVehicle(localPlayer) == e then n = n .. " (yours)" end
    elseif kind == "player" then
        n = getPlayerName(e):gsub("#%x%x%x%x%x%x", "")
    else
        n = getElementData(e, "vana:keeper") and "Shopkeeper" or "Pedestrian"
    end
    local tid = getElementData(e, "vana:tid")
    return tid and ("%s  #%d"):format(n, tid) or n
end

local function highlight(e)
    if e == shaded then return end
    if shaded and shader and isElement(shaded) then engineRemoveShaderFromWorldTexture(shader, "*", shaded) end
    shaded = isElement(e) and e or nil
    if shaded then
        if not shader then shader = dxCreateShader("highlight.fx", 0, 0, false, "vehicle,ped") end
        if shader then
            dxSetShaderValue(shader, "gColor", GLOW[1] / 255, GLOW[2] / 255, GLOW[3] / 255, 1)
            engineApplyShaderToWorldTexture(shader, "*", shaded)
        end
        if not arrow then arrow = createMarker(0, 0, 0, "arrow", 0.6, GLOW[1], GLOW[2], GLOW[3], 200) end
        setElementInterior(arrow, getElementInterior(localPlayer))
        setElementDimension(arrow, getElementDimension(localPlayer))
    elseif arrow then
        destroyElement(arrow)
        arrow = nil
    end
end

local function text() return edit and guiGetText(edit) or "" end
local function setText(t)
    guiSetText(edit, t)
    guiEditSetCaretIndex(edit, #t)
end

local function needsInputDoc(c) return (c.usage or ""):find("<") ~= nil end

local function rebuildSuggestions()
    local t = text()
    local first = (t:match("^%s*/?(%S*)") or ""):lower()
    local typedArgs = t:match("^%s*/?%S+%s") ~= nil
    local list, seen = {}, {}
    local function add(entry)
        if not seen[entry.name] and #list < 8 then seen[entry.name] = true; list[#list + 1] = entry end
    end
    if first ~= "" then
        if typedArgs then
            local def = Commands.get(first)
            if def then add({ name = def.name, label = def.label or def.summary, usage = def.usage }) end
            for _, c in ipairs(documented) do
                if c.name == first then add({ name = c.name, label = c.summary, usage = c.usage }) end
            end
        else
            for _, item in ipairs(menu and menu.items or {}) do
                if item.name:find(first, 1, true) == 1 then add({ name = item.name, label = item.label, needsInput = item.needsInput }) end
            end
            for _, def in ipairs(Commands.list()) do
                local hit = def.name:find(first, 1, true) == 1
                for _, a in ipairs(def.aliases or {}) do hit = hit or a:find(first, 1, true) == 1 end
                if hit then
                    local input = false
                    for _, p in ipairs(def.params or {}) do input = input or (p[3] and p[2] ~= "target") end
                    add({ name = def.name, label = def.label or def.summary, usage = def.usage, needsInput = input })
                end
            end
            for _, c in ipairs(documented) do
                if c.name:find(first, 1, true) == 1 then add({ name = c.name, label = c.summary, usage = c.usage, needsInput = needsInputDoc(c) }) end
            end
        end
    end
    suggest.list = list
    suggest.selected = math.max(1, math.min(suggest.selected, #list))
end

local function close()
    if not open then return end
    open, menu, hover = false, nil, nil
    highlight(nil)
    if edit then destroyElement(edit) edit = nil end
    guiSetInputMode(previousMode or "allow_binds")
    MenuInput.cursor(false)
    toggleAllControls(true, true, false)
end

local function openMode()
    if open or isPedDead(localPlayer) or isMainMenuActive() then return end
    open = true
    suggest = { list = {}, selected = 1, rows = {} }
    local sw, sh = guiGetScreenSize()
    edit = guiCreateEdit(sw / 2 - sx(260), sh - sx(90), sx(520), sx(30), "", false)
    guiSetAlpha(edit, 0)
    guiEditSetMaxLength(edit, 120)
    previousMode = guiGetInputMode()
    guiSetInputMode("no_binds_when_editing")
    MenuInput.cursor(true)
    toggleAllControls(false, true, false)
    guiBringToFront(edit)
    guiFocus(edit)
    addEventHandler("onClientGUIChanged", edit, rebuildSuggestions, false)
    addEventHandler("onClientGUIAccepted", edit, function() Interact.accept() end, false)
    triggerServerEvent("vana-help:commands", root)
end

local function openMenu(target, x, y)
    menu = { target = target, x = x, y = y, selected = 1, rows = {} }
    triggerServerEvent("vana-controls:menu", resourceRoot, target)
end

addEvent("vana-controls:menu", true)
addEventHandler("vana-controls:menu", resourceRoot, function(target, _, items)
    if menu and menu.target == target then
        menu.items = items
        menu.selected = 1
    end
end)

addEvent("vana-help:commands", true)
addEventHandler("vana-help:commands", root, function(list) documented = type(list) == "table" and list or {} end)

local function picked() return menu and isElement(menu.target) and menu.target or nil end

local function words(t)
    local out = {}
    for w in t:gmatch("%S+") do out[#out + 1] = w end
    return out
end

-- A menu entry or suggestion: run it, or put its command in the box when it needs more.
local function choose(entry)
    if entry.needsInput then
        setText(entry.name .. " ")
        rebuildSuggestions()
        return
    end
    if Commands.get(entry.name) then
        Commands.run(entry.name, {}, picked())
    else
        executeCommandHandler(entry.name)
        triggerServerEvent("vana-controls:command", resourceRoot, entry.name, nil)
    end
    close()
end

Interact = {}
function Interact.accept()
    if not open then return end
    local t = text():gsub("^%s*/", ""):gsub("%s+$", "")
    if t == "" then
        local item = menu and menu.items and menu.items[menu.selected]
        if item then choose(item) end
        return
    end
    local w = words(t)
    local name = table.remove(w, 1):lower()
    local known = Commands.get(name) ~= nil
    for _, c in ipairs(documented) do known = known or c.name == name end
    if #w == 0 and not known then
        local entry = suggest.list[suggest.selected]
        if not entry then return end
        return choose(entry)
    end
    if Commands.get(name) then
        Commands.run(name, w, picked())
    else
        executeCommandHandler(name, #w > 0 and table.concat(w, " ") or nil)
        triggerServerEvent("vana-controls:command", resourceRoot, name, #w > 0 and table.concat(w, " ") or nil)
    end
    close()
end

addCommandHandler("interact", function()
    if open then close() else openMode() end
end)

-- The list the arrow keys move in: the suggestions while typing a command, else the target's menu.
local function activeList()
    if text():match("%S") then return suggest.list, suggest end
    if menu and menu.items then return menu.items, menu end
end

addEventHandler("onClientKey", root, function(key, pressed)
    if not open or not pressed then return end
    local bound = getKeyBoundToCommand("interact")
    if key == "escape" or (bound and key == bound) then
        if menu and key == "escape" then menu = nil rebuildSuggestions() else close() end
        cancelEvent()
        return
    end
    if key == "tab" then
        local entry = suggest.list[suggest.selected]
        if entry then setText(entry.name .. " ") rebuildSuggestions() end
        cancelEvent()
        return
    end
    if key == "enter" or key == "num_enter" or key == "backspace" then return end -- the box has them
    local action = MenuInput.action(key)
    local list, holder = activeList()
    if (action == "up" or action == "down") and list and #list > 0 then
        holder.selected = action == "up" and (holder.selected - 2) % #list + 1 or holder.selected % #list + 1
        cancelEvent()
    elseif action == "accept" then
        Interact.accept()
        cancelEvent()
    elseif action == "back" then
        if menu then menu = nil else close() end
        cancelEvent()
    end
end)

addEventHandler("onClientCursorMove", root, function(_, _, ax, ay)
    if not open then return end
    local i = menu and MenuInput.rowAt(menu.rows, ax, ay)
    if i then menu.selected = i return end
    i = MenuInput.rowAt(suggest.rows, ax, ay)
    if i then suggest.selected = i end
end)

addEventHandler("onClientClick", root, function(button, state, ax, ay)
    if not open or state ~= "up" then return end
    if button == "left" then
        local i = menu and MenuInput.rowAt(menu.rows, ax, ay)
        if i and menu.items and menu.items[i] then
            choose(menu.items[i])
        else
            i = MenuInput.rowAt(suggest.rows, ax, ay)
            if i and suggest.list[i] then
                choose(suggest.list[i])
            elseif hover then
                openMenu(hover, ax, ay)
            else
                menu = nil
            end
        end
    elseif button == "right" then
        menu = nil
    end
    if edit then guiBringToFront(edit) guiFocus(edit) end
end)

addEventHandler("onClientPlayerWasted", localPlayer, close)
addEventHandler("onClientResourceStop", resourceRoot, close)

-- What the cursor points at, through the world (the player's own body doesn't count).
local function underCursor(ax, ay)
    local cx, cy, cz = getCameraMatrix()
    local wx, wy, wz = getWorldFromScreenPosition(ax, ay, 60)
    if not wx then return end
    local hit, _, _, _, element = processLineOfSight(cx, cy, cz, wx, wy, wz, true, true, true, true, false, false, false, false, localPlayer)
    if hit and isElement(element) and TARGETS[getElementType(element)] then return element end
end

local function row(rows, i, x, y, w, h, label, right, selected)
    rows[i] = { x, y, x + w, y + h }
    if selected then dxDrawRectangle(x + sx(4), y, w - sx(8), h, tocolor(172, 203, 241, 60)) end
    dxDrawText(label, x + sx(12), y, x + w - sx(12), y + h, selected and tocolor(255, 255, 255) or tocolor(190, 190, 190), sx(1.05), "default-bold", "left", "center", true)
    if right then dxDrawText(right, x, y, x + w - sx(12), y + h, tocolor(172, 203, 241), sx(0.95), "default", "right", "center", true) end
end

addEventHandler("onClientRender", root, function()
    if not open then return end
    local sw, sh = guiGetScreenSize()
    local cx, cy = getCursorPosition()
    local ax, ay = (cx or 0) * sw, (cy or 0) * sh
    local overUi = cx and (MenuInput.rowAt(menu and menu.rows, ax, ay) or MenuInput.rowAt(suggest.rows, ax, ay))
    hover = cx and not overUi and underCursor(ax, ay) or nil
    local glow = hover or picked()
    highlight(glow)
    if glow then
        if shader then dxSetShaderValue(shader, "gStrength", 0.35 + 0.15 * math.sin(getTickCount() / 150)) end
        local x, y, z = getElementPosition(glow)
        local _, _, _, _, _, maxZ = getElementBoundingBox(glow)
        if arrow then setElementPosition(arrow, x, y, z + (maxZ or 1) + 0.6) end
    end
    if hover and hover ~= picked() then
        dxDrawText(nameOf(hover), ax + sx(18), ay + sx(2), ax + sx(400), ay + sx(24), tocolor(GLOW[1], GLOW[2], GLOW[3]), sx(1.0), "default-bold", "left", "top")
    end

    -- The context menu, beside where it was opened.
    if menu then
        menu.rows = {}
        local w, h = sx(260), sx(24)
        local items = menu.items or {}
        local n = math.max(1, #items)
        local x = math.min(menu.x + sx(12), sw - w - sx(8))
        local y = math.min(menu.y, sh - h * (n + 1.4) - sx(120))
        dxDrawRectangle(x, y, w, h * (n + 1.4), tocolor(0, 0, 0, 200))
        dxDrawText(isElement(menu.target) and nameOf(menu.target) or "", x + sx(12), y + sx(2), x + w, y + h, tocolor(GLOW[1], GLOW[2], GLOW[3]), sx(1.05), "default-bold", "left", "center", true)
        if not menu.items then
            dxDrawText("...", x + sx(12), y + h * 1.2, x + w, y + h * 2.2, tocolor(190, 190, 190), sx(1.05), "default-bold", "left", "center")
        elseif #items == 0 then
            dxDrawText("Nothing to do here.", x + sx(12), y + h * 1.2, x + w, y + h * 2.2, tocolor(190, 190, 190), sx(1.05), "default-bold", "left", "center")
        end
        for i, item in ipairs(items) do
            row(menu.rows, i, x, y + h * (i + 0.2), w, h, item.label, item.needsInput and "..." or nil, i == menu.selected and not text():match("%S"))
        end
    end

    -- The command box and its suggestions, above it.
    local bx, by, bw, bh = sw / 2 - sx(260), sh - sx(90), sx(520), sx(30)
    suggest.rows = {}
    local h = sx(24)
    for i, entry in ipairs(suggest.list) do
        local ry = by - sx(6) - h * (#suggest.list - i + 1)
        if i == 1 then dxDrawRectangle(bx, ry, bw, h * #suggest.list, tocolor(0, 0, 0, 190)) end
        row(suggest.rows, i, bx, ry, bw, h, "/" .. entry.name .. (entry.usage and ("  " .. entry.usage) or ""), entry.label, i == suggest.selected)
    end
    dxDrawRectangle(bx, by, bw, bh, tocolor(0, 0, 0, 200))
    local t = text()
    if t == "" then
        local hint = menu and "Pick from the menu, or type a command" or "Click someone or something, or type a command"
        dxDrawText(hint, bx + sx(12), by, bx + bw, by + bh, tocolor(140, 140, 140), sx(1.05), "default-bold", "left", "center", true)
    else
        dxDrawText("/" .. t, bx + sx(12), by, bx + bw - sx(12), by + bh, tocolor(255, 255, 255), sx(1.05), "default-bold", "left", "center", true)
    end
    if getTickCount() % 1000 < 550 then
        local caret = edit and guiEditGetCaretIndex(edit) or #t
        local cx2 = bx + sx(12) + dxGetTextWidth((t == "" and "" or "/") .. t:sub(1, caret), sx(1.05), "default-bold")
        dxDrawRectangle(cx2, by + sx(6), sx(2), bh - sx(12), tocolor(255, 255, 255, 200))
    end
    local target = picked()
    if target then
        dxDrawText("on " .. nameOf(target), bx, by + bh + sx(4), bx + bw - sx(4), by + bh + sx(24), tocolor(GLOW[1], GLOW[2], GLOW[3]), sx(0.95), "default-bold", "right", "top", true)
    end
end)
