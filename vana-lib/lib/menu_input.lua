-- Menu input (client): one way through every menu, by keyboard, joystick or mouse. Import on the client.
--   MenuInput.action(key)       what an onClientKey key means in a menu: "up", "down", "left", "right",
--                               "accept", "back" or nil. Arrows / D-pad / mouse wheel move; Enter, the
--                               pad's sprint button (else joy1) accept; Backspace, Escape, the pad's
--                               enter/exit button (else joy2) go back.
--   MenuInput.cursor(on)        the mouse cursor while a menu is open (counted: several menus can ask)
--   MenuInput.rowAt(rows, x, y) the row under the cursor: rows[i] = { x1, y1, x2, y2 }, as drawn
--   MenuInput.wheel(m, key, n)  the mouse wheel over the menu `m` (its `box`, drawn): scrolls it a row
--                               and selects the row then under the cursor; true when it did
-- A menu draws its rows into a table each frame, picks the row under onClientCursorMove and runs it
-- on a left click (onClientClick); a right click goes back.
-- Scrolling: a menu keeps the first row it shows (`first`, with `visible` rows). The keys and the pad
-- clear it, so the view follows the selection with its margin as before; the mouse picking a row
-- leaves it where it is, and the wheel over the menu moves it.
MenuInput = {}

local MOVES = { arrow_u = "up", arrow_d = "down", arrow_l = "left", arrow_r = "right",
                pov_up = "up", pov_down = "down", pov_left = "left", pov_right = "right",
                mouse_wheel_up = "up", mouse_wheel_down = "down",
                enter = "accept", num_enter = "accept", backspace = "back", escape = "back" }

local function padButton(control, key, fallback)
    local any = false
    for bound in pairs(getBoundKeys(control) or {}) do
        if bound:sub(1, 3) == "joy" then
            any = true
            if bound == key then return true end
        end
    end
    return not any and key == fallback
end

function MenuInput.action(key)
    if MOVES[key] then return MOVES[key] end
    if key:sub(1, 3) ~= "joy" then return nil end
    if padButton("sprint", key, "joy1") then return "accept" end
    if padButton("enter_exit", key, "joy2") then return "back" end
end

local wanted = 0
function MenuInput.cursor(on)
    wanted = math.max(0, wanted + (on and 1 or -1))
    showCursor(wanted > 0, false)
end

function MenuInput.cursorAt()
    local cx, cy = getCursorPosition()
    if not cx then return end
    local sw, sh = guiGetScreenSize()
    return cx * sw, cy * sh
end

function MenuInput.wheel(m, key, count)
    local delta = key == "mouse_wheel_up" and -1 or key == "mouse_wheel_down" and 1 or nil
    local x, y = MenuInput.cursorAt()
    local b = m.box
    if not delta or not x or not b or x < b[1] or x > b[3] or y < b[2] or y > b[4] then return false end
    local old = m.first or 1
    m.first = math.max(1, math.min(old + delta, count - (m.visible or count) + 1))
    local i = MenuInput.rowAt(m.rows, x, y)
    if i then m.selected = math.max(1, math.min(count, i + m.first - old)) end
    return true
end

function MenuInput.rowAt(rows, x, y)
    if not x then return end
    for i, r in pairs(rows or {}) do
        if x >= r[1] and x <= r[3] and y >= r[2] and y <= r[4] then return i end
    end
end
