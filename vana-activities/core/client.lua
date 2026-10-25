-- The activity HUD, vanilla style: big centred titles, subtitles (objectives), the help box and
-- on-screen counters, with GXT formatting rendered (~r~ colours, ~n~ new lines, ~k~~CONTROL~ keys).
-- Also reports the sub-mission key (vanilla R3, PC "2") to the server.
Hud = {}
local big, say, help -- { text, untilTick, style, money }
local counters = {}  -- id -> { label, value, kind, up, at }
local order = {}     -- counter ids in arrival order
local current        -- active activity name

local COLOURS = { r = "#B4191D", g = "#36682C", b = "#323C7F", y = "#E1C482", p = "#A86EFC", w = "#FFFFFF",
                  s = "#FFFFFF", h = "#FFFFFF", l = "#000000", x = "#FFFFFF", o = "#FFFFFF", q = "#FFFFFF" }
-- Vanilla control names (~k~~NAME~) -> MTA controls.
local CONTROLS = {
    PED_SPRINT = "sprint", PED_JUMPING = "jump", PED_FIREWEAPON = "fire", PED_LOCK_TARGET = "aim_weapon",
    VEHICLE_ENTER_EXIT = "enter_exit", GO_FORWARD = "forwards", GO_BACK = "backwards", GO_LEFT = "left",
    GO_RIGHT = "right", PED_DUCK = "crouch", CONVERSATION_YES = "conversation_yes", CONVERSATION_NO = "conversation_no",
    TOGGLE_SUBMISSIONS = "sub_mission", VEHICLE_ACCELERATE = "accelerate", VEHICLE_BRAKE = "brake_reverse",
    VEHICLE_HORN = "horn", VEHICLE_FIREWEAPON = "vehicle_fire", VEHICLE_FIREWEAPON_ALT = "vehicle_secondary_fire",
    VEHICLE_HANDBRAKE = "handbrake", VEHICLE_LOOKLEFT = "vehicle_look_left", VEHICLE_LOOKRIGHT = "vehicle_look_right",
    VEHICLE_LOOKBEHIND = "vehicle_look_behind", VEHICLE_STEERUP = "steer_forward", VEHICLE_STEERDOWN = "steer_back",
    VEHICLE_STEERLEFT = "vehicle_left", VEHICLE_STEERRIGHT = "vehicle_right", PED_WALK = "walk",
    PED_CYCLE_WEAPON_RIGHT = "next_weapon", PED_CYCLE_WEAPON_LEFT = "previous_weapon", PED_LOOKBEHIND = "look_behind",
    GROUP_CONTROL_FWD = "group_control_forwards", GROUP_CONTROL_BWD = "group_control_back",
    CAMERA_CHANGE_VIEW_ALL_SITUATIONS = "change_camera", VEHICLE_RADIO_STATION_UP = "radio_next",
    VEHICLE_RADIO_STATION_DOWN = "radio_previous", PED_ANSWER_PHONE = "action", PED_CENTER_CAMERA_BEHIND_PLAYER = "action",
    VEHICLE_TURRETLEFT = "special_control_left", VEHICLE_TURRETRIGHT = "special_control_right",
    VEHICLE_TURRETUP = "special_control_up", VEHICLE_TURRETDOWN = "special_control_down",
}

local NUM = { add = "+", sub = "-", mul = "*", div = "/", dec = ".", enter = "ENTER" }
local function keyFor(name)
    local control = CONTROLS[name] or name:lower()
    local key = next(getBoundKeys(control) or {})
    if not key then return control end
    local num = key:match("^num_(%w+)$")
    return num and ("NUM" .. (NUM[num] or num:upper())) or key:upper()
end

-- GXT -> MTA colour-coded text.
function Hud.format(s)
    if not s then return "" end
    s = s:gsub("~k~~([%w_]+)~", function(name) return "#FFFFFF[" .. keyFor(name) .. "]#FFFFFF" end)
    s = s:gsub("~[nN]~", "\n")
    s = s:gsub("~(%a)~", function(c) return COLOURS[c:lower()] or "" end)
    return s
end

local function sx(v) return v * (select(2, guiGetScreenSize()) / 720) end

-- Where the counters may start: just below the lowest vanilla HUD piece on the right of the screen
-- (Neon reports their positions and sizes); a safe fraction of the screen if it can't tell.
local HUD_PIECES = { "money", "wanted", "weapon", "ammo", "health", "armour", "breath", "clock" }
local hudTop, hudCheckedAt = nil, 0
function Hud.counterTop()
    local now = getTickCount()
    if hudTop and now - hudCheckedAt < 2000 then return hudTop end
    hudCheckedAt = now
    local w, h = guiGetScreenSize()
    local bottom = 0
    for _, piece in ipairs(HUD_PIECES) do
        local ok, px, py = pcall(getPlayerHudComponentProperty, piece, "position")
        local ok2, sw, sh = pcall(getPlayerHudComponentProperty, piece, "size")
        if ok and ok2 and type(px) == "number" and type(py) == "number" and type(sh) == "number" and px > w / 2 then
            bottom = math.max(bottom, py + sh)
        end
    end
    hudTop = (bottom > 0 and bottom < h * 0.6) and (bottom + sx(12)) or h * 0.34
    return hudTop
end

addEvent("vana-activities:session", true)
addEventHandler("vana-activities:session", resourceRoot, function(name)
    current = name
    if not name then
        counters, order = {}, {}
        Hud.help(nil)
    end
end)

addEvent("vana-activities:big", true)
addEventHandler("vana-activities:big", resourceRoot, function(text, ms, style, money)
    big = { text = Hud.format(text), untilTick = getTickCount() + ms, style = style, money = money }
end)

-- Subtitles are vana-controls' too (the game's own, bottom middle); ours only stand in without it.
local function controls()
    local res = getResourceFromName("vana-controls")
    return res and getResourceState(res) == "running"
end

-- GXT for vana-controls' native text: keys other than enter/exit (which it names: /use's key) named here.
local function namedKeys(text)
    return text and (text:gsub("~k~~([%w_]+)~", function(name)
        if name == "VEHICLE_ENTER_EXIT" then return nil end
        return keyFor(name)
    end)) or nil
end

addEvent("vana-activities:say", true)
addEventHandler("vana-activities:say", resourceRoot, function(text, ms)
    if controls() then
        say = nil
        exports["vana-controls"]:subtitle(namedKeys(text), ms or 5000)
        return
    end
    say = text and { text = Hud.format(text), untilTick = getTickCount() + (ms or 5000) } or nil
end)


addEvent("vana-activities:help", true)
addEventHandler("vana-activities:help", resourceRoot, function(text, forever) Hud.help(text, forever) end)

-- Counters can also be set by client-side activity code (e.g. the burglary noise bar).
function Hud.counter(id, label, value, kind, up)
    if not label then
        counters[id] = nil
        for i, o in ipairs(order) do if o == id then table.remove(order, i) break end end
        return
    end
    if not counters[id] then order[#order + 1] = id end
    counters[id] = { label = Hud.format(label), value = value, kind = kind, up = up, at = getTickCount() }
end

-- The help box is vana-controls' (the game's own, shared with /use's prompts); ours only stands in
-- when it isn't running. Keys other than enter/exit (which vana-controls names: /use's key) are named here.
function Hud.help(text, forever)
    if controls() then
        help = nil
        exports["vana-controls"]:help(namedKeys(text), forever)
        return
    end
    help = text and { text = Hud.format(text), untilTick = forever and math.huge or getTickCount() + 10000 } or nil
end

addEvent("vana-activities:counter", true)
addEventHandler("vana-activities:counter", resourceRoot, Hud.counter)

local function shadowText(text, x1, y1, x2, y2, colour, scale, font, ax, ay)
    dxDrawText(text:gsub("#%x%x%x%x%x%x", ""), x1 + 2, y1 + 2, x2 + 2, y2 + 2, tocolor(0, 0, 0, 220), scale, font, ax, ay, false, true)
    dxDrawText(text, x1, y1, x2, y2, colour, scale, font, ax, ay, false, true, false, true)
end

local function clock(ms)
    local s = math.max(0, math.floor(ms / 1000))
    return ("%d:%02d"):format(math.floor(s / 60), s % 60)
end

addEventHandler("onClientRender", root, function()
    local w, h = guiGetScreenSize()
    local now = getTickCount()
    if big and now < big.untilTick then
        if big.style == "passed" or big.style == "failed" then
            shadowText(big.text, 0, h * 0.30, w, h * 0.40, tocolor(225, 196, 130), sx(1.6), "pricedown", "center", "center")
            if big.money then shadowText("$" .. big.money, 0, h * 0.40, w, h * 0.48, tocolor(255, 255, 255), sx(1.4), "pricedown", "center", "center") end
        elseif big.style == "small" then
            shadowText(big.text, 0, h * 0.36, w, h * 0.46, tocolor(255, 255, 255), sx(1.0), "bankgothic", "center", "center")
        else
            shadowText(big.text, 0, h * 0.18, w, h * 0.30, tocolor(225, 196, 130), sx(1.5), "bankgothic", "center", "center")
        end
    end
    if say and now < say.untilTick then
        shadowText(say.text, w * 0.15, h * 0.80, w * 0.85, h * 0.92, tocolor(255, 255, 255), sx(1.15), "default-bold", "center", "center")
    end
    if help and now < help.untilTick then
        -- Top middle, as vana-controls' status box (clear of the chat).
        local bw = sx(330)
        local x, y = (w - bw) / 2, sx(16)
        local lines = select(2, help.text:gsub("\n", "")) + 1
        local bh = sx(18) * lines + sx(24) + sx(14) * math.floor(#help.text / 48)
        dxDrawRectangle(x, y, bw, bh, tocolor(0, 0, 0, 190))
        dxDrawText(help.text, x + sx(10), y + sx(10), x + bw - sx(10), y + bh, tocolor(255, 255, 255), sx(1.05), "default-bold", "center", "top", false, true, false, true)
    end
    -- Counters on the right, below the vanilla HUD (money, wanted stars, weapon), as vanilla stacks them.
    local y = Hud.counterTop()
    for _, id in ipairs(order) do
        local c = counters[id]
        local value = c.value
        local text
        if c.kind == "timer" then
            local elapsed = now - c.at
            text = clock(c.up and value + elapsed or value - elapsed)
        elseif c.kind == "money" then
            text = "$" .. tostring(value)
        elseif c.kind ~= "bar" then
            text = tostring(value)
        end
        local x1, x2 = w - sx(290), w - sx(30)
        dxDrawRectangle(x1, y, x2 - x1, sx(30), tocolor(0, 0, 0, 150))
        shadowText(c.label, x1 + sx(10), y, x2, y + sx(30), tocolor(225, 196, 130), sx(1.1), "default-bold", "left", "center")
        if c.kind == "bar" then
            local bx, bw = x1 + sx(130), sx(115)
            dxDrawRectangle(bx, y + sx(9), bw, sx(12), tocolor(60, 20, 20, 220))
            dxDrawRectangle(bx, y + sx(9), bw * math.max(0, math.min(1, (value or 0) / 100)), sx(12), tocolor(180, 30, 30, 240))
        else
            shadowText(text, x1, y, x2 - sx(10), y + sx(30), tocolor(255, 255, 255), sx(1.1), "default-bold", "right", "center")
        end
        y = y + sx(36)
    end
end)

-- The sub-mission key: start (or end) the vehicle job the player is driving.
bindKey("sub_mission", "down", function()
    if isChatBoxInputActive() or isConsoleActive() or isMainMenuActive() then return end
    triggerServerEvent("vana-activities:submission", resourceRoot)
end)

function Hud.activity()
    return current
end

-- Perks this player has earned (sent by the server); some act here.
Hud.perks = {}
addEvent("vana-activities:perks", true)
addEventHandler("vana-activities:perks", resourceRoot, function(held) Hud.perks = held or {} end)

-- A passenger let out (Activity.letOut): out through their own door, as GTA's peds get out. The
-- server sends this again until they're out.
addEvent("vana-activities:letOut", true)
addEventHandler("vana-activities:letOut", resourceRoot, function(ped)
    if not isElement(ped) or not isElementStreamedIn(ped) or not getPedOccupiedVehicle(ped) or not isElementSyncer(ped) then return end
    killPedTask(ped, "primary", 3, false)
    setPedExitVehicle(ped)
end)

-- Firefighter's reward (vanilla): fire doesn't hurt you.
addEventHandler("onClientPlayerDamage", localPlayer, function(_, weapon)
    if Hud.perks.fireproof and weapon == 37 then cancelEvent() end
end)

-- A vanilla-style pick list (top left, vana-lib's menu_list): the server opens it with
-- "vana-activities:menu" (id, title, items = { { label, right, enabled } }, hint); choosing sends
-- "vana-activities:menuChoice" (id, index). An entry with enabled = false is greyed and does nothing.
local pickId
local pickList = MenuList.new{ x = 40, y = 120, width = 440, rows = 14, colorCoded = true,
    onClose = function() pickId = nil end }

addEvent("vana-activities:menu", true)
addEventHandler("vana-activities:menu", resourceRoot, function(id, title, items, hint)
    if not id then return pickList:close() end
    pickId = id
    local entries = {}
    for i, item in ipairs(items) do
        entries[i] = { label = Hud.format(item.label), right = item.right, greyed = item.enabled == false,
            run = function()
                if item.enabled == false then return end
                local chosen = pickId
                pickList:close()
                triggerServerEvent("vana-activities:menuChoice", resourceRoot, chosen, i)
            end }
    end
    pickList:setTitle(Hud.format(title))
    pickList.hint = hint or "Enter: choose   Backspace: leave"
    pickList:setItems(entries, 1)
    pickList:open()
end)
