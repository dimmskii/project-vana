-- /preferences (/prefs, F9): one panel for the player's own settings (config/preferences.lua), kept in a
-- file of this resource's on their machine (@prefs.json), so every server restart and reconnect keeps
-- them. Other client scripts read them with exports["vana-controls"]:getPreference(key), and hear about
-- changes from onClientPreferenceChange (key, value) on the root element.
local FILE = "@prefs.json"
local values = {}
local byKey = {}
for _, p in ipairs(Preferences) do if p.key then byKey[p.key] = p end end

addEvent("onClientPreferenceChange", false)

local function load()
    local f = fileExists(FILE) and fileOpen(FILE, true)
    if not f then return end
    local data = fromJSON(fileRead(f, fileGetSize(f)) or "")
    fileClose(f)
    if type(data) == "table" then
        for k, v in pairs(data) do if byKey[k] then values[k] = v end end
    end
end

local function save()
    local f = fileCreate(FILE)
    if not f then return end
    fileWrite(f, toJSON(values, true))
    fileClose(f)
end

function getPreference(key)
    local p = byKey[key]
    if not p then return nil end
    if values[key] == nil then return p.default end
    return values[key]
end

local function setPreference(key, value)
    if not byKey[key] or getPreference(key) == value then return end
    values[key] = value
    save()
    triggerEvent("onClientPreferenceChange", root, key, value)
end

local items = {}
for _, p in ipairs(Preferences) do
    if p.heading then
        items[#items + 1] = { heading = p.heading, level = p.level }
    else
        items[#items + 1] = { label = p.label, choices = p.choices,
            get = function() return getPreference(p.key) end, set = function(v) setPreference(p.key, v) end }
    end
end
items[#items + 1] = { label = "Back to the defaults", run = function()
    for key in pairs(byKey) do setPreference(key, byKey[key].default) end
    values = {}
    save()
end }

local panel = MenuList.new{ title = "Preferences", centred = true, y = 110, width = 440, rows = 14, items = items }

local function toggle()
    if panel:isOpen() then return panel:close() end
    if isPedDead(localPlayer) then return end
    panel:open()
end
addCommandHandler("preferences", toggle)
addCommandHandler("prefs", toggle)

addEventHandler("onClientResourceStart", resourceRoot, function()
    load()
    bindKey("f9", "down", "preferences")
end)
