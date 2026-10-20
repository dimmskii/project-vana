-- A list menu in our style (client): a box of rows, headings the selection passes over, entries that
-- run, choices that change in place. Every list menu of ours is one (shops, garages, activities,
-- schools, preferences). Keys, the pad and the mouse through menu_input (import it first): up/down
-- move, Enter / a click / the pad's accept run an entry, left/right (or Enter, or a click) change a
-- choice, Backspace / Escape / right click go back. Scrolling as every menu does it: the keys follow
-- the selection, the mouse never moves the view, the wheel over the box scrolls it. While open, the
-- cursor shows and the game's controls are off.
--   local m = MenuList.new{ title = "Shop", x = 40, y = 120, width = 360, rows = 12, items = { ... },
--       labelIndent = 12,                  where labels start (40 suits lists with headings)
--       colorCoded = false,                labels with MTA colour codes (#RRGGBB)
--       hint = "Enter: buy" or function(m) -> text   the line under the rows (a default otherwise)
--       footer = function(m) -> text       drawn before the hint on the same line (money, say)
--       onSelect = function(item, index)   the highlighted entry changed (trying things on)
--       onBack = function(m) -> true       Back pressed: true keeps the menu open (it went up a level)
--       onClose = function() }             closed, however
--   items:  { heading = "HUD" } / { heading = "Map", level = 2 }
--           { label = "Blip size", choices = { { "Small", 0.8 }, ... }, get = function() return v end,
--             set = function(v) end }                          a value picked from its choices
--           { label = "Buy", run = function(item) end,         an entry that does something;
--             right = "$100" or function(item, selected),      right-hand text (rightColour),
--             rights = { { text, colour }, ... },              or several, rightmost first;
--             greyed = true, disabled = true }                 greyed: dim but selectable;
--                                                              disabled: dim and passed over
--   m:open(), m:close(), m:toggle(), m:isOpen(), m:setItems(items [, index]), m:setTitle(title),
--   m:current() -> item, index, m:select(index), m:message(text, ok),
--   m.locked = true (input ignored: waiting on the server), m:suspend(on) (still open, cursor and
--   controls as they are, but neither drawn nor taking input: a custom view on top, the garage's colour
--   grid)                                                    (x, y, width in 720p units,
--   scaled; centred = true: x is ignored, the box sits in the middle, clear of the chat)
MenuList = {}
MenuList.__index = MenuList

local TITLE, TEXT, DIM, GREY, VALUE, SELECT = tocolor(172, 203, 241), tocolor(255, 255, 255), tocolor(180, 180, 180),
    tocolor(100, 100, 100), tocolor(172, 203, 241), tocolor(172, 203, 241, 60)
local MESSAGE_MS = 2500

local function selectable(item) return item ~= nil and not item.heading and not item.disabled end

function MenuList.new(opts)
    local m = setmetatable({ title = opts.title, x = opts.x or 40, y = opts.y or 120, width = opts.width or 400, centred = opts.centred,
        visible = opts.rows or 14, items = opts.items or {}, labelIndent = opts.labelIndent or 12, colorCoded = opts.colorCoded,
        hint = opts.hint, footer = opts.footer, onSelect = opts.onSelect, onBack = opts.onBack, onClose = opts.onClose,
        selected = 1, rows = {} }, MenuList)
    m.handlers = {
        render = function() m:render() end,
        key = function(key, pressed) m:key(key, pressed) end,
        move = function(_, _, x, y)
            if m.locked then return end
            local i = MenuInput.rowAt(m.rows, x, y)
            if i and i ~= m.selected and selectable(m.items[i]) then m:select(i) end
        end,
        click = function(button, state, x, y) m:click(button, state, x, y) end,
    }
    return m
end

local function listen(m, on)
    local f = on and addEventHandler or removeEventHandler
    f("onClientRender", root, m.handlers.render)
    f("onClientKey", root, m.handlers.key)
    f("onClientCursorMove", root, m.handlers.move)
    f("onClientClick", root, m.handlers.click)
end

function MenuList:isOpen() return self.shown == true end
function MenuList:current() return self.items[self.selected], self.selected end
function MenuList:setTitle(title) self.title = title end
function MenuList:message(text, ok) self.messageText, self.messageOk, self.messageAt = text, ok, getTickCount() end

-- Highlight entry `i` (telling onSelect when it changes).
function MenuList:select(i)
    local changed = i ~= self.selected
    self.selected = i
    if changed and self.onSelect then self.onSelect(self.items[i], i) end
end

function MenuList:step(dir)
    local n, i = #self.items, self.selected
    for _ = 1, n do
        i = (i - 1 + dir) % n + 1
        if selectable(self.items[i]) then return self:select(i) end
    end
end

-- New entries (another level, a refreshed list): the selection at `index` (or the first entry).
function MenuList:setItems(items, index)
    self.items, self.first = items, nil
    local i = math.max(1, math.min(index or 1, #items))
    -- On a heading or a disabled entry: the next one that isn't, else the one before.
    local j = i
    while j <= #items and not selectable(items[j]) do j = j + 1 end
    if j > #items then
        j = i
        while j >= 1 and not selectable(items[j]) do j = j - 1 end
    end
    self.selected = math.max(1, j)
    if self.onSelect then self.onSelect(items[self.selected], self.selected) end
end

function MenuList:open()
    if self.shown then return end
    self.shown, self.first = true, nil
    if not selectable(self.items[self.selected]) then self:step(1) end
    MenuInput.cursor(true)
    toggleAllControls(false, true, false)
    listen(self, true)
    if self.onSelect and self.items[self.selected] then self.onSelect(self.items[self.selected], self.selected) end
end

function MenuList:suspend(on)
    on = on == true
    if not self.shown or (self.suspended == true) == on then return end
    self.suspended = on
    listen(self, not on)
end

function MenuList:close()
    if not self.shown then return end
    self.shown = false
    if self.suspended then self.suspended = false else listen(self, false) end
    self.locked = nil
    MenuInput.cursor(false)
    toggleAllControls(true, true, false)
    if self.onClose then self.onClose() end
end

function MenuList:toggle() if self.shown then self:close() else self:open() end end

function MenuList:back()
    if self.onBack and self.onBack(self) then
        self.first = nil
        return
    end
    self:close()
end

-- A choice's current index (the nearest value), or 1.
local function current(item)
    local v, best, bestDist = item.get(), 1, math.huge
    for i, c in ipairs(item.choices) do
        local d = type(v) == "number" and type(c[2]) == "number" and math.abs(c[2] - v) or (c[2] == v and 0 or math.huge)
        if d < bestDist then best, bestDist = i, d end
    end
    return best
end

-- The selected entry: a choice moves by `dir` (wrapping); an entry runs on accept (`run`).
function MenuList:change(dir, run)
    local item = self.items[self.selected]
    if not selectable(item) then return end
    if item.choices then
        local i = (current(item) - 1 + dir) % #item.choices + 1
        item.set(item.choices[i][2])
    elseif run and item.run then
        item.run(item, self.selected)
    end
end

function MenuList:key(key, pressed)
    if not pressed then return end
    if self.locked then
        if MenuInput.action(key) then cancelEvent() end
        return
    end
    if MenuInput.wheel(self, key, #self.items) then
        -- The wheel picked the row under the cursor; a heading there isn't one to pick.
        local i = self.selected
        if not selectable(self.items[i]) then self:step(1) elseif self.onSelect then self.onSelect(self.items[i], i) end
        return cancelEvent()
    end
    local action = MenuInput.action(key)
    if action == "up" then self:step(-1)
    elseif action == "down" then self:step(1)
    elseif action == "left" then self:change(-1)
    elseif action == "right" then self:change(1)
    elseif action == "accept" then self:change(1, true)
    elseif action == "back" then self:back()
    else return end
    if action ~= "back" then self.first = nil end
    cancelEvent()
end

function MenuList:click(button, state, x, y)
    if state ~= "up" or self.locked then return end
    if button == "right" then return self:back() end
    local i = button == "left" and MenuInput.rowAt(self.rows, x, y)
    if i and selectable(self.items[i]) then
        self:select(i)
        -- A click on the left half of a choice's value goes back a step.
        local r = self.rows[i]
        self:change(self.items[i].choices and x < r[1] + (r[3] - r[1]) * 0.75 and x > r[1] + (r[3] - r[1]) * 0.5 and -1 or 1, true)
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
    dxDrawText(self.title, x + 12 * s, y + 6 * s, x + w, y + row, TITLE, 1.4 * s, "bankgothic", "left", "top", false, false, false, self.colorCoded)
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
            local dim = item.greyed or item.disabled
            local colour = dim and GREY or (selected and TEXT or DIM)
            dxDrawText(item.label, x + self.labelIndent * s, ry, x + w, ry + row, colour, 1.1 * s, "default-bold", "left", "center",
                true, false, false, self.colorCoded)
            local right = x + w - 12 * s
            if item.choices then
                local c = item.choices[current(item)]
                local text = selected and ("<  " .. c[1] .. "  >") or c[1]
                dxDrawText(text, x, ry, right, ry + row, VALUE, 1.1 * s, "default-bold", "right", "center")
            else
                local rights = item.rights
                if not rights and item.right then
                    local text = type(item.right) == "function" and item.right(item, selected) or item.right
                    rights = text and { { text, dim and GREY or item.rightColour or colour } } or nil
                end
                for _, r in ipairs(rights or {}) do
                    dxDrawText(r[1], x, ry, right, ry + row, r[2] or colour, 1.1 * s, "default-bold", "right", "center")
                    right = right - dxGetTextWidth(r[1], 1.1 * s, "default-bold") - 14 * s
                end
            end
        end
    end
    local by = y + row * (visible + 1.5)
    if self.messageText and getTickCount() - self.messageAt < MESSAGE_MS then
        dxDrawText(self.messageText, x + 12 * s, by, x + w, by + row, self.messageOk and tocolor(120, 255, 120) or tocolor(255, 120, 120),
            1 * s, "default-bold", "left", "center")
        return
    end
    local hint = type(self.hint) == "function" and self.hint(self) or self.hint
        or "Up/Down: choose   Left/Right, Enter or click: change   Backspace: close"
    local footer = self.footer and self.footer(self)
    dxDrawText(footer and (footer .. "   |   " .. hint) or hint, x + 12 * s, by, x + w, by + row, tocolor(200, 200, 200), 1 * s, "default", "left", "center")
end
