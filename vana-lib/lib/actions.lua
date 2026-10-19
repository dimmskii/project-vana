-- Actions: what a player can do to something in the world, each one a command (docs/controls.md).
-- A resource adds its own with Actions.add (server) and exports getActions, checkActionTarget,
-- getTargetActions and runAction in its meta.xml; vana-controls collects them, makes each a command
-- on every client (typed, bound, or picked in /interact's menu), finds the target and checks the gate.
-- Actions.add{
--   name      the command (lowercase);  aliases: other names for it
--   label     the menu entry ("Turn the engine off"): a string, or function(player, target)
--   usage     what follows the command, e.g. "<amount> [player]";  summary: one line for /help
--   targets   element types it acts on ("vehicle", "player", "ped", "marker"); none: no target
--   accepts   function(target, player): this element is one it acts on (optional)
--   inside    the vehicle the player sits in is the target, wherever they look
--   reach     metres from the player to the target (default 5)
--   params    the arguments after the command: { name, "number" | "string" | "target", required };
--             a "target" is a player's name (or part of it), like any #id typed anywhere
--   available function(player, target): listed in the menu right now (optional)
--   run       function(player, target, args): the message to show, or false and why
--   right     an ACL right the player needs (optional; everyone otherwise)
-- }
Actions = {}
local list, byName = {}, {}

function Actions.add(def)
    def.reach = def.reach or 5
    list[#list + 1] = def
    byName[def.name] = def
end

-- A message on the player's screen, vanilla style (vana-controls' status line), copied to their console.
function Actions.status(player, text)
    local res = getResourceFromName("vana-controls")
    if res and getResourceState(res) == "running" then
        exports["vana-controls"]:status(player, text)
    elseif isElement(player) then
        outputChatBox(text, player, 200, 200, 255)
    end
end

local function label(def, player, target)
    if type(def.label) == "function" then return def.label(player, target) end
    return def.label
end

local function fits(def, target, player)
    if not def.targets then return target == nil end
    if not isElement(target) then return false end
    local kind = getElementType(target)
    local typed = false
    for _, t in ipairs(def.targets) do typed = typed or t == kind end
    return typed and (not def.accepts or def.accepts(target, player)) == true
end

-- What vana-controls registers: everything but the functions.
function getActions()
    local out = {}
    for _, def in ipairs(list) do
        out[#out + 1] = { name = def.name, aliases = def.aliases, usage = def.usage, summary = def.summary,
            targets = def.targets, reach = def.reach, params = def.params, inside = def.inside, right = def.right,
            label = type(def.label) == "string" and def.label or nil }
    end
    return out
end

function checkActionTarget(name, player, target)
    local def = byName[name]
    return def ~= nil and fits(def, target, player)
end

-- The menu for one target: { name, label, needsInput } for each action that takes it now.
function getTargetActions(player, target)
    local out = {}
    for _, def in ipairs(list) do
        if def.targets and fits(def, target, player) and (not def.available or def.available(player, target)) then
            local needsInput = false
            for _, p in ipairs(def.params or {}) do needsInput = needsInput or (p[3] and p[2] ~= "target") end
            out[#out + 1] = { name = def.name, label = label(def, player, target) or def.name, needsInput = needsInput }
        end
    end
    return out
end

function runAction(name, player, target, args)
    local def = byName[name]
    if not def then return false end
    if def.targets and not fits(def, target, player) then return false, "You can't do that here." end
    local ok, message, why = pcall(def.run, player, target, args or {})
    if not ok then
        outputDebugString(("[actions] %s: %s"):format(name, tostring(message)), 1)
        return false
    end
    if message == false then return false, why end
    return true, message
end
