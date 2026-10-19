-- /use: vanilla's enter/exit key for everything that isn't a car (docs/controls.md). Bound to F and
-- Enter (the game's enter/exit keys) under this resource in MTA's binds menu, where players rebind it.
-- Scripts offer what /use does where the player stands (a shop counter, a machine, loot); the latest
-- offer wins. While there is one, the game's own enter/exit is off, so the key never also climbs into
-- the nearest car; with none, the key is the game's again (getting in and out of cars stays GTA's).
--   exports["vana-controls"]:offer(id, text [, silent])  text as "Press F to <text>", or with
--                                                        ~k~~VEHICLE_ENTER_EXIT~ where the key goes;
--                                                        silent: the script shows its own help
--   exports["vana-controls"]:withdraw(id)
-- Pressing it raises onClientVanaUse(id) on the root element; the offering script acts on its own id.
-- When this resource (re)starts, onClientVanaUseReset asks scripts to offer again.
local offers, serial = {}, 0 -- id -> { text, silent, order }
local disabledByUs = false
local menuUp = false -- a menu has the controls off: the prompt waits

addEvent("onClientVanaUse", false)
addEvent("onClientVanaUseReset", false)

local function current()
    if getPedOccupiedVehicle(localPlayer) or isPedDead(localPlayer) then return end
    local best, bestId
    for id, o in pairs(offers) do
        if not best or o.order > best.order then best, bestId = o, id end
    end
    return best, bestId
end

local function promptText(text)
    if text:find("~k~~VEHICLE_ENTER_EXIT~", 1, true) then return text end
    return ("Press ~k~~VEHICLE_ENTER_EXIT~ to %s"):format(text)
end

local function update()
    local o = current()
    Status.prompt(o and not o.silent and not menuUp and promptText(o.text) or nil)
end

function offer(id, text, silent)
    if type(id) ~= "string" or type(text) ~= "string" then return false end
    serial = serial + 1
    offers[id] = { text = text, silent = silent == true, order = serial }
    update()
    return true
end

function withdraw(id)
    if offers[id] then
        offers[id] = nil
        update()
    end
    return true
end

-- Another resource stopping takes its offers with it.
addEventHandler("onClientResourceStop", root, function(res)
    local prefix = getResourceName(res) .. ":"
    for id in pairs(offers) do
        if id:sub(1, #prefix) == prefix then offers[id] = nil end
    end
    update()
end)

addCommandHandler("use", function()
    local o, id = current()
    if o then triggerEvent("onClientVanaUse", localPlayer, id) end
end)

-- Vehicles and menus come and go without telling us: the prompt and the game's key follow each frame.
local lastInVehicle
addEventHandler("onClientPreRender", root, function()
    local inVehicle = getPedOccupiedVehicle(localPlayer) ~= false
    local menu = not isControlEnabled("forwards")
    if inVehicle ~= lastInVehicle or menu ~= menuUp then
        lastInVehicle, menuUp = inVehicle, menu
        update()
    end
    local want = current() ~= nil
    if want then
        if isControlEnabled("enter_exit") then
            toggleControl("enter_exit", false)
            disabledByUs = true
        end
    elseif disabledByUs then
        -- A menu that has every control off turns them back on itself when it closes.
        disabledByUs = false
        if not menuUp then toggleControl("enter_exit", true) end
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    bindKey("f", "down", "use")
    bindKey("enter", "down", "use")
    bindKey("f1", "down", "interact")
    bindKey("x", "down", "interact")
    triggerEvent("onClientVanaUseReset", root)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if disabledByUs then toggleControl("enter_exit", true) end
end)
