-- A list menu in our style (client): a box of rows, headings the selection passes over, choices that
-- change in place. Keys, the pad and the mouse through menu_input (import it first): up/down move,
-- left/right or Enter (or a click) change a choice or run an entry, Backspace / Escape / right click
-- close. Scrolling as every menu does it (menu_input): the keys follow the selection, the mouse never
-- moves the view, the wheel over the box scrolls it.
--   local m = MenuList.new{ title = "Preferences", x = 40, y = 120, width = 420, rows = 14, items = { ... },
--                           onClose = function() end }
--   items:  { heading = "HUD" } / { heading = "Map", level = 2 }
--           { label = "Blip size", choices = { { "Small", 0.8 }, ... }, get = function() return v end,
--             set = function(v) end }                         a value picked from its choices
--           { label = "Reset", run = function() end }        an entry that does something
--   m:open(), m:close(), m:toggle(), m:isOpen()               (x, y, width in 720p units, scaled;
--                                                              centred = true: x is ignored, the box
--                                                              sits in the middle, clear of the chat)
MenuList = {}
MenuList.__index = MenuList

local TITLE, TEXT, DIM, VALUE, SELECT = tocolor(172, 203, 241), tocolor(255, 255, 255), tocolor(180, 180, 180),
    tocolor(172, 203, 241), tocolor(172, 203, 241, 60)

local function selectable(item) return item and not item.heading end

function MenuList.new(opts)
    local m = setmetatable({ title = opts.title, x = opts.x or 40, y = opts.y or 120, width = opts.width or 400, centred = opts.centred,
        visible = opts.rows or 14, items = opts.items or {}, onClose = opts.onClose, selected = 1, rows = {} }, MenuList)
    m.handlers = {
        render = function() m:render() end,
        key = function(key, pressed) m:key(key, pressed) end,
        move = function(_, _, x, y)
            local i = MenuInput.rowAt(m.rows, x, y)
            if i and selectable(m.items[i]) then m.selected = i end
        end,
        click = function(button, state, x, y) m:click(button, state, x, y) end,
    }
    return m
end

function MenuList:isOpen() return self.shown == true end

function MenuList:step(dir)
    local n = #self.items
    for _ = 1, n do
        self.selected = (self.selected - 1 + dir) % n + 1
        if selectable(self.items[self.selected]) then return end
    end
end

function MenuList:open()
    if self.shown then return end
    self.shown, self.first = true, nil
    if not selectable(self.items[self.selected]) then self:step(1) end
    MenuInput.cursor(true)
    toggleAllControls(false, true, false)
    addEventHandler("onClientRender", root, self.handlers.render)
    addEventHandler("onClientKey", root, self.handlers.key)
    addEventHandler("onClientCursorMove", root, self.handlers.move)
    addEventHandler("onClientClick", root, self.handlers.click)
end

function MenuList:close()
    if not self.shown then return end
    self.shown = false
    removeEventHandler("onClientRender", root, self.handlers.render)
    removeEventHandler("onClientKey", root, self.handlers.key)
    removeEventHandler("onClientCursorMove", root, self.handlers.move)
    removeEventHandler("onClientClick", root, self.handlers.click)
    MenuInput.cursor(false)
    toggleAllControls(true, true, false)
    if self.onClose then self.onClose() end
end

function MenuList:toggle() if self.shown then self:close() else self:open() end end

-- A choice's current index (the nearest value), or 1.
local function current(item)
    local v, best, bestDist = item.get(), 1, math.huge
    for i, c in ipairs(item.choices) do
        local d = type(v) == "number" and type(c[2]) == "number" and math.abs(c[2] - v) or (c[2] == v and 0 or math.huge)
        if d < bestDist then best, bestDist = i, d end
    end
    return best
end

-- Change the selected entry: a choice moves by `dir` (wrapping), an entry runs.
function MenuList:change(dir)
    local item = self.items[self.selected]
    if not selectable(item) then return end
    if item.choices then
        local i = (current(item) - 1 + dir) % #item.choices + 1
        item.set(item.choices[i][2])
    elseif item.run then
        item.run()
    end
end

function MenuList:key(key, pressed)
    if not pressed then return end
    if MenuInput.wheel(self, key, #self.items) then
        if not selectable(self.items[self.selected]) then self:step(1) end
        return cancelEvent()
    end
    local action = MenuInput.action(key)
    if action == "up" then self:step(-1)
    elseif action == "down" then self:step(1)
    elseif action == "left" then self:change(-1)
    elseif action == "right" or action == "accept" then self:change(1)
    elseif action == "back" then self:close()
    else return end
    self.first = nil
    cancelEvent()
end

function MenuList:click(button, state, x, y)
    if state ~= "up" then return end
    if button == "right" then return self:close() end
    local i = button == "left" and MenuInput.rowAt(self.rows, x, y)
    if i and selectable(self.items[i]) then
        self.selected = i
        -- A click on the left half of a choice's value goes back a step.
        local r = self.rows[i]
        self:change(self.items[i].choices and x < r[1] + (r[3] - r[1]) * 0.75 and x > r[1] + (r[3] - r[1]) * 0.5 and -1 or 1)
    end
end

function MenuList:render()
    local sw, sh = guiGetScreenSize()
    local s = sh / 720
    local x, y, w, row = self.x * s, self.y * s, self.width * s, 24 * s
    if self.centred then x = (sw - w) / 2 end
    local n = #self.items
    local visible = math.min(n, self.visible)
    local first = math.max(1, math.min(self.first or (self.selected - math.floor(visible / 2)), n - visible + 1))
    self.first = first
    self.rows = {}
    self.box = { x, y, x + w, y + row * (visible + 2.6) }
    dxDrawRectangle(x, y, w, row * (visible + 2.6), tocolor(0, 0, 0, 200))
    dxDrawText(self.title, x + 12 * s, y + 6 * s, x + w, y + row, TITLE, 1.4 * s, "bankgothic")
    for i = first, first + visible - 1 do
        local item = self.items[i]
        local ry = y + row * (i - first + 1.4)
        if item.heading then
            local indent = (item.level or 1) > 1 and 14 * s or 0
            dxDrawText(item.heading, x + 12 * s + indent, ry, x + w, ry + row, TITLE, (item.level or 1) > 1 and 1.05 * s or 1.15 * s,
                "default-bold", "left", "center")
        else
            self.rows[i] = { x, ry, x + w, ry + row }
            local selected = i == self.selected
            if selected then dxDrawRectangle(x + 4 * s, ry, w - 8 * s, row, SELECT) end
            dxDrawText(item.label, x + 40 * s, ry, x + w, ry + row, selected and TEXT or DIM, 1.1 * s, "default-bold", "left", "center")
            if item.choices then
                local c = item.choices[current(item)]
                local text = selected and ("<  " .. c[1] .. "  >") or c[1]
                dxDrawText(text, x, ry, x + w - 12 * s, ry + row, VALUE, 1.1 * s, "default-bold", "right", "center")
            end
        end
    end
    local hint = "Up/Down: choose   Left/Right, Enter or click: change   Backspace: close"
    dxDrawText(hint, x + 12 * s, y + row * (visible + 1.5), x + w, y + row * (visible + 2.5), tocolor(200, 200, 200), 1 * s, "default", "left", "center")
end
