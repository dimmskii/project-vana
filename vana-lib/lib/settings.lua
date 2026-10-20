-- Settings (server): a resource's levers in MTA's own resource settings, the `<settings>` in its
-- meta.xml (defaults, each public: "@name"), changed values kept in the server's settings.xml
-- (docs/setup.md). Import on the server.
--   Settings.bind(CONFIG, { density = "number", enabled = "bool", species = "string" } [, onChange])
--       reads each setting into CONFIG[name] (keeping CONFIG's value when the setting is missing or
--       unreadable) and keeps it current: a change (the admin panel, /vanaset) is read again and
--       onChange(name, value) called
--   Settings.set(name, value)   changes one of this resource's settings and saves it
-- Each resource that imports this exports setSetting (meta.xml), which /vanaset (vana-core) calls.
Settings = {}
local bound = {}
local me = getResourceName(getThisResource())

local function read(name, kind, default)
    local v = get(name)
    if v == nil or v == false and kind ~= "bool" then return default end
    if type(v) == "table" then v = v[1] end
    if kind == "number" then return tonumber(v) or default end
    if kind == "bool" then
        if v == true or v == "true" or v == 1 or v == "1" then return true end
        if v == false or v == "false" or v == 0 or v == "0" then return false end
        return default
    end
    return v ~= nil and tostring(v) or default
end

function Settings.bind(target, fields, onChange)
    for name, kind in pairs(fields) do target[name] = read(name, kind, target[name]) end
    bound[#bound + 1] = { target = target, fields = fields, onChange = onChange }
end

function Settings.set(name, value)
    for _, b in ipairs(bound) do
        if b.fields[name] then
            local ok = set("@" .. name, tostring(value)) -- public, as in meta.xml (unprefixed would be private)
            b.target[name] = read(name, b.fields[name], b.target[name])
            if b.onChange then b.onChange(name, b.target[name]) end
            return ok, b.target[name]
        end
    end
    return false
end

-- For /vanaset (vana-core): name and value as typed; returns ok, the value now in force.
function setSetting(name, value)
    if type(name) ~= "string" then return false end
    return Settings.set(name, value)
end

-- The settings this resource has bound: name -> current value (for /vanaset's listing).
function getSettings()
    local out = {}
    for _, b in ipairs(bound) do
        for name in pairs(b.fields) do out[name] = b.target[name] end
    end
    return out
end

addEventHandler("onSettingChange", root, function(setting)
    local res, name = setting:match("^[%*@#]?([^%.]+)%.(.+)$")
    if res ~= me then return end
    for _, b in ipairs(bound) do
        if b.fields[name] then
            b.target[name] = read(name, b.fields[name], b.target[name])
            if b.onChange then b.onChange(name, b.target[name]) end
        end
    end
end)
